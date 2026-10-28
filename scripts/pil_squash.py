#!/usr/bin/env python3
"""Склейка разбитой прошивки Qualcomm (NAME.mdt + NAME.b00..bNN) в один NAME.mbn — то же, что pil-squasher.
Сегмент i берётся из NAME.bNN (или из самого .mdt, если сегмент лежит в нём) и кладётся по p_offset.
Запуск: python3 -I scripts/pil_squash.py OUT.mbn IN.mdt"""
import os, struct, sys

out, mdt = sys.argv[1], sys.argv[2]
data = open(mdt, "rb").read()
assert data[:4] == b"\x7fELF"
is64 = data[4] == 2
if is64:
    e_phoff, = struct.unpack_from("<Q", data, 0x20)
    e_phentsize, e_phnum = struct.unpack_from("<HH", data, 0x36)
else:
    e_phoff, = struct.unpack_from("<I", data, 0x1c)
    e_phentsize, e_phnum = struct.unpack_from("<HH", data, 0x2a)
base = mdt[:-4]
img = bytearray()
for i in range(e_phnum):
    o = e_phoff + i * e_phentsize
    if is64:
        p_type, p_flags, p_offset, p_vaddr, p_paddr, p_filesz = struct.unpack_from("<IIQQQQ", data, o)
    else:
        p_type, p_offset, p_vaddr, p_paddr, p_filesz = struct.unpack_from("<IIIII", data, o)
    if p_filesz == 0:
        continue
    seg_file = f"{base}.b{i:02d}"
    if os.path.exists(seg_file):
        seg = open(seg_file, "rb").read()[:p_filesz]
    elif p_offset + p_filesz <= len(data):
        seg = data[p_offset:p_offset + p_filesz]
    else:
        raise SystemExit(f"segment {i} missing: {seg_file}")
    end = p_offset + len(seg)
    if len(img) < end:
        img.extend(b"\0" * (end - len(img)))
    img[p_offset:end] = seg
# заголовок ELF + phdrs из .mdt
hdr_end = e_phoff + e_phnum * e_phentsize
img[:hdr_end] = data[:hdr_end]
open(out, "wb").write(img)
print(f"{out}: {len(img)} bytes from {e_phnum} phdrs")
