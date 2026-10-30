#!/usr/bin/env bash
# Снять со стокового Android (root Magisk, только чтение) всё, что нужно pmOS из прошивки Lenovo:
#   /vendor/firmware_mnt (раздел modem: modem, adsp, cdsp, wlanmdsp, venus), /vendor/firmware (GPU zap, тач, усилители),
#   /vendor/bt_firmware, /vendor/dsp (библиотеки ADSP для датчиков), /vendor/etc/sensors, /mnt/vendor/persist/sensors,
#   плюс версии и cmdline (ревизия панели). Результат: FIRMWARE/<дата>/*.tar + SHA256SUMS
#   и собранный из них FIRMWARE/<дата>/firmware-lenovo-j606f-1.tar (scripts/build_firmware_package.sh).
# Это проприетарные файлы ВАШЕГО устройства: не публикуйте их.
# Запуск (adb в PATH или ADB=путь):  bash scripts/collect_firmware.sh
set -eu
ADB="${ADB:-adb}"
OUT="FIRMWARE/$(date +%Y%m%d_%H%M%S)"; mkdir -p "$OUT"

"$ADB" shell 'su -c id' | tr -d '\r' | grep -q 'uid=0' || { echo "нет root (Magisk): su -c id не вернул uid=0"; exit 1; }

r() { "$ADB" exec-out "su -c '$1'" > "$2"; }
r 'cat /proc/cmdline' "$OUT/cmdline.txt"
r 'getprop' "$OUT/getprop.txt"
for spec in vendor_firmware_mnt:/vendor/firmware_mnt vendor_firmware:/vendor/firmware vendor_bt_firmware:/vendor/bt_firmware \
            vendor_dsp:/vendor/dsp vendor_etc_sensors:/vendor/etc/sensors persist_sensors:/mnt/vendor/persist/sensors; do
	name=${spec%%:*}; dir=${spec#*:}
	echo "== $dir"
	r "cd $dir && tar cf - . 2>/dev/null" "$OUT/$name.tar"
	tar -tf "$OUT/$name.tar" > /dev/null || { echo "битый архив: $OUT/$name.tar"; exit 1; }
done
( cd "$OUT" && shasum -a 256 ./* > SHA256SUMS 2>/dev/null || sha256sum ./* > SHA256SUMS )
# Сразу собрать персональный тарбол для pmaports (firmware-lenovo-j606f-1.tar, включая Venus для H.264/HEVC).
bash "$(dirname "$0")/build_firmware_package.sh" "$OUT"
grep -o 'msm_drm.dsi_display0=[^ ]*' "$OUT/cmdline.txt" || true
echo "готово: $OUT"
