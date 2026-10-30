#!/bin/sh
# Reboot mark for the offline charging hook (Lenovo TB-J606F): $1 is reboot or poweroff.
# Run by j606f-reboot-mark.service / j606f-poweroff-unmark.service early in the shutdown
# (a systemd-shutdown hook runs too late here: the mark never reached the disk).
# The PMIC can't tell a reboot from a cold boot by the charger (PON_REASON1 = CBL
# both times), so leave a mark on reboot in an unused area of the misc partition
# (0xF0000, Android uses the first 64 KiB); the initramfs charger hook consumes it.
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
MISC=/dev/disk/by-partlabel/misc
[ -b "$MISC" ] || exit 0
case "$1" in
	reboot|kexec)
		printf 'J606F-REBOOT' | dd of="$MISC" bs=4096 seek=240 conv=notrunc,fsync 2>/dev/null
		;;
	*)
		dd if=/dev/zero of="$MISC" bs=4096 seek=240 count=1 conv=notrunc,fsync 2>/dev/null
		;;
esac
exit 0
