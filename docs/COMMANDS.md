# COMMANDS — tested working commands

Paths are relative to ./pmos-j606f. adb/fastboot: ~/platform-tools/. Python with fdt/zstandard/certifi: a venv in the scratchpad (`$VENV/bin/python`).

## Exploration and backup (Android, Magisk root)
```bash
bash scripts/phase0_adb.sh          # without root
bash scripts/phase0_root.sh         # as root → raw/root_YYYYMMDD/
bash scripts/backup_partitions.sh   # all partitions except userdata, sha256 device=Mac → BACKUP/partitions/
bash scripts/backup_partitions.sh boot_a dtbo_a   # selected ones
~/platform-tools/adb exec-out 'su -c "cat /sys/firmware/fdt"' > live.dtb
```

## Image inspection
```bash
python3 -I scripts/bootimg_info.py IMG [--extract DIR]   # boot.img header v0–v2
python3 -I scripts/dtbo_info.py BACKUP/partitions/dtbo_a.img --extract raw/dtbo_a
```

## Mainline debug image (tested 2026-10-29: boots)
```bash
K=dl/linux-nura-qcom-sm61x5-7.2.3-r0/x
$VENV/bin/python -I scripts/dtb_add_abl_sink.py $K/boot/dtbs/qcom/sm6115p-lenovo-j606f.dtb raw/dtbo_a/labels_445.txt out/sm6115p-lenovo-j606f-ablsink.dtb
$VENV/bin/python -I scripts/make_debug_bootimg.py --header-version 2 --kernel $K/boot/vmlinuz \
  --dtb out/sm6115p-lenovo-j606f-ablsink.dtb --modules $K/usr/lib/modules/7.2.3-sm61x5 \
  --busybox dl/alpine/bb/bin/busybox.static --out out/debug-boot-7.2.3-r0-ablsink.img
```

## Booting without writing
```bash
~/platform-tools/adb reboot bootloader            # or, if already in fastboot:
~/platform-tools/fastboot reboot bootloader       # REQUIRED before every fastboot boot
~/platform-tools/fastboot boot out/debug-boot-7.2.3-r0-ablsink.img
```

## Talking to the debug initramfs
```bash
python3 -I scripts/acm_run.py /dev/cu.usbmodemj606f_debug3 'touch /tmp/keepalive; ip addr add 169.254.42.1/16 dev usb0; (nc -lk -p 9100 -e /bin/sh &)'
bash scripts/tcp_run.sh 'uname -a'                # shell over TCP
bash scripts/tcp_run.sh < scripts/debug-initramfs/collect.sh   # diagnostics → /tmp/info.tar
bash scripts/tcp_run.sh '(nc -l -p 9101 < /tmp/info.tar &)'; nc -w 5 169.254.42.1 9101 > info.tar
$VENV/bin/python -I scripts/mirror_proxy.py 169.254.203.202 8080   # Alpine/pmOS/Codeberg proxy for the tablet
```

## Back to Android
- From the debug shell: `reboot -f` (ABL boots boot_a with Magisk).
- From fastboot: `~/platform-tools/fastboot reboot`.

## Full test boot cycle (tested 2026-10-29, tests 6–8)
```bash
bash scripts/cycle_boot.sh out/debug-boot-hx83102p-test8-kbuild.img   # prints MAC_IP=169.254.x.y
VENV=<scratchpad>
$VENV/bin/python -I scripts/mirror_proxy.py <MAC_IP> 8080 &              # proxy on the Mac's current link-local address
bash scripts/tcp_run.sh 'touch /tmp/keepalive /tmp/nc-contact'           # disarm the 300 s safety reboot
```

## Building modules and the DTB on the tablet itself (≈10 min, all in RAM)
```bash
NOW=$(date -u "+%Y-%m-%d %H:%M:%S")
bash scripts/tcp_run.sh "wget -q -O /tmp/b.sh http://<MAC_IP>:8080/local/device_buildenv.sh && (MAC=<MAC_IP> NOW='$NOW' setsid sh /tmp/b.sh > /tmp/buildenv.log 2>&1 &)"
# result: /mnt/root/build/out.tar (ko + dtb)
```

## Wi-Fi and BT in the debug environment
```bash
bash scripts/tcp_run.sh "wget -q -O /tmp/w.sh http://<MAC_IP>:8080/local/device_wifi.sh && MAC=<MAC_IP> sh /tmp/w.sh"
bash scripts/tcp_run.sh "chroot /mnt/rt /usr/sbin/iw dev wlan0 scan | grep -c ^BSS"
bash scripts/tcp_run.sh "wget -q -O /tmp/bt.sh http://<MAC_IP>:8080/local/device_bt.sh && MAC=<MAC_IP> sh /tmp/bt.sh"
bash scripts/tcp_run.sh "chroot /mnt/rt btmgmt -i hci0 public-addr <BT_MAC>; chroot /mnt/rt btmgmt power on; chroot /mnt/rt btmgmt le on"
```

## Graphics
```bash
# kmscube / modetest: stdin must stay open, otherwise modetest -v exits at once
bash scripts/tcp_run.sh 'chroot /mnt/rt sh -c "sleep 20 | timeout 15 kmscube -D /dev/dri/card1 -c 300"'
bash scripts/tcp_run.sh 'chroot /mnt/rt sh -c "sleep 12 | timeout 10 modetest -M msm -v -s 36@50:1200x2000"'
# weston (without seatd and without input)
bash scripts/tcp_run.sh 'R=/mnt/rt; mount -t tmpfs tmpfs $R/run; mkdir -p $R/tmp/xdg; chmod 700 $R/tmp/xdg; setsid chroot $R sh -c "export HOME=/root XDG_RUNTIME_DIR=/tmp/xdg LIBSEAT_BACKEND=noop; weston --backend=drm --renderer=gl --drm-device=card1 --continue-without-input --log=/tmp/weston.log" </dev/null >/dev/null 2>&1 &'
bash scripts/tcp_run.sh 'chroot /mnt/rt sh -c "export XDG_RUNTIME_DIR=/tmp/xdg WAYLAND_DISPLAY=wayland-1; timeout -s INT 12 weston-simple-egl -f"'
```

## SSH (dropbear in the debug environment, key only)
```bash
ssh -i out/sshkey/j606f_test -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@169.254.42.1
```

## Reading MMIO registers (read only): python mmap of /dev/mem in the chroot (see LOG: INTF1 0x05e6b800, MDP 0x05e01000)

## Read-only access to the stock partitions from mainline
```bash
losetup -r -o 3958374400 /dev/loop0 /dev/sda14 && mount -t ext4 -o ro,noload /dev/loop0 /mnt/vendor   # vendor_a from super
mount -o ro /dev/sde9 /mnt/dsp                                                                            # dsp_a
```

## A new kernel without writing (tested 01–02.11, r120/r121)
```bash
tar -xzf linux-lenovo-j606f-7.2.3-rN.apk -C x boot/vmlinuz boot/dtbs/qcom/sm6115p-lenovo-j606f-hx83102p.dtb
python3 scripts/bootimg_replace_dtb.py boot-current.img x/boot/dtbs/qcom/sm6115p-lenovo-j606f-hx83102p.dtb boot-test.img x/boot/vmlinuz
ssh user@<tablet> 'sudo systemctl reboot --reboot-argument=bootloader'
~/platform-tools/fastboot boot boot-test.img
```

## Installing a kernel on the tablet (after the test)
```bash
sudo head -c $(stat -c %s /boot/boot.img) /dev/disk/by-partlabel/boot_b > ~/boot_b-before-rN.img   # backup
cp /etc/apk/world /tmp/world.before
sudo apk add ./linux-lenovo-j606f-7.2.3-rN.apk          # boot-deploy writes boot_b itself
sudo cp /tmp/world.before /etc/apk/world                  # apk puts paths with hashes into world
uname -v                                                  # after the reboot: #<pkgrel+1>
```

## Cameras
```bash
cam -l                                                    # 1: Internal back camera, 2: Internal front camera
cam -c 2 -s width=1632,height=1224 --capture=90           # fps
cam -c 2 --capture=150 --metadata | grep -E 'ExposureTime|AnalogueGain'   # how the AGC behaves
# RAW of the front camera through CSID0 (do not touch CSID1 — it hangs the tablet)
media-ctl -r
media-ctl -l '"msm_csiphy2":1->"msm_csid0":0[1],"msm_csid0":1->"msm_vfe0_rdi0":0[1]'
media-ctl -V '"s5k4h7 3-0010":0[fmt:SGRBG10_1X10/3264x2448]'   # and the same for msm_csiphy2:0, msm_csid0:0, msm_vfe0_rdi0:0
v4l2-ctl -d /dev/video0 --set-fmt-video=width=3264,height=2448,pixelformat=pgAA --stream-mmap --stream-count=6 --stream-to=/tmp/f.raw
```

## Diagnostics
```bash
journalctl -b -1 -o short-monotonic --no-pager | tail -200   # the previous boot (journald is persistent), e.g. after a CrashDump
qrtr-lookup                                                  # DSP services: without ADSP services there is no sound and no sensors
for r in /sys/class/remoteproc/remoteproc*; do echo $(cat $r/name) $(cat $r/state); done
```

