# STATE — where we stopped (2026-11-04)

> The current state of the port. Device: [DEVICE.md](DEVICE.md). Decisions: [docs/DECISIONS.md](docs/DECISIONS.md).
> Detailed per-subsystem notes: `docs/notes/*.md`.

## 1. In one line
**pmOS (Nura edge) with KDE Plasma Desktop is installed to internal storage and boots on its own** on the Lenovo Tab P11 TB-J606F (Himax HX83102P revision):
**rootfs in `userdata` (~100 GiB)**, boot.img in `boot_b`, **dtbo_b erased**, active slot **b**. Kernel — linux-lenovo-j606f (linux-nura-qcom-sm61x5 7.2.3 with patches 0001, 0003–0024)
(**pkgrel 121** in pmaports; without HACK 0002). Working: Plasma, Wi-Fi, Bluetooth, battery, sensors, **touch**, **USB OTG**, charging from a USB-C wall charger (FUSB302),
GPU with a DDR bandwidth vote (patch 0009, ×2.5–7), **hardware H.264/HEVC decoding through Venus** (patch 0011, firmware r2), **speakers** (4× AW88258, stereo, 0012–0016) and the **rear camera** (OV13B10 + DW9763 focus, CAMSS 0017–0022) and the **front camera** (own S5K4H7 driver, 0023–0024); libcamera r6.
Missing: microphones, headset (USB-C), a stable suspend (CrashDump after a resume) and the final offline-charging test. Packages are served from **https://repo.yarnick.ru/j606f** (README).
**A ready archive to flash** (no Lenovo blobs, one script) — [Releases](https://github.com/Yar1klamer/j606f-postmarketos/releases), tested 03.11.
A second tablet (a tester's, also HX83102P, Android 11 in stock) runs an image with its own firmware.

## 2. Device state right now
| What | Value |
|---|---|
| Running | pmOS + Plasma Desktop (autologin user), normal boot from slot b |
| Active slot | **b** (`slot-successful:b` = yes) |
| boot_a | stock boot + Magisk; the stock original is in the private backup |
| boot_b | kernel **linux-lenovo-j606f r121** (uname `#122`, both cameras), boot.img written by boot-deploy automatically; r121 was tested through `fastboot boot` first; rollback images in the private backup |
| dtbo_b | **erased** (`fastboot erase dtbo_b`): ABL applies no overlay, compatible = `lenovo,j606f` |
| dtbo_a, vbmeta_a / vbmeta_b | stock |
| userdata (102 GiB) | **pmOS rootfs**: GPT (sector 4096) pmOS_boot 480 MiB + pmOS_root 102 GiB (moved block by block from super with the same UUIDs, 29.10) |
| super (12 GiB) | **stock** (restored from the backup 03.11 to test the archive): vendor is available to the firmware extraction |
| Android | super is stock again, but userdata holds pmOS — Android in slot a was not tested |
| modem*/persist/fsg/abl/xbl | untouched (rmtfs in pmOS writes EFS to modemst1/2 and fsg — as intended) |
| Access | `ssh user@172.16.42.1` (USB) or over Wi-Fi; on the tablet passwordless `sudo` for user and autologin (local setting, **not in the image**) |
| apk | repository `https://repo.yarnick.ru/j606f` without a tag — from the device package (`/usr/lib/apk/repositories.d`, key in `/usr/lib/apk/keys`), migrated with `repo-migrate`; on the tablet and in the apk repository linux-lenovo-j606f r121 and libcamera r6 (own build of the pmOS libcamera with the OV13B10 and S5K4H7 helpers, all subpackages except -dbg) ; device r23 on the tablet, device r24 in the apk repository (+ nt36523w r14; since 03.11); the apk repository also has the shared firmware set firmware-lenovo-j606f 0.320208 (stock S320208); our tablet has its own firmware 1-r3 (with `awinic/aw882xx_acf.bin`: our vendor is wiped) |

Local settings on the tablet (lost on a full reinstall of the image):
- kscreen: DSI-1 `rotation.left` (landscape), scale 1.4;
- `apk add mesa-vulkan-freedreno fastfetch` (Vulkan: Turnip Adreno 610); `~/.config/fastfetch/config.jsonc` — GPU through Vulkan;
- the Mi Mouse3C Bluetooth mouse is paired and trusted (`bluetoothctl`);
- on-screen keyboard: `kwinrc [Wayland] InputMethod=/usr/share/applications/org.kde.plasma.keyboard.desktop`, `VirtualKeyboardMode=2`; `plasmakeyboardrc [General] enabledLocales=en_US,ru_RU`;
  shortcut `~/.local/bin/osk-toggle` + `org.j606f.osk-toggle.desktop` on the panel;
- sensors: since device r22 from the package — firmware-extract builds the `/usr/share/qcom/sm6115/LENOVO/J606F/` tree (dsp, sensors, socinfo) from the tablet's partitions,
  the hexagonrpcd drop-ins with `-R` are in `/usr/lib/systemd/system/hexagonrpcd-adsp-*.service.d/j606f.conf`; the sensors come up ~2 min after boot;
- `~/.config/kscreenlockerrc`: `[Daemon] Autolock=false, LockOnResume=false` (disabled while there was no touch; the owner decided to keep it);
- `~/.config/powerdevilrc`: `PowerButtonAction=128` (Power = screen on/off);
- mpv (settings from device r20: `/etc/mpv/mpv.conf` — profile=fast, hwdec=no; the own `~/.config/mpv/mpv.conf` was removed), glmark2, vkmark;
- zsh + starship shell, Konsole with JetBrains Mono Nerd and a dark scheme, KDE: Papirus-Dark, Breeze window decoration, night light;
- locale ru_RU.UTF-8, NTP (systemd-timesyncd) enabled: the PMIC hardware clock is not written from Linux, without network the time comes from the timesyncd stamp;
- `/etc/apk/repositories`: pmOS — `https://mirror.minlexx.ru/postmarketos/{extra-repos/systemd/main,main}`, Alpine — `http://mirror.yandex.ru/mirrors/alpine/edge/{main,community,testing}`
  (mirror.nura.eco serves ~500 B/s from this network; the fallback is the official RWTH Aachen).

## 3. Next step
0. ✅ **The "download and flash" archive** (03.11): device r22 (sensors from the package), r23 (the image needs no Lenovo blobs, one reboot after the first boot),
   r24 (the GPU zap is optional in the initramfs) — in the apk repository. Archive: userdata.img + boot.img + flash-all.{sh,bat} + SHA256SUMS + README.txt ([`release/`](release/)).
   Tested on our tablet with the stock super: the first boot extracted the firmware from modem, bluetooth, dsp, persist and vendor; GPU (FD610), touch, speakers,
   BT, Wi-Fi and sensors work. Not tested: flash-all.bat (Windows) and installing with a wiped vendor.
0a. **CrashDump** (the tester — on volume keys, a browser page reload and a reboot; ours — ~2 min after a resume from s2idle), kernel r121.
   No panic in the journal (an SoC hang → watchdog). On resume — "Watchdog detected hard LOCKUP" in cpuidle_enter_s2idle.
   Next: reproduce and take the ramoops (`/var/lib/systemd/pstore`) on the first boot after the crash. For now — advise turning automatic sleep off.
0c. **Wi-Fi and wlanmdsp.mbn** (03.11): on our system with the personal firmware package, after the release image had run, the modem stopped
   accepting its wlanmdsp.mbn (it differed from the file in modem_a): "User-PD grace timer expired for wlan_process", no wlan0. The stock file from modem_a
   in `/lib/firmware/updates` brought Wi-Fi back ([docs/notes/firmware.md](docs/notes/firmware.md)). The release archive and the shared set are not affected
   (firmware-extract takes wlanmdsp from modem_a). Volume keys checked with evtest.
0d. **UEFI and Windows on ARM** (since 04.11): explored separately — UEFI [Project Aloha mu_aloha_platforms](https://github.com/Project-Aloha/mu_aloha_platforms/releases),
   installation following the [Renegade Project guide](https://renegade-project.tech/en/install). pmOS stays the main system.
0b. Cameras: both work (r121 + libcamera r6). Next — autofocus, front AGC with backlight, colour tuning (ov13b10.yaml, s5k4h7.yaml),
   hiding the raw CAMSS nodes in PipeWire (a WirePlumber rule), the PMI632 flash.
1. ✅ **Venus works**: kernel r115 + firmware r2, hardware H.264 and HEVC 1080p tested through `v4l2m2m-copy` with a clean EOF. Published (patch 0011 in the repository, packages in the apk repository); mpv uses software decoding by default (r20).
2. Suspend: r110 fixed USB ep0, r111 achieved a successful s2idle; on r121 suspend and resume run without USB/ADSP errors, sound and BT come back.
   Since **device r21** (nt36523w r11) the suspend helper is packaged: `j606f-sleep.service` stops the sensors and BT before suspend, `j606f-resume.service`
   (After=suspend.target) brings hexagonrpcd-adsp-rootpd/sensorspd and iio-sensor-proxy back afterwards. The cause of the old bug: hexagonrpcd-adsp-* have
   `Conflicts=suspend.target`, systemd stopped them at the same time as our hook, so they never got onto the restore list. 02.11: three suspend cycles —
   sensors, ADSP, sound, BT are back. Not tested: long suspend (hours) and suspend with OTG; when suspended from ssh the BT UART (msmgpio 11) wakes it after ~2 s.
3. Offline charging: device r11 tells a reboot from a charger boot. The final poweroff → charger → unplug cycle is not finished; the plan is to drop the «hold power button to boot» screen and do offline charging differently.
4. Defaults in the device package (Power = screen, on-screen keyboard EN/RU, no autolock, scale 1.4) — the tester had to set these by hand.
5. Audio next: ES7210 microphones (port of the Lenovo driver), headset over USB-C (FSA4480 + WCD937x); the speakers are done (r117). Auto-rotation (ACCEL_MOUNT_MATRIX), sensor packaging, writing the charger limits,
   Novatek touch for the NT36523W revision, the pen.

## 4. How to update without reinstalling (the procedure since r120)
A full reinstall resets the local settings and needs fastboot. Instead:
1. Build the packages: `pmbootstrap build <package>` → `.apk` (signed with the repository key, which is already on the tablet).
2. A new kernel — first without writing: a test image = the current `/boot/boot.img` with vmlinuz and DTB from the new package
   ([`scripts/bootimg_replace_dtb.py`](scripts/bootimg_replace_dtb.py)), `systemctl reboot --reboot-argument=bootloader`, `fastboot boot`, check.
3. Save a copy of boot_b and `/etc/apk/world`, then `sudo apk add <.apk files>` — mkinitfs and boot-deploy write boot_b by themselves (device r7+);
   restore world from the copy, reboot and check `uname -v` (`#<pkgrel+1>`).
4. Publish to the apk repository — everyone else gets it with a plain `apk upgrade`. Rollback — the previous boot.img through `fastboot flash boot_b`.

## 5. Build (pmbootstrap)
- `pmbootstrap_v3.cfg`: device lenovo-j606f, **ui plasma-desktop**.
- Mirrors:
  `pmbootstrap config mirrors.alpine http://mirror.yandex.ru/mirrors/alpine/`,
  `pmbootstrap config mirrors.pmaports https://mirror.minlexx.ru/postmarketos/`,
  `pmbootstrap config mirrors.systemd https://mirror.minlexx.ru/postmarketos/extra-repos/systemd/`.
- The kernel is built cross-native; a rebuild with ccache takes ~12 min, from scratch ~80 min. Install with Plasma ~25 min.

## 6. Versions
- pmbootstrap **3.12.1**; pmaports branch **main** + local commits; channel **systemd-edge**.
- Kernel: **linux-lenovo-j606f 7.2.3-r121** on the tablet and in the apk repository (up to r117 — linux-nura-qcom-sm61x5; codeberg.org/sm61x5-mainline/linux v7.2.3-r0 + `kernel/patches/0001, 0003–0024`), uname `7.2.3-sm61x5 #122`.
- libcamera: **99990.7.2-r6** (pmaports temp/libcamera + 0007 OV13B10, 0008 S5K4H7) on the tablet and in the apk repository (above pmOS r4).
- device-lenovo-j606f **r24** in pmaports and the apk repository, r23 on our tablet (r22: sensors from the package; r23: no Lenovo blobs; r24: optional zap; the j606f-sleep/j606f-resume suspend helper, the port's repository and its key, `/etc/mpv/mpv.conf`, rootfs → userdata, automatic boot_b write, offline-charger hook, speaker UCM, SoundWire → WCD937x softdep, firmware from the tablet's own modem/bluetooth/super — into /lib/firmware/updates with the shared set, an apk trigger); firmware-lenovo-j606f: personal **1-r3** (from our own backup, not published) or the shared **0.320208** from the apk repository (`APKBUILD.shared`); hexagonrpcd 0.4.0-r50 (our `sns_reg_version` patch).
- postmarketos-ui-plasma-desktop 5; Plasma 6.8.1; Mesa 26.2.5 (freedreno FD610); Alpine edge.
- Stock firmware: TB-J606F_S120184_210520_ROW (Android 10), ABL "Loader Build Info: Sep 4 2021".

## 7. Checklist
P0: [x] display+backlight · [x] stable boot from internal storage after power off and on · [x] touch (HX83102E, patch 0006; pen not tested) ·
[x] USB networking + SSH · [x] Wi-Fi (connection, DHCP, DNS, internet) ·
[~] battery and charging: gauge (mm8013), charger status (read-only), charging from USB-A and from a USB-C wall charger (FUSB302, 5 V); no offline charging and no writing of limits · [x] buttons (Power turns the screen off/on, volume checked by the owner).
P1: [x] GPU + Wayland (Plasma), Vulkan (turnip) · [x] cameras (rear with manual focus, front) · [~] audio (speakers ✅ r117; no microphones or headset) · [x] BT (pairing and input: Mi Mouse3C mouse) · [x] sensors (light, proximity, accelerometer; orientation — the matrix is to be found) · [~] USB OTG (FUSB302) · [~] suspend (r110/r111 + the suspend helper in device r21; CrashDump after a resume) · [x] GPU performance (DDR votes, 0009) · [x] hardware H.264/HEVC decoding (Venus, 0011/r115).
P2/P3: pmaports packages (linux-lenovo-j606f r121, libcamera r6, device r24, device-lenovo-j606f-nt36523w r14, firmware 1-r3 (personal APKBUILD) + APKBUILD.shared (shared 0.320208), hexagonrpcd r50) — in `pmaports/`; apk repository https://repo.yarnick.ru/j606f; documentation — this repository.
