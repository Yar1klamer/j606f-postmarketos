#!/usr/bin/env bash
# Бэкап разделов с устройства (только чтение: dd if=раздел → stdout → файл на Mac).
# Требует root (Magisk). sha256 считается и на устройстве, и на Mac, затем сравнивается.
# Запуск из ./pmos-j606f:  bash scripts/backup_partitions.sh [раздел ...]
# Без аргументов: все разделы из by-name, кроме userdata (и кроме целых LUN sda..sdf).
set -u
ADB="${ADB:-$HOME/platform-tools/adb}"
OUT="BACKUP/partitions"; mkdir -p "$OUT"
SUMS="$OUT/SHA256SUMS"; LOGF="$OUT/backup.log"
BN=/dev/block/bootdevice/by-name

if [ $# -gt 0 ]; then parts="$*"; else
  parts=$("$ADB" shell "su -c 'ls $BN'" | tr -d '\r' | grep -vxE 'userdata|sd[a-f]')
fi

for p in $parts; do
  f="$OUT/$p.img"
  if [ -s "$f" ] && grep -q " $p.img\$" "$SUMS" 2>/dev/null; then echo "skip $p (уже есть)"; continue; fi
  dev_sum=$("$ADB" shell "su -c 'sha256sum $BN/$p'" | tr -d '\r' | awk '{print $1}')
  "$ADB" exec-out "su -c 'dd if=$BN/$p bs=4M 2>/dev/null'" > "$f"
  host_sum=$(shasum -a 256 "$f" | awk '{print $1}')
  size=$(stat -f %z "$f")
  if [ "$dev_sum" = "$host_sum" ] && [ "$size" -gt 0 ]; then
    echo "$host_sum  $p.img" >> "$SUMS"
    echo "OK   $p size=$size sha256=$host_sum" | tee -a "$LOGF"
  else
    echo "FAIL $p size=$size dev=$dev_sum host=$host_sum" | tee -a "$LOGF"
    mv "$f" "$f.bad"
  fi
done
