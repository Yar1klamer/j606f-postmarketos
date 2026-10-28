#!/usr/bin/env bash
# Полный цикл: (если планшет в отладочном mainline) reboot → Android → bootloader → fastboot boot IMG →
# ожидание USB-гаджета и ping. Печатает link-local адрес Mac на en* (меняется при каждом подключении).
# Ничего не пишет во внутреннюю память. Запуск: bash scripts/cycle_boot.sh out/IMG.img
set -u
IMG=$1; A=~/platform-tools/adb; F=~/platform-tools/fastboot; H=169.254.42.1
if ping -c1 -t2 $H >/dev/null 2>&1; then
  echo "[cycle] mainline is up -> reboot"
  J606F_TIMEOUT=10 bash "$(dirname "$0")/tcp_run.sh" 'sync; (sleep 1; reboot -f) & (sleep 20; echo b > /proc/sysrq-trigger) & echo bye' || true
fi
for i in $(seq 1 60); do $A devices | grep -q "device$" && break; $F devices | grep -q fastboot && break; sleep 3; done
if $A devices | grep -q "device$"; then
  for i in $(seq 1 40); do [ "$($A shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ] && break; sleep 2; done
  echo "[cycle] android up -> bootloader"; $A reboot bootloader
  for i in $(seq 1 40); do $F devices | grep -q fastboot && break; sleep 2; done
else
  echo "[cycle] already in fastboot -> fresh session"; $F reboot bootloader; sleep 5
  for i in $(seq 1 40); do $F devices | grep -q fastboot && break; sleep 2; done
fi
$F boot "$IMG" 2>&1 | tail -2
for i in $(seq 1 40); do ioreg -p IOUSB -l -w0 2>/dev/null | grep -q '"TB-J606F mainline debug"' && { echo "[cycle] gadget at $((i*3))s"; break; }; sleep 3; done
for i in $(seq 1 30); do ping -c1 -t2 $H >/dev/null 2>&1 && break; sleep 2; done
ping -c1 -t2 $H >/dev/null 2>&1 && echo "[cycle] ping OK" || echo "[cycle] NO PING"
for ifc in $(ifconfig -l); do ifconfig $ifc 2>/dev/null | grep -q "inet 169.254" && echo "[cycle] MAC_IP=$(ifconfig $ifc | awk '/inet 169.254/ {print $2}') ($ifc)"; done
