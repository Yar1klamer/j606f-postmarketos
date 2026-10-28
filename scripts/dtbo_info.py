#!/usr/bin/env python3
"""Разбор dtbo.img (Android DTBO table, magic 0xd7b7ab1e). Печатает записи и, при --extract DIR,
сохраняет каждый overlay как entryNN.dtbo.
Запуск: python3 -I scripts/dtbo_info.py BACKUP/partitions/dtbo_a.img [--extract DIR]"""
import struct, sys, os

b = open(sys.argv[1], "rb").read()
magic, total, hsize, esize, count, eoff, pgsz, ver = struct.unpack_from(">8I", b, 0)
assert magic == 0xd7b7ab1e, hex(magic)
print(f"total_size={total} header={hsize} entry_size={esize} count={count} entries_off={eoff} page={pgsz} ver={ver}")
out = sys.argv[3] if len(sys.argv) > 3 and sys.argv[2] == "--extract" else None
if out:
    os.makedirs(out, exist_ok=True)
for i in range(count):
    size, off, eid, rev, c0, c1, c2, c3 = struct.unpack_from(">8I", b, eoff + i * esize)
    print(f"[{i}] off={off:#x} size={size} id={eid:#x} rev={rev:#x} custom={c0:#x},{c1:#x},{c2:#x},{c3:#x}")
    if out:
        open(os.path.join(out, f"entry{i:02d}.dtbo"), "wb").write(b[off:off + size])
