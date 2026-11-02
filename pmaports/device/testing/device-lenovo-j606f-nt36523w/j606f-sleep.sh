#!/bin/sh
# Suspend helper for Lenovo Tab P11 (TB-J606F), run by j606f-sleep.service around sleep.target.
# - Sensors: the ADSP sensor_process makes FastRPC calls into hexagonrpcd; with the host frozen
#   the call fails, sensor_process crashes the whole ADSP and its recovery fails (-110), so the
#   ADSP (sensors, audio) stays dead until a reboot. Stop the sensor stack before suspend.
# - Bluetooth: the WCN3990 keeps sending events over its UART, whose RX wake GPIO (msmgpio 11)
#   wakes the system within a second; with the wake disabled the lost bytes break the HCI link
#   (command tx timeout). Power the controller off with rfkill for the time of the suspend.
# Whatever was running before is restored after resume: Bluetooth by j606f-sleep.service when
# sleep.target stops, the sensors by j606f-resume.service once suspend.target is reached.
# The hexagonrpcd-adsp-* units have Conflicts=suspend.target, so systemd stops them itself while
# "pre" runs and is-active can not tell whether they ran: they are restored when enabled.
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
# separate files: "post" and "resume" run at the same time
STATE=/run/j606f-sleep
UNITS=/run/j606f-sleep.units
RPCD="hexagonrpcd-adsp-rootpd.service hexagonrpcd-adsp-sensorspd.service"

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
	;;
post)
	[ -f "$STATE" ] || exit 0
	grep -q "^bluetooth$" "$STATE" && rfkill unblock bluetooth
	rm -f "$STATE"
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
