#!/bin/sh
# Запуск pmbootstrap внутри chroot на планшете: sh pmb.sh <аргументы pmbootstrap>
# Лог: /mnt/work/pmb_last.log (+ /mnt/work/alpine/work/pmb/log.txt)
A=/mnt/work/alpine
chroot $A /bin/sh -c "cd /work && HOME=/root python3 /work/pmbootstrap/pmbootstrap.py --as-root -y $*" > /mnt/work/pmb_last.log 2>&1
echo "PMB_EXIT=$?" >> /mnt/work/pmb_last.log
