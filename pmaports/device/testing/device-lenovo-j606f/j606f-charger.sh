#!/bin/sh
# Offline charging for Lenovo Tab P11 (TB-J606F).
# ABL boots the kernel when a charger is plugged into a powered-off tablet, but it
# does not pass androidboot.mode=charger. Decide from the PMIC power-on reason
# (PM6125 PON_REASON1, 0x8C0: bit 6 CBL / bit 4 USB = cable, bit 7 = power key) and
# a reboot mark that j606f-reboot-flag leaves in the misc partition (a reboot also
# reads as CBL). In charger mode stay in the initramfs: show the battery level, blank
# the backlight after a while, continue booting on a long Power press, power off when
# the charger is gone. Installed as an initramfs hook (/hooks), runs before the root
# is mounted.

MISC=/dev/disk/by-partlabel/misc
i=0
while [ ! -b "$MISC" ] && [ $i -lt 10 ]; do
	sleep 0.5
	i=$((i + 1))
done
if [ -b "$MISC" ]; then
	mark=$(dd if="$MISC" bs=4096 skip=240 count=1 2>/dev/null | head -c 12)
	if [ "$mark" = "J606F-REBOOT" ]; then
		dd if=/dev/zero of="$MISC" bs=4096 seek=240 count=1 conv=notrunc 2>/dev/null
		exit 0
	fi
fi

if ! grep -q "androidboot.mode=charger" /proc/cmdline; then
	[ -d /sys/kernel/debug/regmap ] || mount -t debugfs debugfs /sys/kernel/debug 2>/dev/null
	reason=$(dd if=/sys/kernel/debug/regmap/0-00/registers bs=9 skip=$((0x8c0)) count=1 2>/dev/null | cut -d" " -f2)
	[ -n "$reason" ] || exit 0
	reason=$((0x$reason))
	# power key pressed, or not powered on by a cable: normal boot
	[ $((reason & 0x80)) -eq 0 ] || exit 0
	[ $((reason & 0x50)) -ne 0 ] || exit 0
fi

echo "[j606f-charger] charger mode"
modprobe -q evdev
modprobe -q mm8013
modprobe -q qcom_pmi632_charger

BAT=/sys/class/power_supply/mm8013
CHG=/sys/class/power_supply/pmi632-charger
BL=$(ls -d /sys/class/backlight/* 2>/dev/null | head -n 1)

backlight() {
	[ -n "$BL" ] && echo "$1" > "$BL/brightness" 2>/dev/null
}

message() {
	echo "[j606f-charger] $1"
	# as splash_set_message in init_functions.sh: show the splash, then the text
	if plymouth --ping 2>/dev/null; then
		plymouth show-splash
		plymouth display-message --text "$(printf '%b' "$1")"
	fi
}

# the battery and the charger probe asynchronously
i=0
while [ ! -e "$BAT/capacity" ] && [ $i -lt 20 ]; do
	sleep 0.5
	i=$((i + 1))
done

i=0
while [ "$(cat "$CHG/online" 2>/dev/null)" != "1" ] && [ $i -lt 10 ]; do
	sleep 0.5
	i=$((i + 1))
done
[ "$(cat "$CHG/online" 2>/dev/null)" = "1" ] || exit 0

BL_ON=$(( $(cat "$BL/max_brightness" 2>/dev/null || echo 4095) / 4 ))
backlight "$BL_ON"
screen_on=1
idle=0
unplugged=0
held=0
tick=0

while true; do
	cap=$(cat "$BAT/capacity" 2>/dev/null || echo "?")
	state=$(cat "$BAT/status" 2>/dev/null || echo "")
	online=$(cat "$CHG/online" 2>/dev/null || echo 1)

	if [ "$online" = "0" ]; then
		unplugged=$((unplugged + 1))
		# charger gone for 5 s: nothing to do here any more
		if [ $unplugged -ge 5 ]; then
			message "Charger removed, powering off"
			sleep 2
			poweroff -f
		fi
	else
		unplugged=0
	fi

	if iskey KEY_POWER; then
		held=$((held + 1))
		idle=0
		if [ $screen_on = 0 ]; then
			backlight "$BL_ON"
			screen_on=1
		fi
		# Power held for 2 s: leave charger mode and continue booting the system
		if [ $held -ge 2 ]; then
			message "Booting..."
			backlight "$BL_ON"
			exit 0
		fi
	else
		held=0
		idle=$((idle + 1))
	fi

	if [ $screen_on = 1 ] && [ $idle -ge 15 ]; then
		backlight 0
		screen_on=0
	fi

	# refresh the text every 10 s and right after waking the screen
	if [ $((tick % 10)) -eq 0 ] || [ $idle -le 1 ]; then
		if [ "$state" = "Full" ]; then
			message "Charged: ${cap}%\nHold Power to boot"
		else
			message "Charging: ${cap}%\nHold Power to boot"
		fi
	fi

	tick=$((tick + 1))
	sleep 1
done
