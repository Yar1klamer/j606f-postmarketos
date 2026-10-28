#!/usr/bin/env python3
"""Собирает отладочный boot.img (Android header v2) для `fastboot boot` на TB-J606F без Linux-хоста:
ядро и DTB из бинарного пакета linux-nura-qcom-sm61x5, initramfs из busybox-static +
scripts/debug-initramfs/init + USB-гаджет-модули (распакованные из .ko.zst).

Запуск (нужен venv с zstandard):
  .../venv/bin/python -I scripts/make_debug_bootimg.py --kernel K --dtb D --modules MODDIR \
      --busybox BB --out OUT.img [--cmdline "..."]
Параметры раскладки взяты из стокового boot (notes/boot.md)."""
import argparse, gzip, hashlib, io, os, struct, time
import zstandard

PAGE = 4096
BASE = 0x00000000
KERNEL_OFF, RAMDISK_OFF, SECOND_OFF, TAGS_OFF, DTB_OFF = 0x8000, 0x01000000, 0x00f00000, 0x100, 0x01f00000
OS_VERSION = 0x14000155  # как у стокового boot (Android 10, патч 2021-05)
MODULES = ["libcomposite", "u_ether", "usb_f_ecm", "u_serial", "usb_f_acm"]
HERE = os.path.dirname(os.path.abspath(__file__))


class Cpio:
    def __init__(self):
        self.buf = io.BytesIO()
        self.ino = 1

    def _hdr(self, name, mode, size, rmaj=0, rmin=0, nlink=1):
        name_b = name.encode() + b"\0"
        h = "070701" + "".join("%08X" % v for v in (
            self.ino, mode, 0, 0, nlink, int(time.time()), size, 0, 0, rmaj, rmin, len(name_b), 0))
        self.ino += 1
        self.buf.write(h.encode() + name_b)
        self._pad()

    def _pad(self):
        self.buf.write(b"\0" * ((4 - self.buf.tell() % 4) % 4))

    def dir(self, name):
        self._hdr(name, 0o040755, 0, nlink=2)

    def file(self, name, data, mode=0o100644):
        self._hdr(name, mode, len(data))
        self.buf.write(data)
        self._pad()

    def chardev(self, name, major, minor):
        self._hdr(name, 0o020600, 0, major, minor)

    def finish(self):
        self._hdr("TRAILER!!!", 0, 0)
        return self.buf.getvalue()


def find_module(moddir, name):
    for root, _, files in os.walk(moddir):
        for f in files:
            if f in (name + ".ko.zst", name + ".ko"):
                return os.path.join(root, f)
    raise SystemExit(f"module {name} not found in {moddir}")


def modinfo(raw):
    """Поля .modinfo из ELF-модуля (name, depends, ...)."""
    info = {}
    for part in raw.split(b"\0"):
        for key in (b"name=", b"depends=", b"vermagic="):
            if part.startswith(key):
                info.setdefault(key[:-1].decode(), part[len(key):].decode(errors="replace"))
    return info


def load_module_index(moddir, extra):
    """name -> (bytes, depends[]) для всех модулей пакета + extra (*.ko собранные отдельно, имеют приоритет)."""
    dctx = zstandard.ZstdDecompressor()
    idx = {}
    for root, _, files in os.walk(moddir):
        for f in files:
            if f.endswith((".ko", ".ko.zst")):
                idx[f.split(".ko")[0].replace("-", "_")] = os.path.join(root, f)
    for e in extra:
        idx[os.path.basename(e).split(".ko")[0].replace("-", "_")] = e

    def read(name):
        p = idx[name]
        raw = open(p, "rb").read()
        if p.endswith(".zst"):
            raw = dctx.stream_reader(io.BytesIO(raw)).read()
        return raw
    return idx, read


def resolve(names, idx, read):
    """Порядок загрузки с учётом depends= (зависимости раньше)."""
    order, seen = [], set()

    def visit(n):
        n = n.replace("-", "_")
        if n in seen:
            return
        seen.add(n)
        if n not in idx:
            raise SystemExit(f"module {n} not found")
        deps = [d for d in modinfo(read(n)).get("depends", "").split(",") if d]
        for d in deps:
            visit(d)
        order.append(n)
    for n in names:
        visit(n)
    return order


def build_initramfs(busybox, moddir, extra=(), load=(), firmware=None):
    c = Cpio()
    for d in ["bin", "dev", "proc", "sys", "tmp", "run", "etc", "lib", "lib/modules", "www", "www/cgi-bin"]:
        c.dir(d)
    c.chardev("dev/console", 5, 1)
    c.chardev("dev/null", 1, 3)
    c.chardev("dev/kmsg", 1, 11)
    c.file("init", open(os.path.join(HERE, "debug-initramfs/init"), "rb").read(), 0o100755)
    c.file("bin/busybox", open(busybox, "rb").read(), 0o100755)
    c.file("www/cgi-bin/dmesg", open(os.path.join(HERE, "debug-initramfs/cgi-dmesg"), "rb").read(), 0o100755)
    c.file("www/cgi-bin/run", open(os.path.join(HERE, "debug-initramfs/cgi-run"), "rb").read(), 0o100755)
    idx, read = load_module_index(moddir, extra)
    for m in MODULES:
        c.file(f"lib/modules/{m}.ko", read(m))
    order = resolve(load, idx, read) if load else []
    for m in order:
        if m not in MODULES:
            c.file(f"lib/modules/{m}.ko", read(m))
    # /etc/modules.load читает init после поднятия USB (см. debug-initramfs/init)
    c.file("etc/modules.load", ("\n".join(m for m in order if m not in MODULES) + "\n").encode())
    if firmware:
        dirs = set()
        for root, _, files in os.walk(firmware):
            for f in sorted(files):
                rel = os.path.relpath(os.path.join(root, f), firmware)
                parts = ("lib/firmware/" + rel).split("/")
                for i in range(2, len(parts)):
                    dd = "/".join(parts[:i])
                    if dd not in dirs:
                        dirs.add(dd)
                        c.dir(dd)
                c.file("lib/firmware/" + rel, open(os.path.join(root, f), "rb").read())
    print("modules to load:", " ".join(m for m in order if m not in MODULES))
    return gzip.compress(c.finish(), 9)


def pad(b):
    return b + b"\0" * ((PAGE - len(b) % PAGE) % PAGE)


def bootimg_v0(kernel, ramdisk, cmdline):
    """header v0: DTB уже приклеен к kernel (Image.gz-dtb), как у xiaomi-laurel в pmaports."""
    assert len(cmdline) < 512
    sha = hashlib.sha1()
    for blob in (kernel, ramdisk, b""):  # kernel, ramdisk, second
        sha.update(blob)
        sha.update(struct.pack("<I", len(blob)))
    hid = sha.digest() + b"\0" * 12
    hdr = b"ANDROID!" + struct.pack("<10I", len(kernel), BASE + KERNEL_OFF, len(ramdisk), BASE + RAMDISK_OFF,
                                    0, BASE + SECOND_OFF, BASE + TAGS_OFF, PAGE, 0, OS_VERSION)
    hdr += b"\0" * 16 + cmdline.encode().ljust(512, b"\0") + hid + b"\0" * 1024
    assert len(hdr) == 1632, len(hdr)
    return pad(hdr) + pad(kernel) + pad(ramdisk)


def bootimg_v2(kernel, ramdisk, dtb, cmdline):
    assert len(cmdline) < 512
    sha = hashlib.sha1()
    for blob in (kernel, ramdisk, b"", b"", dtb):  # kernel, ramdisk, second, recovery_dtbo, dtb
        sha.update(blob)
        sha.update(struct.pack("<I", len(blob)))
    hid = sha.digest() + b"\0" * 12
    hdr = b"ANDROID!" + struct.pack("<10I", len(kernel), BASE + KERNEL_OFF, len(ramdisk), BASE + RAMDISK_OFF,
                                    0, BASE + SECOND_OFF, BASE + TAGS_OFF, PAGE, 2, OS_VERSION)
    hdr += b"\0" * 16                                  # name
    hdr += cmdline.encode().ljust(512, b"\0")          # cmdline
    hdr += hid                                         # id[8]
    hdr += b"\0" * 1024                                # extra_cmdline
    hdr += struct.pack("<IQI", 0, 0, 1660)             # recovery_dtbo size/offset, header_size
    hdr += struct.pack("<IQ", len(dtb), BASE + DTB_OFF)
    assert len(hdr) == 1660, len(hdr)
    return pad(hdr) + pad(kernel) + pad(ramdisk) + pad(dtb)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kernel", required=True)
    ap.add_argument("--dtb", required=True)
    ap.add_argument("--modules", required=True)
    ap.add_argument("--busybox", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--extra-ko", action="append", default=[], help="собранный отдельно .ko (повторяемо)")
    ap.add_argument("--load", action="append", default=[], help="модуль для загрузки после USB (повторяемо)")
    ap.add_argument("--firmware", help="каталог, кладётся в /lib/firmware")
    ap.add_argument("--header-version", type=int, choices=(0, 2), default=2,
                    help="0: DTB приклеивается к ядру (append_dtb); 2: DTB в отдельной секции")
    ap.add_argument("--cmdline", default="console=tty0 fbcon=rotate:2 loglevel=7 ignore_loglevel "
                                          "clk_ignore_unused pd_ignore_unused panic=10 rdinit=/init")
    a = ap.parse_args()
    rd = build_initramfs(a.busybox, a.modules, a.extra_ko, a.load, a.firmware)
    kernel, dtb = open(a.kernel, "rb").read(), open(a.dtb, "rb").read()
    if a.header_version == 0:
        img = bootimg_v0(kernel + dtb, rd, a.cmdline)
    else:
        img = bootimg_v2(kernel, rd, dtb, a.cmdline)
    open(a.out, "wb").write(img)
    print(f"{a.out}: {len(img)} bytes, ramdisk {len(rd)} bytes, sha256 {hashlib.sha256(img).hexdigest()}")


main()
