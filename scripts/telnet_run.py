#!/usr/bin/env python3
"""Команда в отладочном shell initramfs pmOS по telnet (172.16.42.1:23), вывод до маркера.
Запуск: python3 -I scripts/telnet_run.py 'команда' [таймаут]"""
import socket, sys, time
cmd = sys.argv[1]; tmo = float(sys.argv[2]) if len(sys.argv) > 2 else 30
s = socket.create_connection(("172.16.42.1", 23), timeout=tmo)
buf = b""
def pump(t):
    global buf
    end = time.time() + t
    s.settimeout(0.3)
    while time.time() < end:
        try:
            d = s.recv(65536)
        except socket.timeout:
            continue
        if not d:
            break
        out = b""
        i = 0
        while i < len(d):  # ответ отказом на все telnet-опции
            if d[i] == 255 and i + 2 < len(d):
                c, o = d[i + 1], d[i + 2]
                if c in (251, 252): s.sendall(bytes([255, 254, o]))
                elif c in (253, 254): s.sendall(bytes([255, 252, o]))
                i += 3
            else:
                out += d[i:i + 1]; i += 1
        buf += out
        if MARK.encode() + b"\r\n" in buf or MARK.encode() + b"\n" in buf:
            if buf.count(MARK.encode()) >= 2: break
MARK = "__TN_%d__" % int(time.time())
pump(2)
buf = b""
s.sendall((cmd + "; echo " + MARK + "\n").encode())
pump(tmo)
txt = buf.decode(errors="replace").replace("\r", "")
lines = [l for l in txt.split("\n") if MARK not in l]
print("\n".join(lines))
