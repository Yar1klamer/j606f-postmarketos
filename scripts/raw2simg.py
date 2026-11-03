#!/usr/bin/env python3
"""Back up a partition over ssh as an Android sparse image that fastboot can flash.

Only non-zero 4 KiB blocks travel; a dump whose unused blocks are zero (e2image -ra)
takes only the space of the used data.
  on the tablet:  <raw stream> | python3 raw2simg.py pack          (records to stdout)
  on the host:    ... | python3 raw2simg.py unpack SIZE out.simg   (Android sparse image)
SIZE is the exact size of the target partition in bytes (blockdev --getsize64).
Both sides print the sha256 of the raw stream (zero blocks included) to stderr.
Restore: fastboot flash userdata out.simg
"""
import hashlib
import struct
import sys

BLK = 4096
MAGIC = 0xED26FF3A
RAW, DONT_CARE = 0xCAC1, 0xCAC3
ZERO = bytes(BLK)
REC = struct.Struct("<QI")  # first block, number of blocks; the data follows
END = 0xFFFFFFFFFFFFFFFF


def pack():
    src, dst = sys.stdin.buffer, sys.stdout.buffer
    sha = hashlib.sha256()
    blk = 0
    run_start, run = 0, []
    buf = b""

    def flush():
        nonlocal run
        if run:
            dst.write(REC.pack(run_start, len(run)))
            dst.write(b"".join(run))
            run = []

    while True:
        data = src.read(256 * BLK)
        if not data:
            break
        sha.update(data)
        buf += data
        n = len(buf) // BLK
        for i in range(n):
            b = buf[i * BLK:(i + 1) * BLK]
            if b == ZERO or len(run) >= 16384:
                flush()
            if b != ZERO:
                if not run:
                    run_start = blk
                run.append(b)
            blk += 1
        buf = buf[n * BLK:]
    if buf:
        sys.exit("stream length is not a multiple of 4096")
    flush()
    dst.write(REC.pack(END, blk))
    dst.flush()
    print(f"pack: {blk} blocks, sha256 {sha.hexdigest()}", file=sys.stderr)


def unpack(size, out_path):
    if size % BLK:
        sys.exit("size is not a multiple of 4096")
    total = size // BLK
    src = sys.stdin.buffer
    out = open(out_path, "wb")
    out.write(bytes(28))  # file header, written at the end
    chunks, pos = 0, 0
    sha = hashlib.sha256()

    def zeros(n):
        nonlocal chunks
        if n:
            out.write(struct.pack("<HHII", DONT_CARE, 0, n, 12))
            chunks += 1
            for _ in range(n // 4096):
                sha.update(ZERO * 4096)
            sha.update(ZERO * (n % 4096))

    while True:
        hdr = src.read(REC.size)
        if len(hdr) != REC.size:
            sys.exit("stream ended without the end record")
        start, n = REC.unpack(hdr)
        if start == END:
            zeros(n - pos)
            pos = n
            break
        data = src.read(n * BLK)
        if len(data) != n * BLK:
            sys.exit("stream cut inside a record")
        zeros(start - pos)
        out.write(struct.pack("<HHII", RAW, 0, n, 12 + len(data)))
        out.write(data)
        sha.update(data)
        chunks += 1
        pos = start + n
    if pos > total:
        sys.exit("stream is larger than the partition")
    if pos < total:
        out.write(struct.pack("<HHII", DONT_CARE, 0, total - pos, 12))
        chunks += 1
    out.seek(0)
    out.write(struct.pack("<IHHHHIIII", MAGIC, 1, 0, 28, 12, BLK, total, chunks, 0))
    out.close()
    print(f"unpack: {pos} blocks in stream, {total} in the partition, {chunks} chunks, sha256 {sha.hexdigest()}", file=sys.stderr)


if __name__ == "__main__":
    if sys.argv[1:2] == ["pack"]:
        pack()
    elif sys.argv[1:2] == ["unpack"]:
        unpack(int(sys.argv[2]), sys.argv[3])
    else:
        sys.exit(__doc__)
