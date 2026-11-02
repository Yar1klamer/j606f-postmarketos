# Installing on the revision with the Novatek NT36523W panel

> **Status: not tested on hardware.** The port was done on the HX83102P revision. For NT36523W there is a separate DTB
> (`sm6115p-lenovo-j606f-nt36523w.dts`) and device package `device-lenovo-j606f-nt36523w`; everything except the panel and touch is shared between the revisions.

## Which revision you have
In stock Android as root: `cat /proc/cmdline | tr ' ' '\n' | grep dsi_display0`
- `qcom,mdss_dsi_nt36523w_boe_2k_video` — this guide;
- `qcom,mdss_dsi_himax83102p_boe_2k_video` — the main guide in the README (device `lenovo-j606f`).

## What to expect
| | |
|---|---|
| Display, backlight | the panel driver is in mainline (Linaro tested exactly on NT36523W) |
| GPU, Wi-Fi, Bluetooth, battery, charger (status), buttons, sensors | shared with HX83102P, should work |
| **Touch** | **no**: the Novatek NT36523 over SPI (CS1) is not ported yet (source: the Lenovo kernel, `drivers/input/touchscreen/NT36523W`) |
| USB OTG | shared with HX83102P (FUSB302 + boost gpio38, patch 0008), should work |

Without touch you need a Bluetooth mouse/keyboard (paired over SSH with `bluetoothctl`) or SSH over USB.

## 1. Unlocking the bootloader (wipes all data)
1. Settings → About tablet → tap "Build number" 7 times; Developer options → "OEM unlocking" and "USB debugging".
2. `adb reboot bootloader`, then `fastboot flashing unlock` and confirm with the volume keys. The tablet is reset to factory settings.
3. Go through the Android setup again and enable "USB debugging".

## 2. Temporary root (without flashing boot)
1. Take **exactly the same** `boot.img` as installed (build number in "About tablet"): the firmware from Lenovo Rescue and Smart Assistant
   (LMSA) for your serial number, the `boot.img` file from the archive.
2. Install the Magisk app, "Install → Select and patch a file" → get `magisk_patched-….img`.
3. `adb reboot bootloader`, then `fastboot boot magisk_patched-….img` (boot only, the boot partition is not changed).
   `fastboot boot` works **once** per session in this bootloader; on error — `fastboot reboot bootloader` and retry.
4. In Android: `adb shell su -c id` → allow root for Shell on the screen.

## 3. Backup and firmware (read only)
From the repository directory, with the tablet connected over USB:
```bash
bash scripts/backup_partitions.sh        # all partitions except userdata, sha256-verified (~13 GB) → BACKUP/partitions/
bash scripts/collect_firmware.sh         # Lenovo firmware → FIRMWARE/<date>/*.tar
```
Keep the backup (`BACKUP/`) yourself: it is the only way to restore modem/persist/EFS. `FIRMWARE/` contains your device's proprietary files:
give them only to whoever builds your image, and do not publish them.

## 4. Image
Built with pmbootstrap using the pmaports from this repository (`pmaports/device/testing/`): kernel `linux-lenovo-j606f`,
`device-lenovo-j606f-nt36523w`, `firmware-lenovo-j606f`: either the shared set of the S320208 stock from the apk repository (`APKBUILD.shared`, no backup needed,
the device package takes the DSP firmware of your own stock from the tablet's partitions), or a tarball of your files (the layout is in the APKBUILD).
```bash
pmbootstrap init        # device: lenovo-j606f-nt36523w
pmbootstrap install --password <temporary password>
pmbootstrap export      # lenovo-j606f-nt36523w.img (rootfs, sparse) and boot.img
```

## 5. Installation (slot b, the Android bootloader of slot a is not touched)
```bash
fastboot boot boot.img                         # a test without writing; it will not reach the rootfs yet — we only wait for a picture/USB networking
fastboot reboot bootloader
fastboot flash userdata lenovo-j606f-nt36523w.img   # sparse image: fastboot only, not dd
fastboot flash boot_b boot.img
fastboot erase dtbo_b                          # otherwise the bootloader applies the stock overlay and the kernel does not start
fastboot --set-active=b
fastboot reboot
```
First login: USB networking `ssh user@172.16.42.1` (password from `pmbootstrap install`), run `passwd` right away.
Android will not boot after this (userdata is taken); back to stock: `fastboot --set-active=a` + a reset through recovery, or LMSA.

## 6. Updates through the apk repository
Since device-lenovo-j606f-nt36523w r8 the repository address and key come with the device package itself
(`/usr/lib/apk/repositories.d/j606f.list`, `/usr/lib/apk/keys/`): `sudo apk update && sudo apk upgrade && sudo reboot` — that's all.
An installation with device ≤ r7 needs a one-time migration (details in the README, "Updates through the apk repository"):
```bash
echo "https://repo.yarnick.ru/j606f" | sudo tee -a /etc/apk/repositories
sudo apk update
sudo apk add linux-lenovo-j606f device-lenovo-j606f-nt36523w device-lenovo-j606f-nt36523w-nonfree-firmware
sudo /usr/lib/j606f/repo-migrate
sudo reboot
```
Do not install `device-lenovo-j606f` (that is the HX83102P revision package): both device packages ship their own deviceinfo and DTB, they cannot be installed together.

## 7. If something goes wrong
- Black screen, but USB networking is up — send `dmesg` (`ssh user@172.16.42.1 sudo dmesg > dmesg.txt`).
- Neither screen nor USB networking after ~1 min — `Vol− + Power` into fastboot, `fastboot --set-active=a`, and report what was on the screen.
