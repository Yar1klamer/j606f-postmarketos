#!/usr/bin/env bash
# Фаза 0, часть 2: ТОЛЬКО ЧТЕНИЕ через fastboot. Планшет в bootloader (adb reboot bootloader).
FB="${FASTBOOT:-$HOME/platform-tools/fastboot}"
OUT="raw/fastboot_$(date +%Y%m%d_%H%M%S)"; mkdir -p "$OUT"
"$FB" devices | tee "$OUT/devices.txt"
"$FB" getvar all > "$OUT/getvar_all.txt" 2>&1
for v in current-slot slot-count is-userspace unlocked secure max-download-size product variant serialno; do
  echo "--- $v"; "$FB" getvar $v 2>&1
done | tee "$OUT/getvar_key.txt"
echo "Папка: $OUT"
