#!/usr/bin/env python3
"""Заменяет DTB (и, по желанию, ядро) в boot.img (Android header v2) и пересчитывает id (SHA1, как mkbootimg).
Нужен для `fastboot boot` с тестовым DTB/ядром без записи boot_b:
  python3 -I scripts/bootimg_replace_dtb.py IN.img NEW.dtb OUT.img [NEW_VMLINUZ]
Ядро в boot.img — это /boot/vmlinuz из пакета linux-lenovo-j606f как есть.
"""
import hashlib, struct, sys


def pages(n, page):
    return (n + page - 1) // page * page


def main(src, dtb_path, dst, kernel_path=None):
    img = open(src, "rb").read()
    if img[:8] != b"ANDROID!":
        sys.exit("not an Android boot image")
    (kernel_size, kernel_addr, ramdisk_size, ramdisk_addr, second_size, second_addr,
     tags_addr, page, version, os_version) = struct.unpack_from("<10I", img, 8)
    if version != 2:
        sys.exit(f"header v{version}, only v2 is supported")
    dtbo_size, = struct.unpack_from("<I", img, 1632)
    dtb_size, = struct.unpack_from("<I", img, 1648)
    off = page
    parts = {}
    for name, size in (("kernel", kernel_size), ("ramdisk", ramdisk_size), ("second", second_size),
                       ("dtbo", dtbo_size), ("dtb", dtb_size)):
        parts[name] = img[off:off + size]
        off += pages(size, page)
    if kernel_path:
        parts["kernel"] = open(kernel_path, "rb").read()
    new_dtb = open(dtb_path, "rb").read()
    if new_dtb[:4] != b"\xd0\x0d\xfe\xed":
        sys.exit("not a flattened device tree")
    hdr = bytearray(img[:page])
    struct.pack_into("<I", hdr, 8, len(parts["kernel"]))
    struct.pack_into("<I", hdr, 1648, len(new_dtb))
    sha = hashlib.sha1()
    for name in ("kernel", "ramdisk", "second", "dtbo"):
        sha.update(parts[name])
        sha.update(struct.pack("<I", len(parts[name])))
    sha.update(new_dtb)
    sha.update(struct.pack("<I", len(new_dtb)))
    hdr[576:608] = sha.digest().ljust(32, b"\0")
    out = bytearray(hdr)
    for data in (parts["kernel"], parts["ramdisk"], parts["second"], parts["dtbo"], new_dtb):
        out += data + b"\0" * (pages(len(data), page) - len(data))
    open(dst, "wb").write(out)
    print(f"{dst}: kernel {kernel_size} -> {len(parts['kernel'])}, dtb {dtb_size} -> {len(new_dtb)} bytes, {len(out)} bytes total")


if __name__ == "__main__":
    if len(sys.argv) not in (4, 5):
        sys.exit(__doc__)
    main(*sys.argv[1:])
