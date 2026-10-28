#!/bin/sh
# Запускается на планшете в отладочном initramfs mainline (busybox sh), полностью в RAM (tmpfs).
# 1) часы, tmpfs, Alpine edge (clang/lld 23, dtc, pahole) через прокси на Mac;
# 2) исходники linux 7.2.3-r0, config пакета + нужные модули, modules_prepare;
# 3) сборка внешних модулей (/build/ext) и DTB → /mnt/root/build/out.tar
# Использование: MAC=169.254.x.y NOW="YYYY-MM-DD HH:MM:SS" sh device_buildenv.sh
set -e
P=http://$MAC:8080
[ -n "$NOW" ] && date -u -s "$NOW" >/dev/null
mkdir -p /mnt; mountpoint -q /mnt || mount -t tmpfs -o size=4500m tmpfs /mnt
mkdir -p /mnt/dl /mnt/root/build
cd /mnt/dl
[ -x sbin/apk.static ] || { wget -q $P/alpine/edge/main/aarch64/apk-tools-static-3.0.8-r0.apk; tar xzf apk-tools-static-3.0.8-r0.apk 2>/dev/null; }
R=/mnt/root
if [ ! -x $R/usr/bin/clang ]; then
  /mnt/dl/sbin/apk.static --root $R --initdb --arch aarch64 --allow-untrusted --no-progress \
    -X $P/alpine/edge/main -X $P/alpine/edge/community -U add alpine-baselayout busybox musl musl-dev libc-dev gcc \
    apk-tools make clang lld llvm bison flex bc perl python3 openssl-dev elfutils-dev linux-headers findutils \
    diffutils dtc patch xz zstd tar gzip coreutils grep sed gawk bash kmod pahole
fi
for m in proc sys dev; do mountpoint -q $R/$m || { mkdir -p $R/$m; mount --bind /$m $R/$m; }; done
wget -q -O $R/build/inner.sh $P/local/device_build_inner.sh
chroot $R /bin/bash /build/inner.sh "$P"
