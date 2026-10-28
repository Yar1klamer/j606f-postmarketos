#!/usr/bin/env python3
"""Выполнить команду в shell на USB-ACM консоли отладочного initramfs (ttyGS0) и вывести результат.
Без pyserial: termios в raw-режиме. Конец вывода определяется маркером.
Запуск: python3 -I scripts/acm_run.py /dev/cu.usbmodemXXXX 'команда' [таймаут_с]"""
import os, sys, termios, time, select

dev, cmd = sys.argv[1], sys.argv[2]
timeout = float(sys.argv[3]) if len(sys.argv) > 3 else 20
fd = os.open(dev, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
attrs = termios.tcgetattr(fd)
attrs[0] = 0                      # iflag
attrs[1] = 0                      # oflag
attrs[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
attrs[3] = 0                      # lflag: raw
attrs[4] = attrs[5] = termios.B115200
termios.tcsetattr(fd, termios.TCSANOW, attrs)
termios.tcflush(fd, termios.TCIOFLUSH)

marker = "__J606F_DONE_%d__" % int(time.time() * 1000)
os.write(fd, (f"{cmd}; echo {marker}\n").encode())
buf = b""
end = time.time() + timeout
while time.time() < end:
    r, _, _ = select.select([fd], [], [], 0.5)
    if r:
        try:
            chunk = os.read(fd, 65536)
        except BlockingIOError:
            continue
        buf += chunk
        # маркер встречается дважды: в эхе команды и в выводе echo
        if buf.count(marker.encode()) >= 2 or (buf.count(marker.encode()) == 1 and not buf.startswith(cmd.encode()[:10]) and buf.rstrip().endswith(marker.encode())):
            break
os.close(fd)
out = buf.decode(errors="replace").replace("\r\n", "\n")
sys.stdout.write(out)
