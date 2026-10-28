#!/usr/bin/env bash
# Фаза 0, часть 3: сбор данных под root (Magisk). Только чтение.
# Запуск из ./pmos-j606f:  bash scripts/phase0_root.sh
ADB="${ADB:-$HOME/platform-tools/adb}"
OUT="raw/root_$(date +%Y%m%d)"; mkdir -p "$OUT"
r() { n="$1"; shift; echo "== $n"; "$ADB" shell "su -c '$*'" > "$OUT/$n.txt" 2>&1; }
r cmdline        cat /proc/cmdline
r dmesg          dmesg
r partitions     cat /proc/partitions
r input_devices  cat /proc/bus/input/devices
r asound         'cat /proc/asound/cards /proc/asound/devices /proc/asound/pcm'
r lsmod          lsmod
r iomem          cat /proc/iomem
r interrupts     cat /proc/interrupts
r i2c_names      'for d in /sys/bus/i2c/devices/*; do echo "$d name=$(cat $d/name 2>/dev/null) drv=$(basename $(readlink $d/driver) 2>/dev/null) of=$(cat $d/of_node/compatible 2>/dev/null | tr \\0 " ")"; done'
r spi_names      'for d in /sys/bus/spi/devices/*; do echo "$d modalias=$(cat $d/modalias) drv=$(basename $(readlink $d/driver) 2>/dev/null) of=$(cat $d/of_node/compatible 2>/dev/null | tr \\0 " ")"; done'
r platform_drv   'for d in /sys/bus/platform/devices/*; do echo "$(basename $d) drv=$(basename $(readlink $d/driver) 2>/dev/null)"; done'
r regulators     'for d in /sys/class/regulator/regulator.*; do echo "$(basename $d) name=$(cat $d/name) uV=$(cat $d/microvolts 2>/dev/null) state=$(cat $d/state 2>/dev/null)"; done'
r power_supply   'for d in /sys/class/power_supply/*; do echo "== $d"; cat $d/uevent; done'
r backlight_leds 'ls -l /sys/class/backlight /sys/class/leds; for d in /sys/class/backlight/* /sys/class/leds/*; do echo "$d max=$(cat $d/max_brightness 2>/dev/null) cur=$(cat $d/brightness 2>/dev/null)"; done'
r iio            'for d in /sys/bus/iio/devices/iio:device*; do echo "$d $(cat $d/name)"; ls $d | head -60; done'
r thermal        'for d in /sys/class/thermal/thermal_zone*; do echo "$(basename $d) $(cat $d/type) $(cat $d/temp)"; done'
r cpufreq        'for c in /sys/devices/system/cpu/cpu[0-7]; do echo "$c $(cat $c/cpufreq/scaling_available_frequencies 2>/dev/null)"; done'
r gpu            'cat /sys/class/kgsl/kgsl-3d0/gpu_model /sys/class/kgsl/kgsl-3d0/gpuclk /sys/class/kgsl/kgsl-3d0/devfreq/available_frequencies 2>&1'
r drm            'ls -l /sys/class/drm; cat /sys/class/drm/*/modes 2>/dev/null; cat /sys/kernel/debug/dri/0/name 2>/dev/null'
r usb            'ls -l /sys/class/typec /sys/class/udc /config/usb_gadget 2>&1; cat /sys/class/udc/*/uevent 2>&1'
r wifi_bt        'ls -lR /vendor/firmware_mnt/image 2>&1 | head -200; ls -lR /vendor/bt_firmware 2>&1 | head -80; ls -l /vendor/firmware 2>&1 | head -200; ls -l /vendor/etc/wifi /vendor/firmware/wlan 2>&1; ls -lR /mnt/vendor/persist 2>&1 | head -200'
r dsp            'ls -lR /vendor/dsp 2>&1 | head -100'
r mounts         cat /proc/mounts
r gpio           'cat /sys/kernel/debug/gpio 2>&1 | head -400'
r pinctrl        'ls /sys/kernel/debug/pinctrl 2>&1'
r clk_summary    'cat /sys/kernel/debug/clk/clk_summary 2>&1 | head -600'
r reg_summary    'cat /sys/kernel/debug/regulator/regulator_summary 2>&1'
r cpuinfo_soc    'cat /sys/devices/soc0/soc_id /sys/devices/soc0/family /sys/devices/soc0/machine /sys/devices/soc0/revision /sys/devices/soc0/raw_id /sys/devices/soc0/hw_platform /sys/devices/soc0/platform_version /sys/devices/soc0/platform_subtype 2>&1'
echo "== fdt"
"$ADB" exec-out "su -c 'cat /sys/firmware/fdt'" > "$OUT/live.dtb"
echo "== devicetree tar"
"$ADB" exec-out "su -c 'cd /proc/device-tree && tar cf - . 2>/dev/null'" > "$OUT/devicetree.tar"
ls -l "$OUT"
