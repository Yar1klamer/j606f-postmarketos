# COMMANDS — проверенные рабочие команды

Пути от ./pmos-j606f. adb/fastboot: ~/platform-tools/. Python с fdt/zstandard/certifi: venv в scratchpad (`$VENV/bin/python`).

## Разведка и бэкап (Android, root Magisk)
```bash
bash scripts/phase0_adb.sh          # без root
bash scripts/phase0_root.sh         # под root → raw/root_YYYYMMDD/
bash scripts/backup_partitions.sh   # все разделы кроме userdata, sha256 устройство=Mac → BACKUP/partitions/
bash scripts/backup_partitions.sh boot_a dtbo_a   # выборочно
~/platform-tools/adb exec-out 'su -c "cat /sys/firmware/fdt"' > live.dtb
```

## Разбор образов
```bash
python3 -I scripts/bootimg_info.py IMG [--extract DIR]   # заголовок boot.img v0–v2
python3 -I scripts/dtbo_info.py BACKUP/partitions/dtbo_a.img --extract raw/dtbo_a
```

## Отладочный образ mainline (проверено 2026-10-29: грузится)
```bash
K=dl/linux-nura-qcom-sm61x5-7.2.3-r0/x
$VENV/bin/python -I scripts/dtb_add_abl_sink.py $K/boot/dtbs/qcom/sm6115p-lenovo-j606f.dtb raw/dtbo_a/labels_445.txt out/sm6115p-lenovo-j606f-ablsink.dtb
$VENV/bin/python -I scripts/make_debug_bootimg.py --header-version 2 --kernel $K/boot/vmlinuz \
  --dtb out/sm6115p-lenovo-j606f-ablsink.dtb --modules $K/usr/lib/modules/7.2.3-sm61x5 \
  --busybox dl/alpine/bb/bin/busybox.static --out out/debug-boot-7.2.3-r0-ablsink.img
```

## Загрузка без записи
```bash
~/platform-tools/adb reboot bootloader            # или, если уже в fastboot:
~/platform-tools/fastboot reboot bootloader       # ОБЯЗАТЕЛЬНО перед каждым fastboot boot
~/platform-tools/fastboot boot out/debug-boot-7.2.3-r0-ablsink.img
```

## Связь с отладочным initramfs
```bash
python3 -I scripts/acm_run.py /dev/cu.usbmodemj606f_debug3 'touch /tmp/keepalive; ip addr add 169.254.42.1/16 dev usb0; (nc -lk -p 9100 -e /bin/sh &)'
bash scripts/tcp_run.sh 'uname -a'                # shell через TCP
bash scripts/tcp_run.sh < scripts/debug-initramfs/collect.sh   # диагностика → /tmp/info.tar
bash scripts/tcp_run.sh '(nc -l -p 9101 < /tmp/info.tar &)'; nc -w 5 169.254.42.1 9101 > info.tar
$VENV/bin/python -I scripts/mirror_proxy.py 169.254.203.202 8080   # прокси Alpine/pmOS/Codeberg для планшета
```

## Возврат в Android
- Из отладочного shell: `reboot -f` (ABL грузит boot_a с Magisk).
- Из fastboot: `~/platform-tools/fastboot reboot`.

## Полный цикл тестовой загрузки (проверено 2026-10-29, тесты 6–8)
```bash
bash scripts/cycle_boot.sh out/debug-boot-hx83102p-test8-kbuild.img   # печатает MAC_IP=169.254.x.y
VENV=<scratchpad>
$VENV/bin/python -I scripts/mirror_proxy.py <MAC_IP> 8080 &              # прокси на текущий link-local адрес Mac
bash scripts/tcp_run.sh 'touch /tmp/keepalive /tmp/nc-contact'           # снять страховку 300 с
```

## Сборка модулей и DTB на самом планшете (≈10 мин, всё в RAM)
```bash
NOW=$(date -u "+%Y-%m-%d %H:%M:%S")
bash scripts/tcp_run.sh "wget -q -O /tmp/b.sh http://<MAC_IP>:8080/local/device_buildenv.sh && (MAC=<MAC_IP> NOW='$NOW' setsid sh /tmp/b.sh > /tmp/buildenv.log 2>&1 &)"
# результат: /mnt/root/build/out.tar (ko + dtb)
```

## Wi-Fi и BT в отладочной среде
```bash
bash scripts/tcp_run.sh "wget -q -O /tmp/w.sh http://<MAC_IP>:8080/local/device_wifi.sh && MAC=<MAC_IP> sh /tmp/w.sh"
bash scripts/tcp_run.sh "chroot /mnt/rt /usr/sbin/iw dev wlan0 scan | grep -c ^BSS"
bash scripts/tcp_run.sh "wget -q -O /tmp/bt.sh http://<MAC_IP>:8080/local/device_bt.sh && MAC=<MAC_IP> sh /tmp/bt.sh"
bash scripts/tcp_run.sh "chroot /mnt/rt btmgmt -i hci0 public-addr <BT_MAC>; chroot /mnt/rt btmgmt power on; chroot /mnt/rt btmgmt le on"
```

## Графика
```bash
# kmscube / modetest: обязательно открытый stdin, иначе modetest -v сразу выходит
bash scripts/tcp_run.sh 'chroot /mnt/rt sh -c "sleep 20 | timeout 15 kmscube -D /dev/dri/card1 -c 300"'
bash scripts/tcp_run.sh 'chroot /mnt/rt sh -c "sleep 12 | timeout 10 modetest -M msm -v -s 36@50:1200x2000"'
# weston (без seatd и без ввода)
bash scripts/tcp_run.sh 'R=/mnt/rt; mount -t tmpfs tmpfs $R/run; mkdir -p $R/tmp/xdg; chmod 700 $R/tmp/xdg; setsid chroot $R sh -c "export HOME=/root XDG_RUNTIME_DIR=/tmp/xdg LIBSEAT_BACKEND=noop; weston --backend=drm --renderer=gl --drm-device=card1 --continue-without-input --log=/tmp/weston.log" </dev/null >/dev/null 2>&1 &'
bash scripts/tcp_run.sh 'chroot /mnt/rt sh -c "export XDG_RUNTIME_DIR=/tmp/xdg WAYLAND_DISPLAY=wayland-1; timeout -s INT 12 weston-simple-egl -f"'
```

## SSH (dropbear в отладочной среде, только ключ)
```bash
ssh -i out/sshkey/j606f_test -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@169.254.42.1
```

## Чтение регистров MMIO (только чтение): python mmap /dev/mem в chroot (см. LOG: INTF1 0x05e6b800, MDP 0x05e01000)

## Read-only доступ к стоковым разделам из mainline
```bash
losetup -r -o 3958374400 /dev/loop0 /dev/sda14 && mount -t ext4 -o ro,noload /dev/loop0 /mnt/vendor   # vendor_a из super
mount -o ro /dev/sde9 /mnt/dsp                                                                            # dsp_a
```

## Новое ядро без записи (проверено 01–02.11, r120/r121)
```bash
tar -xzf linux-lenovo-j606f-7.2.3-rN.apk -C x boot/vmlinuz boot/dtbs/qcom/sm6115p-lenovo-j606f-hx83102p.dtb
python3 scripts/bootimg_replace_dtb.py boot-current.img x/boot/dtbs/qcom/sm6115p-lenovo-j606f-hx83102p.dtb boot-test.img x/boot/vmlinuz
ssh user@<планшет> 'sudo systemctl reboot --reboot-argument=bootloader'
~/platform-tools/fastboot boot boot-test.img
```

## Установка ядра на планшете (после проверки)
```bash
sudo head -c $(stat -c %s /boot/boot.img) /dev/disk/by-partlabel/boot_b > ~/boot_b-before-rN.img   # бэкап
cp /etc/apk/world /tmp/world.before
sudo apk add ./linux-lenovo-j606f-7.2.3-rN.apk          # boot-deploy пишет boot_b сам
sudo cp /tmp/world.before /etc/apk/world                  # apk вписывает в world пути с хешами
uname -v                                                  # после перезагрузки: #<pkgrel+1>
```

## Камеры
```bash
cam -l                                                    # 1: Internal back camera, 2: Internal front camera
cam -c 2 -s width=1632,height=1224 --capture=90           # fps
cam -c 2 --capture=150 --metadata | grep -E 'ExposureTime|AnalogueGain'   # работа AGC
# RAW фронта через CSID0 (CSID1 не трогать — вешает планшет)
media-ctl -r
media-ctl -l '"msm_csiphy2":1->"msm_csid0":0[1],"msm_csid0":1->"msm_vfe0_rdi0":0[1]'
media-ctl -V '"s5k4h7 3-0010":0[fmt:SGRBG10_1X10/3264x2448]'   # и так же msm_csiphy2:0, msm_csid0:0, msm_vfe0_rdi0:0
v4l2-ctl -d /dev/video0 --set-fmt-video=width=3264,height=2448,pixelformat=pgAA --stream-mmap --stream-count=6 --stream-to=/tmp/f.raw
```

## Диагностика
```bash
journalctl -b -1 -o short-monotonic --no-pager | tail -200   # прошлая загрузка (journald persistent), например после CrashDump
qrtr-lookup                                                  # сервисы DSP: без сервисов ADSP нет звука и датчиков
for r in /sys/class/remoteproc/remoteproc*; do echo $(cat $r/name) $(cat $r/state); done
```


## Образ для прошивки (хост, ~/j606f/release)
```bash
# worktree pmaports на нужном коммите, без личного пакета прошивок
git -C ~/j606f/pmaports worktree add --detach ~/j606f/release/pmaports <commit>; rm -r ~/j606f/release/pmaports/device/testing/firmware-lenovo-j606f
# workdir: version, config_abuild + config_apk_keys/pmos@local-*.pub (sudo cp -a), пакеты (chown 12345:12345), кеш apk
P="python3 ~/j606f/pmbootstrap/pmbootstrap.py -y -c ~/j606f/release/pmbootstrap.cfg"
$P chroot -- true && $P index          # после shutdown index сам native-chroot не монтирует
$P install --password 147147 --no-sshd && $P export
```
Зеркало рвёт большие пакеты → докачка с CDN в кеш: имя `<pkg>-<ver>.<первые 4 байта C: из APKINDEX в hex>.apk` (release/prefetch.sh).

## Бэкап userdata на Mac (только занятые блоки → Android sparse)
```bash
# только по USB (Wi-Fi ~6 МиБ/с — слишком долго держать / замороженной); ~13 МиБ/с, 11 ГБ за ~15 мин
scp scripts/raw2simg.py scripts/backup_userdata.sh user@172.16.42.1:/tmp/
ssh -o ServerAliveInterval=15 -T user@172.16.42.1 'sudo -n sh /tmp/backup_userdata.sh /tmp/raw2simg.py' 2>tablet.log \
  | python3 -B scripts/raw2simg.py unpack 110004875264 BACKUP/userdata-backup-<дата>.simg 2>mac.log   # sha256 в обоих логах должны совпасть
fastboot flash userdata BACKUP/userdata-backup-<дата>.simg   # восстановление (~5 мин)
```
backup_userdata.sh: GPT и pmOS_boot целиком (dd), корень — `e2image -ra` через `losetup -r` (иначе libext2fs создаёт `/.ismount-test-file`
на замороженной / и висит вечно), под `fsfreeze` / и /boot, журнал на время копии в /run (`journalctl --relinquish-var`), сон заблокирован
(`systemd-inhibit`). Экран во время копии чёрный (Plasma ждёт записи) — это нормально.

## Проверка релизного образа на нашем планшете (03.11)
```bash
systemctl reboot --reboot-argument=bootloader          # «systemctl reboot bootloader» → Too many arguments
fastboot flash super BACKUP/partitions/super.img       # стоковый super (sha256 cf8ffbd0…), 15 частей, ~6 мин
echo YES | ./flash-all.sh                              # из распакованного архива
# в образе sshd выключен и sudo с паролем: на планшете sudo systemctl start sshd, затем владелец сам добавляет ключ Mac (вводит пароль).
```
