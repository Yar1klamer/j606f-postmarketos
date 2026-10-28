#!/bin/sh
# Wi-Fi bring-up в отладочном initramfs mainline (всё в RAM).
# rmtfs работает с КОПИЯМИ modemst1/modemst2/fsg/fsc из BACKUP (-o /mnt/rmtfs), реальные разделы не трогаются.
# Использование: MAC=169.254.x.y sh device_wifi.sh
set -x
P=http://$MAC:8080
mkdir -p /mnt; mountpoint -q /mnt || mount -t tmpfs -o size=4500m tmpfs /mnt
cd /mnt
for t in wifimods rmtfs fwwifi; do [ -d /mnt/$t.done ] || { wget -q -O $t.tar $P/local/$t.tar && mkdir -p x-$t && tar xf $t.tar -C x-$t && mkdir $t.done; }; done
mkdir -p /lib/firmware && cp -a x-fwwifi/qcom /lib/firmware/
# Alpine userland: rmtfs, tqftpserv, iw, linux-firmware-ath10k, wireless-regdb
mkdir -p /mnt/dl; cd /mnt/dl
[ -x sbin/apk.static ] || { wget -q $P/alpine/edge/main/aarch64/apk-tools-static-3.0.8-r0.apk; tar xzf apk-tools-static-3.0.8-r0.apk 2>/dev/null; }
R=/mnt/rt
[ -x $R/usr/bin/rmtfs ] || /mnt/dl/sbin/apk.static --root $R --initdb --arch aarch64 --allow-untrusted --no-progress \
  -X $P/alpine/edge/main -X $P/alpine/edge/community -U add busybox musl rmtfs tqftpserv qrtr iw wireless-regdb linux-firmware-ath10k
cp -a $R/lib/firmware/ath10k /lib/firmware/
cp -a $R/lib/firmware/regulatory.db* /lib/firmware/ 2>/dev/null
for m in proc sys dev; do mountpoint -q $R/$m || { mkdir -p $R/$m; mount --bind /$m $R/$m; }; done
mkdir -p $R/lib/firmware/qcom && mount --bind /lib/firmware $R/lib/firmware
# модули: два прохода (у пересобранного qcom_pd_mapper пустой depends=)
for pass in 1 2; do for m in $(cat /mnt/x-wifimods/wifimods/order); do
  grep -q "^$m " /proc/modules || insmod /mnt/x-wifimods/wifimods/$m.ko 2>>/tmp/wifi_insmod.log; done; done
lsmod > /tmp/wifi_lsmod.txt
mkdir -p $R/var/rmtfs && cp /mnt/x-rmtfs/rmtfs/* $R/var/rmtfs/
ls -l /dev/qcom_rmtfs* > /tmp/wifi_rmtfsdev.txt 2>&1
setsid chroot $R /usr/bin/rmtfs -v -o /var/rmtfs > /tmp/rmtfs.log 2>&1 &
mkdir -p $R/var/lib/tqftpserv
setsid chroot $R /usr/bin/tqftpserv > /tmp/tqftpserv.log 2>&1 &
sleep 2
for r in /sys/class/remoteproc/remoteproc*; do [ "$(cat $r/name)" = modem ] && [ "$(cat $r/state)" = offline ] && echo start > $r/state; done
sleep 15
ip link set wlan0 up 2>/dev/null
for r in /sys/class/remoteproc/remoteproc*; do echo "$r $(cat $r/name) $(cat $r/state) $(cat $r/firmware)"; done > /tmp/wifi_rproc.txt
echo WIFI_SETUP_DONE
