#!/bin/sh
# Lenovo Tab P11 (TB-J606F): take the Lenovo firmware from this tablet's own stock partitions.
# Nothing is ever written to the partitions; only files that are still missing are added:
#   modem_a/b (vfat, NON-HLOS)  image/{adsp,cdsp,modem,venus}.mdt+.bNN -> .mbn, image/wlanmdsp.mbn
#   bluetooth_a/b (vfat)        image/crbtfw21.tlv, image/crnv21.bin
#     -> /lib/firmware/updates, which the kernel and tqftpserv search before /lib/firmware: the DSP images
#        have to match this tablet's stock (the sensors crash with an ADSP from another Android version),
#        so they win over the shared S320208 set of the repository's firmware-lenovo-j606f 0.320208.
#        A firmware-lenovo-j606f built from this tablet's own backup (pkgver 1) is used as it is.
#        An apk trigger runs this again whenever a package changes the firmware directory.
#   super -> vendor_a/b (ext4)  firmware/a610_zap.mdt+.bNN -> .mbn (GPU), firmware/Himax_*.bin (touch),
#                               firmware/awinic/aw882xx_acf.bin (speaker amplifier settings)
#     -> /lib/firmware, only if no package has them (the GPU firmware also goes into the initramfs,
#        and these files work with any stock version).
# vendor lives in super, which a pmOS install into userdata leaves alone; if super was overwritten,
# the GPU and touch firmware come from the firmware package (the speakers need its awinic file too).
#   firmware-extract          add what is missing (apk post-install/post-upgrade; reboot afterwards)
#   firmware-extract --boot   the same at boot, then start the DSPs and Venus that missed their firmware
# For testing: J606F_FIRMWARE_ROOT=<dir> writes there instead of /lib/firmware.
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
FW=${J606F_FIRMWARE_ROOT:-/lib/firmware}
UPD=$FW/updates
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

# the DSP images in /lib/firmware are this tablet's own (firmware-lenovo-j606f built from its backup),
# unless the repository's shared set put its marker there; then this tablet's own go to updates
BASE=$FW
if [ -e /usr/share/j606f/firmware-shared ] || [ ! -s "$QC/adsp.mbn" ] || [ -n "${J606F_FIRMWARE_ROOT:-}" ]; then
	BASE=$UPD
fi
OWN=$BASE/qcom/sm6115/LENOVO/J606F

# back on firmware from this tablet's own backup: drop the copies made in front of a shared set,
# they would hide that package's later updates
if [ "$BASE" = "$FW" ] && grep -q "^$UPD/" "$LIST" 2>/dev/null; then
	: > "$LIST.new"
	while read -r f; do
		case "$f" in
		"$UPD"/*) rm -f "$f" && log "removed $f (firmware-lenovo-j606f has this tablet's own)" ;;
		*) echo "$f" >> "$LIST.new" ;;
		esac
	done < "$LIST"
	mv "$LIST.new" "$LIST"
fi

MODEM_FILES="$OWN/adsp.mbn $OWN/cdsp.mbn $OWN/modem.mbn $OWN/venus.mbn $OWN/wlanmdsp.mbn"
BT_FILES="$BASE/qca/crbtfw21.tlv $BASE/qca/crnv21.bin"
ACF=$FW/awinic/aw882xx_acf.bin
VENDOR_FILES="$QC/a610_zap.mbn $FW/Himax_firmware.bin $FW/Himax_mpfw.bin $ACF"
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
		squash "$MNT/image" "$n" "$OWN/$n.mbn" "modem$s"
	done
	add "$MNT/image/wlanmdsp.mbn" "$OWN/wlanmdsp.mbn" "modem$s"
	umount "$MNT"
done

for s in _a _b; do
	missing $BT_FILES || break
	dev=$(part "bluetooth$s") || continue
	mount_ro "$dev" vfat || continue
	add "$MNT/image/crbtfw21.tlv" "$BASE/qca/crbtfw21.tlv" "bluetooth$s"
	add "$MNT/image/crnv21.bin" "$BASE/qca/crnv21.bin" "bluetooth$s"
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
		# the old Awinic container (first bytes 08 f9 15 0a) is the only format the driver reads
		[ "$(od -An -tx1 -N4 "$MNT/firmware/awinic/aw882xx_acf.bin" 2>/dev/null | tr -d ' \n')" = "08f9150a" ] &&
			add "$MNT/firmware/awinic/aw882xx_acf.bin" "$ACF" "vendor$s"
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

# at boot: the DSPs and Venus already gave up for lack of firmware, start them again; the ones that
# came up with the firmware package's images switch to this tablet's own after the next boot
RUNNING=0
for r in /sys/class/remoteproc/remoteproc*; do
	case "$(cat "$r/state" 2>/dev/null)" in
	offline) echo start > "$r/state" 2>/dev/null ;;
	running) RUNNING=1 ;;
	esac
done
case "$ADDED" in
*adsp* | *cdsp* | *modem* | *wlanmdsp*)
	[ $RUNNING = 0 ] || log "running DSPs use the new firmware after the next reboot" ;;
esac
V=/sys/bus/platform/drivers/qcom-venus
if [ -d "$V" ] && [ ! -e "$V/5a00000.video-codec" ]; then
	echo 5a00000.video-codec > "$V/bind" 2>/dev/null
fi
# the speaker amplifiers read their settings when the sound card comes up, which waits for the file:
# binding one amplifier again makes the kernel retry the card
case "$ADDED" in
*aw882xx_acf*)
	if ! grep -q "Lenovo-TB-J606F" /proc/asound/cards 2>/dev/null; then
		for d in /sys/bus/i2c/drivers/aw88258/*-00*; do
			[ -e "$d" ] || continue
			n=$(basename "$d")
			echo "$n" > /sys/bus/i2c/drivers/aw88258/unbind 2>/dev/null
			echo "$n" > /sys/bus/i2c/drivers/aw88258/bind 2>/dev/null
			break
		done
		log "speaker settings in place, sound card tried again"
	fi ;;
esac
# the GPU firmware is taken from the initramfs, the touch firmware at probe: both need a new boot
case "$ADDED" in
*a610_zap*|*Himax*)
	mkinitfs >/dev/null 2>&1 && log "initramfs rebuilt with the GPU firmware - reboot to use the GPU and touch" ;;
esac
exit 0
