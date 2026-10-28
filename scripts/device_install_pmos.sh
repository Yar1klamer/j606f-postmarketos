#!/bin/sh
# Установка собранного pmbootstrap'ом pmOS с самого планшета (под отладочным mainline):
#   rootfs-образ (pmOS_boot + pmOS_root) → super (/dev/sda14), boot.img → boot_b (/dev/sde31).
# Разрешено пользователем 29.10 («андроид можешь сносить», «слот любой»). Слот a не трогаем.
set -e
W=/mnt/work/alpine/work/pmb
IMG=$W/chroot_native/home/pmos/rootfs/lenovo-j606f.img
BOOT=$W/chroot_rootfs_lenovo-j606f/boot/boot.img
check() { [ "$(grep PARTNAME /sys/class/block/$1/uevent | cut -d= -f2)" = "$2" ] || { echo "ABORT: $1 is not $2"; exit 1; }; }
check sda14 super
check sde31 boot_b
for f in "$IMG" "$BOOT"; do [ -s "$f" ] || { echo "ABORT: missing $f"; exit 1; }; done
img_sz=$(stat -c %s "$IMG"); super_sz=$(( $(cat /sys/class/block/sda14/size) * 512 ))
boot_sz=$(stat -c %s "$BOOT"); bootb_sz=$(( $(cat /sys/class/block/sde31/size) * 512 ))
echo "rootfs $img_sz <= super $super_sz ; boot $boot_sz <= boot_b $bootb_sz"
[ "$img_sz" -le "$super_sz" ] && [ "$boot_sz" -le "$bootb_sz" ] || { echo "ABORT: too big"; exit 1; }
grep -q "sda14\|sde31" /proc/mounts && { echo "ABORT: target mounted"; exit 1; }
dd if="$IMG" of=/dev/sda14 bs=4M conv=fsync 2>&1 | tail -1
dd if="$BOOT" of=/dev/sde31 bs=4M conv=fsync 2>&1 | tail -1
sync; echo 3 > /proc/sys/vm/drop_caches
a=$(sha256sum < "$IMG" | cut -c1-64); b=$(head -c "$img_sz" /dev/sda14 | sha256sum | cut -c1-64)
c=$(sha256sum < "$BOOT" | cut -c1-64); d=$(head -c "$boot_sz" /dev/sde31 | sha256sum | cut -c1-64)
echo "rootfs img=$a super=$b"; echo "boot img=$c boot_b=$d"
[ "$a" = "$b" ] && [ "$c" = "$d" ] && echo INSTALL_OK || echo INSTALL_VERIFY_FAILED
