#!/bin/sh
# Ставит пакет ядра на планшете без записи boot-раздела (07.11): boot-deploy пишет в boot+androidboot.slot_suffix
# (при _a — boot_a с UEFI), а mkbootimg (Python) на планшете падает. После — собрать boot.img на Mac (scripts/mkbootimg_v2.py).
# Запуск на планшете: sudo sh kernel_apk_add_noflash.sh /home/user/linux-lenovo-j606f-<ver>.apk
set -u
[ $# -ge 1 ] || { echo "usage: $0 PKG.apk"; exit 2; }
printf 'deviceinfo_flash_kernel_on_update="false"\ndeviceinfo_generate_bootimg="false"\n' > /etc/deviceinfo
apk add --allow-untrusted "$@" 2>&1 | tail -5
rm -f /etc/deviceinfo
apk info -v | grep '^linux-lenovo'
ls -l /boot/initramfs /boot/vmlinuz
