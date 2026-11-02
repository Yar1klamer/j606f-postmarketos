# Building the pmOS (Nura) image with pmbootstrap

> **Status 02.11:** the port's packages are in `pmaports/` of this repository: kernel **linux-lenovo-j606f 7.2.3-r121** (linux-nura-qcom-sm61x5 + patches 0001, 0003–0024;
> its own name since 31.10/r118, `replaces` the old package), device-lenovo-j606f **r20**, device-lenovo-j606f-nt36523w **r10**, firmware-lenovo-j606f
> (personal APKBUILD + `APKBUILD.shared` for the shared set 0.320208), temp/hexagonrpcd **0.4.0-r50**, temp/libcamera **99990.7.2-r6** (0007 OV13B10, 0008 S5K4H7).
> Built on an Ubuntu host, installed and updated through apk (STATE.md §4), distributed through the apk repository (README).
> The sections below are the original steps of 28–29.10 (under the old kernel name) with notes on what changed.

## 1. Kernel: local changes to linux-nura-qcom-sm61x5 (7.2.3)
> Now this is a separate package `device/testing/linux-lenovo-j606f` (patches 0001, 0003–0024 and config-j606f.fragment are already in it); below — how it started.

In the local pmaports copy: device/testing/linux-nura-qcom-sm61x5/
- add to source= and to prepare() (default_prepare applies *.patch):
  - src/patches/0001-drm-panel-himax-hx83102-add-Lenovo-J606F-BOE-HX83102P.patch (panel: init from stock, timings, DCS backlight)
  - src/patches/0003-arm64-dts-qcom-sm6115p-lenovo-j606f-add-HX83102P-SKU.patch (DTS + abl-sink.dtsi + Makefile)
  - src/patches/0002-HACK-soc-qcom-match-qcom-bengalp-root-compatible.patch — ONLY if the stock dtbo is kept (see item 4)
- in config-nura-qcom-sm61x5.aarch64: src/patches/config-j606f.fragment (HX83102, TPS65132, MM8013, NT36523 = m)
- `pmbootstrap checksum linux-nura-qcom-sm61x5`
All three patches are checked: `git apply --check` on tag v7.2.3-r0 (commit 5a88d98) passes; 0001+0002 and the built modules were tested on the device; the DTS was built and booted (tests 5–7).

## 2. Device and firmware packages
- src/pmaports/device/testing/device-lenovo-j606f/{APKBUILD,deviceinfo,modules-initfs} → into pmaports/device/testing/
- src/pmaports/device/testing/firmware-lenovo-j606f/APKBUILD + the tarball firmware-lenovo-j606f-1.tar:
  qcom/sm6115/LENOVO/J606F/{a610_zap,adsp,cdsp,modem,wlanmdsp}.mbn (out/fw), qca/{crbtfw21.tlv,crnv21.bin} (out/serve/fwbt/qca).
  Blobs from THIS device, do not publish.
- The dependency packages exist: msm-firmware-loader, linux-firmware-qcom, linux-firmware-ath10k (pmOS/Alpine), rmtfs, tqftpserv, qbootctl, hexagonrpcd, iio-sensor-proxy (Alpine community). Checked against APKINDEX on 2026-10-29.

## 3. Build
```bash
pmbootstrap init            # device: lenovo-j606f, UI: the owner's choice
pmbootstrap install         # rootfs
pmbootstrap export          # boot.img and the rootfs image in /tmp/postmarketOS-export
```
First test: only `fastboot boot boot.img` (pmOS kernel+initramfs), rootfs from an SD card or over USB (pmOS initramfs debug shell).

## 4. Installing to internal storage — THE OWNER'S DECISION
Option A (recommended): **slot b** for pmOS, Android on slot a is not touched.
- `fastboot flash boot_b boot.img`; dtbo_b: an empty dtbo (mkdtboimg without entries) → ABL applies no overlay, then HACK 0002 and abl-sink are not needed (to be checked!);
- rootfs: userdata (110 GiB, the data does not matter, but format only after an explicit "yes"). At first it was different (rootfs in super, userdata for building); **since 29.10 (night) rootfs is in userdata** (author's notes, device r6: `deviceinfo_flash_fastboot_partition_rootfs="userdata"`);
- `fastboot set_active b`; rollback: `fastboot set_active a`. pmOS must mark the slot successful (qbootctl), otherwise ABL falls back to a after ~7 attempts.
Option B: slot a (replace Android). Rollback: BACKUP/.

## 5. What else is needed in the DTS/drivers (from notes/*, as of 02.11)
- ✓ HX83102E SPI touch (zero-flash) — port of the Lenovo driver, patch 0006;
- pmi632 charging: own read-only driver (patch 0004), writing limits is not done; smb1355 — no driver;
- Wi-Fi/BT MAC: ABL does not pass them; stable addresses derived from serialno are set by bootmac (device r5), the factory ones from persist are not used;
- ~~slow page flips in msm~~ — turned out to be a test artefact (modetest without stdin), the real rate is 60 Hz (notes/display.md);
- audio: ✓ AW88258 speakers (0012–0016); no ES7210 (microphones) and no headset over USB-C/FSA4480 (notes/audio.md);
- sensors (SSC) — **work** (notes/sensors.md); the hexagonrpcd drop-ins and the SSC files are not packaged;
- cameras: ✓ OV13B10 + DW9763, S5K4H7 (0017–0024); no autofocus, PMI632 flash, libcamera tuning (notes/camera.md);
- suspend: the j606f-sleep helper is not packaged (notes/suspend.md); Hall, pogo keyboard, vibration motor, LED — not described.

## 6. Upstream (P3)
Before any MR read the AI policy: https://docs.postmarketos.org/policies-and-processes/development/ai-policy.html
