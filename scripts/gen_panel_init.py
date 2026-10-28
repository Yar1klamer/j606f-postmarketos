#!/usr/bin/env python3
"""Генерирует C-функцию init для panel-himax-hx83102.c из расшифрованного on-command стока
(notes/stock_dt/panel_hx83102p_on_cmds.txt). Финальный 0x29 (display on) не включается:
его посылает hx83102_prepare() после init.
Запуск: python3 -I scripts/gen_panel_init.py notes/stock_dt/panel_hx83102p_on_cmds.txt > out.c"""
import re, sys

MACROS = {
    0xb1: "HX83102_SETPOWER", 0xb2: "HX83102_SETDISP", 0xb4: "HX83102_SETCYC",
    0xb9: "HX83102_SETEXTC", 0xba: "HX83102_SETMIPI", 0xbb: "HX83102_UNKNOWN_BB",
    0xbd: "HX83102_SETBANK", 0xbf: "HX83102_SETPTBA", 0xc0: "HX83102_SETSTBA",
    0xc6: "HX83102_UNKNOWN_C6", 0xc7: "HX83102_SETTCON", 0xc8: "HX83102_SETRAMDMY",
    0xc9: "HX83102_SETPWM", 0xcb: "HX83102_SETCLOCK", 0xcc: "HX83102_SETPANEL",
    0xd0: "HX83102_SETCASCADE", 0xd1: "HX83102_SETPCTRL", 0xd2: "HX83102_UNKNOWN_D2",
    0xd3: "HX83102_SETGIP0", 0xd5: "HX83102_SETGIP1", 0xd6: "HX83102_SETGIP2",
    0xd8: "HX83102_SETGIP3", 0xe0: "HX83102_SETGMA", 0xe1: "HX83102_UNKNOWN_E1",
    0xe7: "HX83102_SETTP1", 0xe9: "HX83102_SETSPCCMD",
    0x51: "MIPI_DCS_SET_DISPLAY_BRIGHTNESS", 0x53: "MIPI_DCS_WRITE_CONTROL_DISPLAY",
}

def wrap(head, args, indent="\t\t\t\t     "):
    out, line = [], head
    for i, a in enumerate(args):
        tok = a + ("," if i < len(args) - 1 else ");")
        if len(line) + 1 + len(tok) > 92:
            out.append(line)
            line = indent + tok
        else:
            line += (" " if not line.endswith("(") else "") + tok
    out.append(line)
    return "\n".join(out)

cmds = []
for l in open(sys.argv[1]):
    m = re.match(r"type=0x([0-9a-f]+) wait=(\d+)ms len=\d+: (.*)", l.strip())
    t, wait, data = int(m.group(1), 16), int(m.group(2)), [int(x, 16) for x in m.group(3).split()]
    cmds.append((t, wait, data))

print("static int lenovo_j606f_boe_hx83102p_init(struct hx83102 *ctx)\n{")
print("\tstruct mipi_dsi_multi_context dsi_ctx = { .dsi = ctx->dsi };\n")
print("\tmsleep(60);\n")
for t, wait, d in cmds:
    if d[0] == 0x29:
        continue  # display on: отправит hx83102_prepare()
    if d[0] == 0x11:
        print("\tmipi_dsi_dcs_exit_sleep_mode_multi(&dsi_ctx);")
    else:
        name = MACROS.get(d[0], f"0x{d[0]:02x}")
        args = [f"0x{x:02x}" for x in d[1:]]
        head = f"\tmipi_dsi_dcs_write_seq_multi(&dsi_ctx, {name},"
        print(wrap(head, args) if args else head[:-1] + ");")
    if wait >= 20:
        print(f"\tmipi_dsi_msleep(&dsi_ctx, {wait});")
    elif wait:
        print(f"\tmipi_dsi_usleep_range(&dsi_ctx, {wait * 1000}, {wait * 1000 + 1000});")
print("\n\treturn dsi_ctx.accum_err;\n}")
