#!/bin/sh
# Lenovo Tab P11 (TB-J606F): take the missing Lenovo firmware from this tablet's own stock partitions,
# so nothing proprietary has to be shipped in packages. Only files that are not installed yet are added
# (a firmware-lenovo-j606f package, if present, always wins); nothing is ever written to the partitions:
#   modem_a/b (vfat, NON-HLOS)  image/{adsp,cdsp,modem,venus}.mdt+.bNN -> .mbn, image/wlanmdsp.mbn
#   bluetooth_a/b (vfat)        image/crbtfw21.tlv, image/crnv21.bin
#   super -> vendor_a/b (ext4)  firmware/a610_zap.mdt+.bNN -> .mbn (GPU), firmware/Himax_*.bin (touch)
# vendor lives in super, which a pmOS install into userdata leaves alone; if super was overwritten,
# the GPU and touch firmware can only come from a backup (scripts/build_firmware_package.sh).
#   firmware-extract          add what is missing (apk post-install/post-upgrade; reboot afterwards)
#   firmware-extract --boot   the same at boot, then start the DSPs and Venus that missed their firmware
# For testing: J606F_FIRMWARE_ROOT=<dir> writes there instead of /lib/firmware.
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
FW=${J606F_FIRMWARE_ROOT:-/lib/firmware}
QC=$FW/qcom/sm6115/LENOVO/J606F
LIST=${J606F_FIRMWARE_ROOT:-/var/lib/j606f}/firmware-extract.list
BOOT=0
[ "${1:-}" = "--boot" ] && BOOT=1

# only on the tablet itself, not in the pmbootstrap chroot that builds the image
grep -q "lenovo,j606f" /proc/device-tree/compatible 2>/dev/null || exit 0

log() {
	echo "j606f-firmware: $*"
	[ $BOOT = 1 ] || return 0
	echo "j606f-firmware: $*" > /dev/kmsg 2>/dev/null
}

missing() {
	for f in "$@"; do
		[ -s "$f" ] || return 0
	done
	return 1
}

MODEM_FILES="$QC/adsp.mbn $QC/cdsp.mbn $QC/modem.mbn $QC/venus.mbn $QC/wlanmdsp.mbn"
BT_FILES="$FW/qca/crbtfw21.tlv $FW/qca/crnv21.bin"
VENDOR_FILES="$QC/a610_zap.mbn $FW/Himax_firmware.bin $FW/Himax_mpfw.bin"
missing $MODEM_FILES $BT_FILES $VENDOR_FILES || exit 0

part() {
	if [ -b "/dev/disk/by-partlabel/$1" ]; then
		echo "/dev/disk/by-partlabel/$1"
		return 0
	fi
	for u in /sys/class/block/*/uevent; do
		if grep -qx "PARTNAME=$1" "$u"; then
			echo "/dev/$(sed -n 's/^DEVNAME=//p' "$u")"
			return 0
		fi
	done
	return 1
}

TMP=$(mktemp -d /tmp/j606f-firmware.XXXXXX) || exit 1
MNT=$TMP/mnt
mkdir -p "$MNT"
MAPPED=""
cleanup() {
	mountpoint -q "$MNT" && umount "$MNT"
	for m in $MAPPED; do
		dmsetup remove "$m" 2>/dev/null
	done
	rm -rf "$TMP"
}
trap cleanup EXIT INT TERM

ADDED=""
add() {	# add <source> <target>: install one file if the target is still missing
	[ -s "$2" ] && return 0
	[ -s "$1" ] || return 0
	mkdir -p "$(dirname "$2")"
	cp "$1" "$2.new" && chmod 644 "$2.new" && mv "$2.new" "$2" || { rm -f "$2.new"; return 1; }
	mkdir -p "$(dirname "$LIST")"
	echo "$2" >> "$LIST"
	ADDED="$ADDED $(basename "$2")"
	log "added $2 (from $3)"
}

squash() {	# squash <dir> <name> <target> <origin>: .mdt + .bNN -> one ELF .mbn
	[ -s "$3" ] && return 0
	[ -s "$1/$2.mdt" ] || return 0
	pil-squasher "$TMP/$2.mbn" "$1/$2.mdt" >/dev/null 2>&1 || { log "pil-squasher failed for $1/$2.mdt"; return 1; }
	# a valid result is an ELF image
	[ "$(head -c 4 "$TMP/$2.mbn" | tail -c 3)" = "ELF" ] || { log "$2.mbn: not an ELF image, skipped"; return 1; }
	add "$TMP/$2.mbn" "$3" "$4"
}

# mount_ro <device> <fstype>
mount_ro() {
	case "$2" in
	ext4) mount -t ext4 -o ro,noload,nodev,nosuid,noexec "$1" "$MNT" 2>/dev/null ;;
	*) mount -t "$2" -o ro,nodev,nosuid,noexec "$1" "$MNT" 2>/dev/null ;;
	esac
}

for s in _a _b; do
	missing $MODEM_FILES || break
	dev=$(part "modem$s") || continue
	mount_ro "$dev" vfat || continue
	for n in adsp cdsp modem venus; do
		squash "$MNT/image" "$n" "$QC/$n.mbn" "modem$s"
	done
	add "$MNT/image/wlanmdsp.mbn" "$QC/wlanmdsp.mbn" "modem$s"
	umount "$MNT"
done

for s in _a _b; do
	missing $BT_FILES || break
	dev=$(part "bluetooth$s") || continue
	mount_ro "$dev" vfat || continue
	add "$MNT/image/crbtfw21.tlv" "$FW/qca/crbtfw21.tlv" "bluetooth$s"
	add "$MNT/image/crnv21.bin" "$FW/qca/crnv21.bin" "bluetooth$s"
	umount "$MNT"
done

if missing $VENDOR_FILES && super=$(part super) && command -v make-dynpart-mappings >/dev/null; then
	for n in 0 1; do
		missing $VENDOR_FILES || break
		s=$([ $n = 0 ] && echo _a || echo _b)
		if [ ! -b "/dev/mapper/vendor$s" ]; then
			before=$(dmsetup ls 2>/dev/null | cut -f1)
			# no valid LP metadata (super overwritten): nothing to map. The tool finds super by its PARTLABEL.
			make-dynpart-mappings "$super" "$n" >/dev/null 2>&1 || continue
			for m in $(dmsetup ls 2>/dev/null | cut -f1); do
				echo "$before" | grep -qx "$m" && continue
				MAPPED="$MAPPED $m"
				blockdev --setro "/dev/mapper/$m" 2>/dev/null
			done
		fi
		[ -b "/dev/mapper/vendor$s" ] || continue
		mount_ro "/dev/mapper/vendor$s" ext4 || continue
		squash "$MNT/firmware" a610_zap "$QC/a610_zap.mbn" "vendor$s"
		add "$MNT/firmware/Himax_firmware.bin" "$FW/Himax_firmware.bin" "vendor$s"
		add "$MNT/firmware/Himax_mpfw.bin" "$FW/Himax_mpfw.bin" "vendor$s"
		umount "$MNT"
	done
fi

for f in $MODEM_FILES $BT_FILES $VENDOR_FILES; do
	[ -s "$f" ] || log "not found on this tablet: $f"
done
[ -n "$ADDED" ] || exit 0

if [ $BOOT = 0 ]; then
	log "new firmware:$ADDED - reboot to use it"
	exit 0
fi

# at boot: the DSPs and Venus already gave up for lack of firmware, start them again
for r in /sys/class/remoteproc/remoteproc*; do
	[ "$(cat "$r/state" 2>/dev/null)" = offline ] && echo start > "$r/state" 2>/dev/null
done
V=/sys/bus/platform/drivers/qcom-venus
if [ -d "$V" ] && [ ! -e "$V/5a00000.video-codec" ]; then
	echo 5a00000.video-codec > "$V/bind" 2>/dev/null
fi
# the GPU firmware is taken from the initramfs, the touch firmware at probe: both need a new boot
case "$ADDED" in
*a610_zap*|*Himax*)
	mkinitfs >/dev/null 2>&1 && log "initramfs rebuilt with the GPU firmware - reboot to use the GPU and touch" ;;
esac
exit 0
