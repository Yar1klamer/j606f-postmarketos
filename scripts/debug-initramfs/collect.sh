#!/bin/sh
# Сбор диагностики в отладочном initramfs mainline (только чтение). Результат: /tmp/info.tar
O=/tmp/info; rm -rf $O; mkdir -p $O
c() { n=$1; shift; sh -c "$*" > $O/$n.txt 2>&1; }
c dmesg dmesg
c cmdline cat /proc/cmdline
c bootargs "cat /sys/firmware/devicetree/base/chosen/bootargs"
c partitions cat /proc/partitions
c lsblk "lsblk 2>/dev/null; ls -l /sys/block/"
c meminfo cat /proc/meminfo
c cpuinfo cat /proc/cpuinfo
c interrupts cat /proc/interrupts
c iomem cat /proc/iomem
c modules "lsmod; cat /proc/modules"
c deferred "cat /sys/kernel/debug/devices_deferred"
c clk "cat /sys/kernel/debug/clk/clk_summary"
c regulators "cat /sys/kernel/debug/regulator/regulator_summary"
c thermal 'for d in /sys/class/thermal/thermal_zone*; do echo "$(basename $d) $(cat $d/type) $(cat $d/temp)"; done'
c cpufreq 'for c in /sys/devices/system/cpu/cpu[0-7]; do echo "$c cur=$(cat $c/cpufreq/scaling_cur_freq 2>&1) avail=$(cat $c/cpufreq/scaling_available_frequencies 2>&1) gov=$(cat $c/cpufreq/scaling_governor 2>&1)"; done'
c power_supply 'ls -l /sys/class/power_supply; for d in /sys/class/power_supply/*; do echo == $d; cat $d/uevent; done'
c input "cat /proc/bus/input/devices"
c drm "ls -l /sys/class/drm /sys/class/backlight /sys/class/graphics 2>&1; cat /sys/class/graphics/fb0/virtual_size /sys/class/graphics/fb0/stride 2>&1"
c pstore "ls -la /sys/fs/pstore /tmp/pstore-prev"
c platform 'for d in /sys/bus/platform/devices/*; do echo "$(basename $d) drv=$(basename $(readlink $d/driver) 2>/dev/null)"; done'
c gpio "cat /sys/kernel/debug/gpio"
c pinctrl "cat /sys/kernel/debug/pinctrl/*/pinmux-pins 2>/dev/null | head -300"
c remoteproc 'for r in /sys/class/remoteproc/*; do echo "$r $(cat $r/name) $(cat $r/state) $(cat $r/firmware)"; done'
c typec "ls -lR /sys/class/typec /sys/class/usb_role 2>&1"
c dt_model "cat /proc/device-tree/model; echo; ls /proc/device-tree; ls /proc/device-tree/abl-sink | head -50"
cp /sys/firmware/fdt $O/live-mainline.dtb
cp -a /tmp/pstore-prev $O/ 2>/dev/null
cp /tmp/dmesg.boot $O/ 2>/dev/null
tar cf /tmp/info.tar -C /tmp info
ls -l /tmp/info.tar
