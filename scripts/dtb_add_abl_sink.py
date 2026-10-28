#!/usr/bin/env python3
"""Обход наложения стокового dtbo в ABL без записи на устройство.

ABL Lenovo TB-J606F всегда накладывает оверлей из раздела dtbo (запись «Lenovo P11 WIFI PVT») на DTB
из boot.img. В mainline DTB нет __symbols__, libufdt не может разрешить __fixups__, и BootLinux падает
(fastboot boot: «Booting OKAY», затем возврат в fastboot).

Скрипт добавляет в DTB:
  /abl-sink            без compatible и со status = "disabled": of_platform_populate его не трогает
  /abl-sink/<label>    по узлу на каждую метку из __fixups__ стоковых оверлеев, у каждого свой phandle
  /__symbols__         <label> = "/abl-sink/<label>"
После наложения весь «мусор» стокового оверлея оседает внутри /abl-sink.

Запуск (venv с пакетом fdt):
  python -I scripts/dtb_add_abl_sink.py IN.dtb LABELS.txt OUT.dtb"""
import sys
import fdt

src, labels_file, dst = sys.argv[1:4]
d = fdt.parse_dtb(open(src, "rb").read())
labels = [l.strip() for l in open(labels_file) if l.strip()]


def max_phandle(node):
    m = 0
    p = node.get_property("phandle")
    if p:
        m = p.value
    for n in node.nodes:
        m = max(m, max_phandle(n))
    return m


ph = max_phandle(d.root) + 1
assert not d.exist_node("/abl-sink") and not d.exist_node("/__symbols__")
sink = fdt.Node("abl-sink")
sink.append(fdt.PropStrings("status", "disabled"))
syms = fdt.Node("__symbols__")
for l in labels:
    n = fdt.Node(l)
    n.append(fdt.PropWords("phandle", ph))
    ph += 1
    sink.append(n)
    syms.append(fdt.PropStrings(l, "/abl-sink/" + l))
d.add_item(sink, "/")
d.add_item(syms, "/")
blob = d.to_dtb(version=17)
open(dst, "wb").write(blob)
print(f"{dst}: {len(blob)} bytes, {len(labels)} labels, phandles up to {ph - 1:#x}")
