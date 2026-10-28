#!/usr/bin/env bash
# Фаза 0, часть 1: ТОЛЬКО ЧТЕНИЕ через adb (Android загружен, USB-отладка включена).
# Запуск из ./pmos-j606f:  bash scripts/phase0_adb.sh
ADB="${ADB:-$HOME/platform-tools/adb}"
OUT="raw/adb_$(date +%Y%m%d_%H%M%S)"; mkdir -p "$OUT"
run() { n="$1"; shift; echo "== $n"; "$ADB" shell "$@" > "$OUT/$n.txt" 2>&1; }
"$ADB" devices -l | tee "$OUT/devices.txt"
run id            'id; su -c id 2>&1 | head -1'
run getprop       getprop
run cmdline       'cat /proc/cmdline'
run version       'cat /proc/version'
run cpuinfo       'cat /proc/cpuinfo'
run meminfo       'head -3 /proc/meminfo'
run partitions    'cat /proc/partitions'
run by_name       'ls -l /dev/block/by-name /dev/block/bootdevice/by-name 2>&1'
run mounts        'cat /proc/mounts'
run dmesg         'dmesg 2>&1 | head -4000'
run lsmod         'lsmod 2>&1'
run input_devices 'cat /proc/bus/input/devices'
run asound        'cat /proc/asound/cards /proc/asound/devices 2>&1'
run iio           'ls -l /sys/bus/iio/devices/ 2>&1; for d in /sys/bus/iio/devices/iio:device*; do echo $d; cat $d/name 2>&1; done'
run sensors       'dumpsys sensorservice 2>&1 | head -150'
run battery       'dumpsys battery; ls /sys/class/power_supply 2>&1'
run display       'dumpsys display 2>&1 | head -120; wm size; wm density; ls /sys/class/backlight /sys/class/leds 2>&1'
run i2c_spi       'ls -l /sys/bus/i2c/devices /sys/bus/spi/devices 2>&1'
run i2c_names     'for d in /sys/bus/i2c/devices/*; do echo "$d $(cat $d/name 2>&1) $(readlink $d/driver 2>&1)"; done'
run wifi_bt       'ls /vendor/firmware /vendor/firmware_mnt /vendor/etc/wifi 2>&1 | head -150; getprop | grep -iE "wifi|bt|bluetooth"'
run regulators    'ls /sys/class/regulator 2>&1 | head -200'
run packages_hw   'pm list features 2>&1 | head -120'
run slots         'getprop ro.boot.slot_suffix; getprop ro.boot.dynamic_partitions; getprop ro.boot.verifiedbootstate; getprop ro.boot.vbmeta.device_state; getprop ro.boot.flash.locked'
run dt_model      'cat /proc/device-tree/model /proc/device-tree/compatible 2>&1 | tr "\0" "\n"'
echo "== device-tree (pull, best-effort, 120s)"
( perl -e "alarm 120; exec @ARGV" "$ADB" pull /sys/firmware/devicetree/base "$OUT/devicetree" > "$OUT/devicetree_pull.log" 2>&1 || true )
echo "== lsusb/lspci на хосте не нужны; готово. Папка: $OUT"
echo "Прислать: tar czf phase0_adb.tgz $OUT  (или вставить ключевое: getprop.txt, cmdline.txt, by_name.txt, id.txt)"
