#!/bin/sh
# Постоянное окружение для pmbootstrap на userdata (/mnt/work, ext4): Alpine edge chroot /mnt/work/alpine.
# Использование: MAC=169.254.x.y NOW="..." sh device_pmb_env.sh
set -x
P=http://$MAC:8080
[ -n "$NOW" ] && date -u -s "$NOW" >/dev/null
mountpoint -q /mnt/work || { mkdir -p /mnt/work; mount -t ext4 /dev/sda15 /mnt/work; }
A=/mnt/work/alpine
mkdir -p /mnt/work/dl && cd /mnt/work/dl
[ -x sbin/apk.static ] || { wget -q $P/alpine/edge/main/aarch64/apk-tools-static-3.0.8-r0.apk; tar xzf apk-tools-static-3.0.8-r0.apk 2>/dev/null; }
[ -x $A/usr/bin/python3 ] || /mnt/work/dl/sbin/apk.static --root $A --initdb --arch aarch64 --allow-untrusted --no-progress \
  -X $P/alpine/edge/main -X $P/alpine/edge/community -U add alpine-base python3 git openssl tar xz zstd util-linux losetup \
  e2fsprogs dosfstools coreutils findutils grep sed bash procps kmod multipath-tools
for m in proc sys dev dev/pts run; do mountpoint -q $A/$m || { mkdir -p $A/$m; mount --bind /$m $A/$m 2>/dev/null || mount -t tmpfs tmpfs $A/$m; }; done
cp /etc/resolv.conf $A/etc/ 2>/dev/null
mkdir -p $A/work
cd $A/work
[ -d pmbootstrap ] || { wget -q -O - $P/local/pmbootstrap-src.tar | tar x; }
[ -d pmaports-main ] || { wget -q -O - $P/local/pmaports-j606f.tar | tar x; }
mkdir -p $A/work/pmb/cache_distfiles
[ -f $A/work/pmb/cache_distfiles/linux-nura-qcom-sm61x5-v7.2.3-r0.tar.gz ] || wget -q -O $A/work/pmb/cache_distfiles/linux-nura-qcom-sm61x5-v7.2.3-r0.tar.gz $P/local/linux-nura-qcom-sm61x5-v7.2.3-r0.tar.gz
mkdir -p $A/root/.config
cat > $A/root/.config/pmbootstrap_v3.cfg <<CFG
[pmbootstrap]
aports = /work/pmaports-main
work = /work/pmb
device = lenovo-j606f
ui = console
user = user
jobs = 8
build_pkgs_on_install = True
is_default_channel = False
timezone = Europe/Moscow
hostname = tab-p11

[mirrors]
alpine = $P/alpine/
pmaports = $P/pmos/
systemd = $P/pmos/extra-repos/systemd/
CFG
echo PMB_ENV_DONE
