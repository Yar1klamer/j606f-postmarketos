#!/bin/sh
# Back up the whole userdata partition (GPT + pmOS_boot + pmOS_root) to stdout as raw2simg "pack" records:
# everything before and after the root filesystem as it is, the root filesystem as e2image -ra (unused blocks
# read as zero, so they are not sent). / and /boot are frozen for the time of the copy and always thawed.
# Run as root:  sudo sh backup_userdata.sh /path/to/raw2simg.py | (on the host) raw2simg.py unpack SIZE out.simg
# The size of userdata goes to stderr first.
set -eu
PACK=$1
# a suspend with / frozen hangs the tablet (the sync before sleep waits for the thaw): block sleep for the whole copy
if [ -z "${J606F_BACKUP_INHIBITED:-}" ]; then
	J606F_BACKUP_INHIBITED=1 exec systemd-inhibit --what=sleep:idle:handle-lid-switch:handle-suspend-key \
		--who=backup_userdata --why="userdata backup" --mode=block sh "$0" "$@"
fi
UD=$(readlink -f /dev/disk/by-partlabel/userdata)
ROOT=$(findmnt -no SOURCE /)
case "$ROOT" in /dev/loop*p2) ;; *) echo "unexpected root device $ROOT" >&2; exit 1 ;; esac
LOOP=${ROOT%p2}
LOOPN=$(basename "$LOOP")
[ "$(cat /sys/block/$LOOPN/loop/backing_file)" = "$UD" ] || { echo "$LOOP is not on $UD" >&2; exit 1; }
SIZE=$(blockdev --getsize64 "$UD")
# partition start and size in sysfs are in 512-byte units
START=$(( $(cat /sys/block/$LOOPN/${LOOPN}p2/start) * 512 ))
LEN=$(( $(cat /sys/block/$LOOPN/${LOOPN}p2/size) * 512 ))
END=$((START + LEN))
[ $((START % 4096)) = 0 ] && [ $((END % 4096)) = 0 ] || { echo "root partition not 4K aligned" >&2; exit 1; }
echo "userdata $UD size $SIZE, root $ROOT bytes $START..$END" >&2

# libext2fs sees that $ROOT is mounted on / and creates /.ismount-test-file to check that, which waits forever
# on the frozen /. A read-only loop over the same partition is not in the mount table, so e2image reads that.
RO=$(losetup -r -f --show "$ROOT")
echo "e2image reads $RO" >&2

thaw() {
	fsfreeze -u / 2>/dev/null || true
	fsfreeze -u /boot 2>/dev/null || true
	journalctl --flush 2>/dev/null || true
	losetup -d "$RO" 2>/dev/null || true
}
trap thaw EXIT INT TERM HUP PIPE

# journald blocked on a frozen / gets killed by its watchdog after 3 min: keep the journal in /run meanwhile.
# Everything else that writes to / waits, so keep the copy short (over USB, not Wi-Fi).
journalctl --relinquish-var 2>/dev/null || true
sync
fsfreeze -f /boot
fsfreeze -f /
{
	dd if="$UD" bs=4096 count=$((START / 4096)) status=none
	e2image -ra "$RO" -
	dd if="$UD" bs=4096 skip=$((END / 4096)) status=none
} | python3 -B "$PACK" pack
thaw
echo "backup stream done" >&2
