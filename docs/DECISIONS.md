# DECISIONS

## 2026-10-28 — Phase 1: what upstream has (checked online on that day)

### Project renaming (an observation, not a guess)
- https://wiki.postmarketos.org/* answers 301 → https://wiki.nura.eco/* (checked with `curl -sI`)
- The pmaports GitLab project is described as "Nura package build recipes", pmbootstrap as "...install Nura". The latest pmbootstrap tag is 3.12.1. The default pmaports branch is `main` (not master).
- New kernels in pmaports are called linux-nura-*.
- The device wiki page could not be read: wiki.nura.eco is behind Anubis (bot protection, error 9e4edb5b6b850c41). I will not bypass the protection; I will ask the owner to open the page in a browser.
- The pmaports MR template links to the AI policy: https://docs.postmarketos.org/policies-and-processes/development/ai-policy.html. **Read it before sending anything upstream (P3).**

### pmaports
- `device-lenovo-j606f` does **not** exist in main/community/testing/downstream/archived, and there is no commit history for these paths (GitLab API tree+commits, branch main).
- `device/testing/linux-nura-qcom-sm61x5`: pkgver 7.2.3, "Close to mainline linux kernel for Qualcomm Snapdragon SM61x5", maintainer Barnabas Czeman, sources https://codeberg.org/sm61x5-mainline/linux (tag v7.2.3-r0, config based on sm6125_defconfig). Added by MR !9491 (merged 2026-10-08) https://gitlab.postmarketos.org/postmarketOS/pmaports/-/merge_requests/9491, together with the device packages xiaomi-laurel (Mi A3), ginkgo, willow.
- `device/archived/linux-postmarketos-qcom-sm6115` 6.10 (github.com/sm6115-mainline/linux), archived on 2026-06-22 as unmaintained.
- MR !8048 "config-postmarketos-qcom-sm6115: enable support for NT36523" (for the Tab P11) was closed without merging.
- There is no firmware package for the J606F. There is https://github.com/sm6115-mainline/firmware-qcom-sm6115 (not studied).

### Mainline Linux DTS
- `arch/arm64/boot/dts/qcom/sm6115p-lenovo-j606f.dts`, Copyright 2022 Linaro. Present in torvalds/master and in codeberg sm61x5 v7.2.3-r0, the files are **byte-identical** (sha256 8664cb3e…). Copies are in notes/dts/.
- Enabled: simplefb (1200x2000 @0x5c000000), gpio-keys Vol+, PON pwrkey/resin (Vol−), ramoops @0xffc00000 (1 MiB), GPU (zap qcom/sm6115/LENOVO/J606F/a610_zap.mbn), MDSS+DSI0+panel "lenovo,j606f-boe-nt36523w" (reset gpio82, rotation 180), ADSP/CDSP/MPSS (fw qcom/sm6115/LENOVO/J606F/{adsp,cdsp,modem}.mbn), pm6125 regulators, SD (sdhc_2, cd gpio88), UFS, USB **peripheral only, high-speed**, Wi-Fi (ath10k, variant Lenovo_P11).
- **Not described**: touchscreen, backlight (sgm37604a), tps65132, battery/charging (mm8013, pmi632), fusb302/Type-C, audio, Bluetooth, sensors, cameras, keyboard.
- Per LKML (Konrad Dybcio's patch "sm6115p-j606f: Hook up display", v2, June 2023, https://lkml.iu.edu/hypermail/linux/kernel/2306.2/05576.html): there is a **second SKU with a different panel and touch combination**, it is not supported. The revision of our unit has to be determined.

### Conclusion for Phase 2 (preliminary, no decision taken)
Mainline covers boot, UFS, display (for the BOE SKU), GPU, Wi-Fi, buttons, SD, USB gadget. That is a strong base, so **mainline based on linux-nura-qcom-sm61x5 is preferred** (an upstream package, recent, with a maintainer). Downstream 4.19 is not considered unless a blocker appears. The missing parts (touch, backlight, battery, BT, audio) will have to be added to the DTS. Final decision after the panel SKU is confirmed.

## 2026-10-29 — after the root exploration and the first mainline boot
- **SKU**: the owner has HX83102P (BOE) + HX83102E touch. The mainline DTS describes NT36523W. Decision: a separate DTS `sm6115p-lenovo-j606f-hx83102p.dts`
  that includes the base one and overrides the panel, plus panel support in panel-himax-hx83102.c (init from the stock DT).
  To discuss for upstream later: one DTS for two SKUs is impossible without the bootloader selecting the panel; two DTS files are normal practice.
- **Kernel**: linux-nura-qcom-sm61x5 7.2.3 (Codeberg sm61x5-mainline). Boot tested (USB gadget, UFS, simpledrm, thermal).
  Its config has HX83102, NT36523, TPS65132, MM8013 disabled: this package does not support the J606F. An own kernel config/fragment or an MR to pmaports is needed.
- **dtbo**: the dtbo partition is not touched for now, worked around with a "sink" in the DTB (notes/boot.md). For pmaports this needs a proper form: either a script/hook in the
  device package that appends /abl-sink and __symbols__ when building boot.img, or documenting "flash an empty dtbo".
- **Building without a Linux host** (temporarily, until there is an SSH key): an Alpine build environment in tmpfs on the tablet itself under mainline,
  packages through an HTTP proxy on the Mac (scripts/mirror_proxy.py). Nothing is written to internal storage.

## 2026-10-29 — where to build and where to install
- **Decision: build on the tablet itself** (8 aarch64 cores, native, no qemu) under the mainline kernel from fastboot boot.
  Workspace: the **userdata** partition (/dev/sda15, ≈110 GiB), formatted as ext4 (the owner allowed wiping Android).
  pmbootstrap inside an Alpine chroot on userdata under a separate user with sudo (our own environment). Packages through the HTTP proxy on the Mac.
- **pmOS installation: the super partition** (12 GiB, formerly Android system/vendor/product) for pmOS_boot+pmOS_root, boot.img in **boot_b**, slot b active. Slot a (boot_a/dtbo_a) stays as is, in case the bootloader rolls back.
- Getting into fastboot without Android: mainline has the PON reboot-mode (pm6125.dtsi: mode-bootloader = <0x2>, CONFIG_REBOOT_MODE=y) → `reboot bootloader`.
- First pmOS build: UI = none (console + SSH), then a UI of the owner's choice.

## 2026-10-29 (day) — installation and kernel build on Ubuntu
- **The installation did not follow install_plan.md**, instead: pmOS rootfs in **super** (12 GiB, formerly system/vendor/product), boot.img in **boot_b**, active slot **b**.
  userdata (sda15) is kept as the pmbootstrap workspace on the tablet. dtbo was not touched: the "sink" in the DTB works, an empty dtbo was not tested.
  and freed up space (~24–29 GB). On the tablet a kernel build would take 3–4 h, and the tablet is needed for testing.
  Mac 127.0.0.1:8080) in scripts/mirror_proxy.py on the Mac (56–82 KB/s from the Mac, *.apk are cached). The proxy accepts only link-local, 127.0.0.1 and the addresses from MIRROR_ALLOW.
- device-lenovo-j606f r3: no prebuilt .ko/.dtb (everything from kernel pkgrel 101), cmdline `console=tty0 fbcon=rotate:2 clk_ignore_unused pd_ignore_unused`,
  `/usr/lib/modules-load.d/j606f.conf` with mm8013. Kernel: patches 0001–0003 + a config fragment (HX83102, TPS65132, MM8013, NT36523 = m).
- HACK 0002 stays for now (ABL replaces the root compatible). It can only be removed after testing an empty dtbo_b.

## 2026-10-29 (evening) — dtbo_b erased
- A tip from the owner's partner: if the dtbo partition is erased, ABL takes the DTB from boot.img without an overlay. Tested: `fastboot erase dtbo_b` → the root compatible
  stays `lenovo,j606f`, the model comes from our DTS. Decision: keep dtbo_b erased for pmOS on slot b. abl-sink and HACK 0002 are left in kernel r101 for now
  (harmless, needed if the dtbo comes back); drop HACK 0002 in the next kernel build.
- The GPU firmware (a630_sqe, a610_zap) goes into the initramfs through /usr/share/mkinitfs/files (device r4), because msm is in modules-initfs.

## 2026-10-29 (night) — root on userdata, sensors, documentation
- **The pmOS rootfs was moved from super (12 GiB) to userdata (~100 GiB)** at the owner's request ("the whole system on userdata"): only ~6 GB were left in super.
  Block-level move with the same UUIDs, local settings preserved. The GPT of the subpartitions in super was removed (the initramfs scans partitions by
  `/proc/diskstats` and would otherwise pick super first), a dump of the table is kept. device r6: `deviceinfo_flash_fastboot_partition_rootfs="userdata"`.
- **Sensors through SSC**: an own hexagonrpcd patch (serves `sns_reg_version`) as `temp/hexagonrpcd` 0.4.0-r50, rather than changing the layout on the ADSP side;
  drop-ins with `-R` for the hexagonrpcd services. The SSC files come from one's own device and are not part of the repository.
- Audio: start with the headphone jack (PM4125/WCD937x, the drivers exist); the AW88258 speakers — only from the Awinic GPL sources (risk of damaging the speakers).

## 2026-10-29 — touch: port of the Lenovo driver rather than the hid-himax series
- The stock Lenovo GPL driver (`himax83102p`, HX83102E zero-flash) from github.com/adazem009/kernel_lenovo_tbj606 was taken and ported to 7.2 with a script
  (`src/himax83102p-port/port.py`), rather than Allen Lin's "hid-himax" series (HX83102J, the protocol may differ). The script leaves the Lenovo sources untouched
  and produces the reproducible patch 0006; the driver is a single module `himax_hx83102e.ko` (=m in kernel package r106).
- Orientation through the standard `touchscreen-inverted-x/y` in the DT (as in other drivers), not a libinput udev matrix: works for every input consumer.
- The touch firmware (`Himax_firmware.bin`, `Himax_mpfw.bin`) is in the local firmware package r1 (not published).

## 2026-10-30 — USB-C, GPU, apk repository
- USB-C: FUSB302 + boost on gpio38 (as in stock), not the PMI632 Type-C/OTG (the PMI632 Type-C is in micro-USB mode, its OTG boost does not reach the connector). PD is disabled
  while the charger driver is read-only.
- GPU: the DDR vote from the stock kgsl table (patch 0009) in common.dtsi — a device-level change, not in sm6115.dtsi (for upstream — in sm6115.dtsi).
  firmware-lenovo-j606f is not published (blobs of a specific device), the script filters it out and everything with license = proprietary.
  (Revised 31.10: exactly one set is published — the shared S320208 stock, see below.)
- deviceinfo_flash_kernel_on_update is not enabled for now — the owner's decision (risk: a broken kernel/power loss while writing boot_b).
  (Revised: enabled since device r7 — boot-deploy writes boot_b itself; the safety net is a test through fastboot boot and a boot_b backup before installing.)

## 2026-10-31 — firmware, kernel name, repository
- The shared firmware set of the S320208 stock (Android 11) is published in the apk repository as `firmware-lenovo-j606f-0.320208-r1` (a version below
  the personal `1-rN`, so a personal build always wins); the source tar is in `j606f/distfiles`, sha256 is verified at publication. No other firmware.
- The device package takes the DSP firmware of the tablet's own stock from its partitions (firmware-extract) and puts it in /lib/firmware/updates: an ADSP
  of another version breaks the sensors.
- The kernel is renamed to `linux-lenovo-j606f` (r118): a package from the regular repositories cannot replace it, the `@j606f` tag is not needed.
  The repository address and key are in the device package (r18), old installs migrate with `repo-migrate`.
- Audio: the speakers first (TDM on LPI, our own AW88258 driver from the GPL sources), ES7210 and the USB-C headset later; the volume is limited (no stock protection).

## 2026-11-01 — cameras
- CAMSS SM6115 — with our own tables (3× CSIPHY/CSID/TFE like QCM2290), libcamera — our own build of the pmOS package with sensor helpers (temp/libcamera).
- Front S5K4H7 — our own driver from the registers of the stock CamX module (no driver in mainline). The CSID1/TFE1 path hangs the SoC → only CSID0/TFE0
  is used (libcamera picks it by itself); do not enable CSID1 by hand.
- A kernel is tested through `fastboot boot` (the current boot.img + new vmlinuz/DTB) and only then installed through apk.

## 2026-11-02 — documentation in English
- The English version is the `english` branch of the same GitHub repository (all .md files translated), not a separate repository; main stays Russian,
  with a link to the branch in the README. Documentation changes are carried over to english by hand.
