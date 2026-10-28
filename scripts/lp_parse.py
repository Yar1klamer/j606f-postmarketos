#!/usr/bin/env python3
"""Печатает логические разделы из super.img (Android dynamic partitions, LP metadata): имя, экстенты, смещение в байтах.
Запуск: python3 -I scripts/lp_parse.py BACKUP/partitions/super.img [slot_suffix]"""
import struct, sys

f = open(sys.argv[1], "rb")
GEOM_OFF = 4096
f.seek(GEOM_OFF)
g = f.read(4096)
magic, struct_size = struct.unpack_from("<II", g, 0)
assert magic == 0x616C4467, hex(magic)
metadata_max_size, metadata_slot_count, logical_block_size = struct.unpack_from("<III", g, 40)
# основная копия метаданных, слот 0: после geometry (4096) + резервной geometry (4096)
f.seek(GEOM_OFF + 4096 * 2)
h = f.read(metadata_max_size)
magic, major, minor, header_size = struct.unpack_from("<IHHI", h, 0)
assert magic == 0x414C5030, hex(magic)
off = 4 + 2 + 2 + 4 + 32 + 4 + 32  # magic, major, minor, header_size, header_checksum, tables_size, tables_checksum
tables = []
for i in range(4):  # partitions, extents, groups, block_devices
    tables.append(struct.unpack_from("<III", h, off + i * 12))
tbl = h[header_size:]
(p_off, p_n, p_sz), (e_off, e_n, e_sz) = tables[0], tables[1]
print(f"LP v{major}.{minor}, block {logical_block_size}, {p_n} partitions, {e_n} extents")
for i in range(p_n):
    name, attrs, first, nume, group = struct.unpack_from("<36sIIII", tbl, p_off + i * p_sz)
    name = name.rstrip(b"\0").decode()
    exts = []
    for j in range(first, first + nume):
        nsec, ttype, tdata, tsrc = struct.unpack_from("<QIQI", tbl, e_off + j * e_sz)
        exts.append((nsec, ttype, tdata, tsrc))
    size = sum(e[0] for e in exts) * 512
    desc = ", ".join(f"[sector {e[2]} (+{e[2]*512:#x}), {e[0]*512} bytes, type {e[1]}]" for e in exts)
    print(f"{name:24s} size={size:>11d} attrs={attrs} {desc}")
