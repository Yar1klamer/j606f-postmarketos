#!/bin/sh
# Bluetooth bring-up в отладочном initramfs (после device_wifi.sh: нужен /mnt и /mnt/rt).
# Использование: MAC=169.254.x.y sh device_bt.sh
set -x
P=http://$MAC:8080
cd /mnt
for t in btmods fwbt; do [ -d /mnt/$t.done ] || { wget -q -O $t.tar $P/local/$t.tar && mkdir -p x-$t && tar xf $t.tar -C x-$t && mkdir $t.done; }; done
mkdir -p /lib/firmware && cp -a x-fwbt/qca /lib/firmware/
/mnt/dl/sbin/apk.static --root /mnt/rt --arch aarch64 --allow-untrusted --no-progress \
  -X $P/alpine/edge/main -X $P/alpine/edge/community add bluez-btmgmt bluez 2>&1 | tail -1
for m in $(cat /mnt/x-btmods/btmods/order); do
  grep -q "^$m " /proc/modules || insmod /mnt/x-btmods/btmods/$m.ko 2>>/tmp/bt_insmod.log; done
sleep 5
dmesg | grep -iE "bluetooth|hci|qca|btqca|serdev|uart" | tail -30 > /tmp/bt_dmesg.txt
ls /sys/class/bluetooth > /tmp/bt_hci.txt 2>&1
echo BT_SETUP_DONE
