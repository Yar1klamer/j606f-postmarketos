#!/bin/sh
# Weston (DRM + GL) в отладочной среде (после device_wifi.sh: нужны /mnt/dl и /mnt/rt).
# Использование: MAC=169.254.x.y NOW="YYYY-MM-DD HH:MM:SS" sh device_weston.sh
P=http://$MAC:8080
[ -n "$NOW" ] && date -u -s "$NOW" >/dev/null
R=/mnt/rt
/mnt/dl/sbin/apk.static --root $R --arch aarch64 --allow-untrusted --no-progress -X $P/alpine/edge/main -X $P/alpine/edge/community \
  add weston weston-backend-drm weston-clients weston-shell-desktop mesa-dri-gallium mesa-egl mesa-gbm mesa-gles font-dejavu kmscube libdrm-tests 2>&1 | tail -1
mountpoint -q $R/run || mount -t tmpfs tmpfs $R/run
mkdir -p $R/tmp/xdg $R/root/.config; chmod 700 $R/tmp/xdg
printf "[core]\nidle-time=0\n\n[shell]\nbackground-color=0xff0050a0\npanel-position=top\nclock-format=seconds\nlocking=false\n" > $R/root/.config/weston.ini
echo 0 > /sys/class/vtconsole/vtcon1/bind 2>/dev/null
setsid chroot $R /bin/sh -c "export HOME=/root XDG_RUNTIME_DIR=/tmp/xdg LIBSEAT_BACKEND=noop; weston --debug --backend=drm --renderer=gl --drm-device=card1 --continue-without-input --log=/tmp/weston.log" </dev/null >/dev/null 2>&1 &
sleep 6
echo 1200 > /sys/class/backlight/5e94000.dsi.0/brightness
echo "WESTON_DONE pid=$(pidof weston)"
