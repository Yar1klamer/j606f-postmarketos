import struct, sys

FDT_BEGIN_NODE, FDT_END_NODE, FDT_PROP, FDT_NOP, FDT_END = 1, 2, 3, 4, 9


def parse(data):
    magic, totalsize, off_struct, off_strings = struct.unpack_from(">4sII I", data, 0)[0], None, None, None
    magic = data[:4]
    assert magic == b"\xd0\x0d\xfe\xed", magic
    totalsize, off_struct, off_strings = struct.unpack_from(">I", data, 4)[0], struct.unpack_from(">I", data, 8)[0], struct.unpack_from(">I", data, 12)[0]
    nodes = {}
    stack = []
    p = off_struct
    while True:
        tok = struct.unpack_from(">I", data, p)[0]; p += 4
        if tok == FDT_BEGIN_NODE:
            end = data.index(b"\0", p)
            name = data[p:end].decode(errors="replace")
            p = (end + 1 + 3) & ~3
            stack.append(name)
            path = "/" + "/".join([s for s in stack if s])
            nodes.setdefault(path, {})
        elif tok == FDT_END_NODE:
            if stack: stack.pop()
        elif tok == FDT_PROP:
            ln, nameoff = struct.unpack_from(">II", data, p); p += 8
            s_end = data.index(b"\0", off_strings + nameoff)
            pname = data[off_strings + nameoff:s_end].decode()
            val = data[p:p + ln]
            p = (p + ln + 3) & ~3
            path = "/" + "/".join([s for s in stack if s])
            nodes.setdefault(path, {})[pname] = val
        elif tok == FDT_NOP:
            continue
        elif tok == FDT_END:
            break
        else:
            raise ValueError("bad token %x at %x" % (tok, p))
    return nodes


if __name__ == "__main__":
    path, prop = sys.argv[1], sys.argv[2]
    for f in sys.argv[3:]:
        n = parse(open(f, "rb").read())
        v = n.get(path, {}).get(prop)
        print(f"{f}: {v.hex() if v is not None else 'MISSING'}")
