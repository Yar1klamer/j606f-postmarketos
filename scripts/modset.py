#!/usr/bin/env python3
"""Набор модулей с зависимостями для загрузки на лету (insmod по порядку).
Берёт модули из каталога пакета ядра (.ko.zst) плюс собранные отдельно (--extra-ko, имеют приоритет),
раскрывает depends= из .modinfo, распаковывает в OUTDIR/<name>.ko и пишет OUTDIR/order.
Запуск: $VENV/bin/python -I scripts/modset.py MODDIR OUTDIR name [name...] [--extra-ko X.ko ...]"""
import io, os, sys
import zstandard

args = sys.argv[1:]
extra = []
while "--extra-ko" in args:
    i = args.index("--extra-ko")
    extra.append(args[i + 1])
    del args[i:i + 2]
moddir, outdir, names = args[0], args[1], args[2:]
dctx = zstandard.ZstdDecompressor()
idx = {}
for root, _, files in os.walk(moddir):
    for f in files:
        if f.endswith((".ko", ".ko.zst")):
            idx[f.split(".ko")[0].replace("-", "_")] = os.path.join(root, f)
for e in extra:
    idx[os.path.basename(e).split(".ko")[0].replace("-", "_")] = e


def read(n):
    p = idx[n]
    raw = open(p, "rb").read()
    return dctx.stream_reader(io.BytesIO(raw)).read() if p.endswith(".zst") else raw


def deps(raw):
    for part in raw.split(b"\0"):
        if part.startswith(b"depends="):
            return [d for d in part[8:].decode().split(",") if d]
    return []


order, seen = [], set()


def visit(n):
    n = n.replace("-", "_")
    if n in seen:
        return
    seen.add(n)
    if n not in idx:
        raise SystemExit(f"module {n} not found")
    for d in deps(read(n)):
        visit(d)
    order.append(n)


for n in names:
    visit(n)
os.makedirs(outdir, exist_ok=True)
for n in order:
    open(os.path.join(outdir, n + ".ko"), "wb").write(read(n))
open(os.path.join(outdir, "order"), "w").write("\n".join(order) + "\n")
print(" ".join(order))
