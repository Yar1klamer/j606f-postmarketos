#!/usr/bin/env python3
"""Печатает заголовок Android boot image (v0–v2) и при --extract DIR раскладывает kernel/ramdisk/second/dtb.
Запуск: python3 -I scripts/bootimg_info.py BACKUP/stock/boot_a_stock_from_magisk.img [--extract DIR]"""
import struct, sys, os

def main():
    path = sys.argv[1]
    out = sys.argv[3] if len(sys.argv) > 3 and sys.argv[2] == "--extract" else None
    b = open(path, "rb").read()
    assert b[:8] == b"ANDROID!", "not a boot image"
    (ks, ka, rs, ra, ss, sa, ta, ps, ver, osv) = struct.unpack_from("<10I", b, 8)
    name = b[48:64].rstrip(b"\0").decode()
    cmd = b[64:64 + 512].rstrip(b"\0").decode()
    extra = b[608:608 + 1024].rstrip(b"\0").decode()
    off = 1632
    ro_size = ro_off = hdr_size = dtb_size = dtb_addr = 0
    if ver >= 1:
        ro_size, ro_off, hdr_size = struct.unpack_from("<IQI", b, off); off += 16
    if ver >= 2:
        dtb_size, dtb_addr = struct.unpack_from("<IQ", b, off)
    # base по соглашению mkbootimg: kernel_addr = base + kernel_offset, kernel_offset по умолчанию 0x8000
    print(f"header_version   {ver}")
    print(f"page_size        {ps:#x}")
    print(f"kernel  size={ks:#x} addr={ka:#x}")
    print(f"ramdisk size={rs:#x} addr={ra:#x}")
    print(f"second  size={ss:#x} addr={sa:#x}")
    print(f"tags_addr        {ta:#x}")
    print(f"dtb     size={dtb_size:#x} addr={dtb_addr:#x}")
    print(f"recovery_dtbo    size={ro_size:#x} off={ro_off:#x}; header_size={hdr_size}")
    maj = (osv >> 25) & 0x7f; mn = (osv >> 18) & 0x7f; pt = osv & 0x7ff
    print(f"os_version       {maj>>0}.{mn}  patch {2000 + (pt >> 4)}-{pt & 0xf:02d}  (raw {osv:#x})")
    print(f"name             {name!r}")
    print(f"cmdline          {cmd!r}")
    print(f"extra_cmdline    {extra!r}")
    base_guess = ka - 0x8000
    print(f"base (если kernel_offset=0x8000) {base_guess:#x}; ramdisk_offset {ra-base_guess:#x}; "
          f"tags_offset {ta-base_guess:#x}; dtb_offset {dtb_addr-base_guess:#x}")
    if out:
        os.makedirs(out, exist_ok=True)
        pg = lambda n: (n + ps - 1) // ps * ps
        o = ps
        parts = [("kernel", ks), ("ramdisk", rs), ("second", ss), ("recovery_dtbo", ro_size), ("dtb", dtb_size)]
        for n, sz in parts:
            if sz:
                open(os.path.join(out, n), "wb").write(b[o:o + sz])
            o += pg(sz)
        print("extracted to", out)

main()
