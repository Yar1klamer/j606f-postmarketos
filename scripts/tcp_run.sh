#!/usr/bin/env bash
# Выполнить команды (stdin или $1) в shell отладочного initramfs через nc-сервер
# (на устройстве: nc -lk -p 9100 -e /bin/sh). Читает вывод до закрытия соединения сервером.
# Пример: bash scripts/tcp_run.sh 'uname -a'   или   bash scripts/tcp_run.sh < cmds.sh
HOST="${J606F_HOST:-169.254.42.1}"; PORT="${J606F_PORT:-9100}"; TMO="${J606F_TIMEOUT:-600}"
if [ $# -gt 0 ]; then printf '%s\nexit\n' "$1"; else cat; printf '\nexit\n'; fi | python3 -I -c '
import socket, sys
s = socket.create_connection((sys.argv[1], int(sys.argv[2])), timeout=float(sys.argv[3]))
s.sendall(sys.stdin.buffer.read()); s.shutdown(socket.SHUT_WR)
while True:
    d = s.recv(65536)
    if not d: break
    sys.stdout.buffer.write(d); sys.stdout.flush()
' "$HOST" "$PORT" "$TMO"
