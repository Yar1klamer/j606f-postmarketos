#!/bin/sh
# Suspend helper for Lenovo Tab P11 (TB-J606F), run by j606f-sleep.service around sleep.target.
# - Sensors: the ADSP sensor_process makes FastRPC calls into hexagonrpcd; with the host frozen
#   the call fails, sensor_process crashes the whole ADSP and its recovery fails (-110), so the
#   ADSP (sensors, audio) stays dead until a reboot. Stop the sensor stack before suspend.
# - Bluetooth: the WCN3990 keeps sending events over its UART, whose RX wake GPIO (msmgpio 11)
#   wakes the system within a second; with the wake disabled the lost bytes break the HCI link
#   (command tx timeout). Power the controller off with rfkill for the time of the suspend.
#   Even rfkill-blocked the UART wakeup IRQ (114, msmgpio 11) fires ~1.7 s into s2idle and
#   turns the sleep into a suspend/resume loop, so the serial wakeup is disabled in "pre"
#   too and restored in "post" (measured 18.11: real 215 s s2idle with it disabled).
# - Pogo dock (i2c_hid_of 0-0060, 1-0061): its resume returns -6 and the suspend is rolled back
#   after a second; the USB3 controller (4ef8800.usb) aborts it with "HS-PHY not in L2". Both
#   are unbound before the suspend and bound again after it (charging goes through the PMIC).
# - The panel does not take the brightness right after a resume ("Invalid response cmd"):
#   it is written again until it sticks. (Pogo, USB3 and brightness: found by kruzeman.)
# Whatever was running before is restored after resume: Bluetooth by j606f-sleep.service when
# sleep.target stops, the sensors by j606f-resume.service once suspend.target is reached.
# The hexagonrpcd-adsp-* units have Conflicts=suspend.target, so systemd stops them itself while
# "pre" runs and is-active can not tell whether they ran: they are restored when enabled.
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
# separate files: "post" and "resume" run at the same time
STATE=/run/j606f-sleep
UNITS=/run/j606f-sleep.units
RPCD="hexagonrpcd-adsp-rootpd.service hexagonrpcd-adsp-sensorspd.service"
HID=/sys/bus/i2c/drivers/i2c_hid_of
HID_CLIENTS="0-0060 1-0061"
USB3=4ef8800.usb
BL=/run/j606f-sleep.brightness
DRV=/run/j606f-sleep.usb3drv
UART=/sys/bus/platform/devices/4a8c000.serial
WAKE=/run/j606f-sleep.uartwake

case "$1" in
pre)
	: > "$STATE"
	: > "$UNITS"
	for u in $RPCD; do
		systemctl -q is-enabled "$u" 2>/dev/null && echo "$u" >> "$UNITS"
	done
	systemctl -q is-active iio-sensor-proxy.service && echo iio-sensor-proxy.service >> "$UNITS"
	systemctl stop iio-sensor-proxy.service $RPCD 2>/dev/null
	if rfkill list bluetooth 2>/dev/null | grep -q "Soft blocked: no"; then
		echo "bluetooth" >> "$STATE"
		rfkill block bluetooth
	fi
	if [ -w "$UART/power/wakeup" ]; then
		cat "$UART/power/wakeup" > "$WAKE"
		echo disabled > "$UART/power/wakeup"
	fi
	for b in /sys/class/backlight/*; do
		[ -r "$b/brightness" ] && { echo "$b $(cat "$b/brightness")" > "$BL"; break; }
	done
	for c in $HID_CLIENTS; do
		[ -e "$HID/$c" ] && echo "$c" > "$HID/unbind" && echo "hid $c" >> "$STATE"
	done
	for d in /sys/bus/platform/drivers/dwc3*; do
		[ -e "$d/$USB3" ] || continue
		echo "$USB3" > "$d/unbind" && echo "$d" > "$DRV"
		break
	done
	;;
post)
	if [ -f "$WAKE" ]; then
		cat "$WAKE" > "$UART/power/wakeup" 2>/dev/null
		rm -f "$WAKE"
	fi
	if [ -f "$DRV" ]; then
		echo "$USB3" > "$(cat "$DRV")/bind"
		rm -f "$DRV"
	fi
	if [ -f "$STATE" ]; then
		for c in $(sed -n 's/^hid //p' "$STATE"); do
			echo "$c" > "$HID/bind"
		done
		grep -q "^bluetooth$" "$STATE" && rfkill unblock bluetooth
		rm -f "$STATE"
	fi
	if [ -f "$BL" ]; then
		read -r b v < "$BL"
		for i in 1 2 3 4 5 6 7 8 9 10; do
			echo "$v" > "$b/brightness" 2>/dev/null
			[ "$(cat "$b/brightness" 2>/dev/null)" = "$v" ] && break
			sleep 0.5
		done
		rm -f "$BL"
	fi
	# let upower and the desktop read the battery again
	udevadm trigger --subsystem-match=power_supply --action=change
	;;
resume)
	[ -f "$UNITS" ] || exit 0
	# the FastRPC servers first, iio-sensor-proxy needs the sensors
	for u in $RPCD iio-sensor-proxy.service; do
		grep -qx "$u" "$UNITS" && systemctl start --no-block "$u"
	done
	rm -f "$UNITS"
	;;
esac
exit 0
