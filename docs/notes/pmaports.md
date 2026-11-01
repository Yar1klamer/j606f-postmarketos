# Building the pmOS (Nura) image with pmbootstrap

> **Since 31.10:** the kernel package is renamed to `linux-lenovo-j606f` (r118; same files and uname suffix, `replaces` the old one), see README "Updates through the apk repository". Below is the history under the old name.

> **Status 29.10 (night):** kernel linux-nura-qcom-sm61x5 **7.2.3-r105** (patches 0001, 0003, 0004, 0005; without HACK 0002), device-lenovo-j606f **r6**
> (r5 on the tablet), firmware-lenovo-j606f r0, temp/hexagonrpcd 0.4.0-r50. Built on the host, installed as an apk upgrade (STATE.md §4).
> Local commits in src/pmaports-main: kernel c523e3a (r101), 06429e1 (r102), d97938f (r103), b2ad809 (r104), 7a93404 (r105);
> device 4a3d060 (r4), 7b52c2d (r5), 9d0a730 (r6, rootfs → userdata); hexagonrpcd 7adbd16. History (before r101): 9f25afd, 02cd3cd, f0ab532.


## 1. Kernel: local changes to linux-nura-qcom-sm61x5 (7.2.3)
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

## 5. What else is needed in the DTS/drivers (from notes/*)
- HX83102E SPI touch (zero-flash) — no driver;
- pmi632 charging: own read-only driver (patch 0004), writing limits is not done; smb1355 — no driver;
- Wi-Fi/BT MAC: ABL does not pass them; stable addresses derived from serialno are set by bootmac (device r5), the factory ones from persist are not used;
- ~~slow page flips in msm~~ — turned out to be a test artefact (modetest without stdin), the real rate is 60 Hz (notes/display.md);
- audio (aw88258, es7210, wcd937x/pm4125) — not started (notes/audio.md); sensors (SSC) — **work** (notes/sensors.md), not packaged.

## 6. Upstream (P3)
Before any MR read the AI policy: https://docs.postmarketos.org/policies-and-processes/development/ai-policy.html
