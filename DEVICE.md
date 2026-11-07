# DEVICE — Lenovo Tab P11 TB-J606F (everything that is known)

> The serial number, MACs and partition GUIDs are scrubbed (`<SERIAL>`, `<WIFI_MAC>`, `<BT_MAC>`, …). Sources: adb/getprop, root dumps,
> fastboot getvar, stock dmesg, the stock DT (live.dtb), mainline logs.

## Boot modes and access
| Mode | How to get there | Note |
|---|---|---|
| fastboot (ABL) | powered off → **Vol− + Power**; from Android `adb reboot bootloader`; from Linux `reboot(RESTART2,"bootloader")` (PON reboot-mode, pm6125 mode-bootloader=0x2) | `fastboot boot` — once per session; `is-userspace: no`; max-download 768 MiB |
| recovery | Vol− + Vol+ + Power | recovery_a/b partition (separate, A/B + recovery as on Android 10) |
| EDL | hold Vol+ and connect USB | for a qdl rollback |
| Hard reset | hold Power ~10–15 s | |
| Android adb | USB 18d1:4ee7 (bcdDevice 4.19), model "Lenovo Tab P11" | Android no longer boots (super overwritten) |
| fastboot USB | 18d1:d00d | |
| debug initramfs (ours) | `scripts/make_debug_bootimg.py` | gadget 18d1:d001 ECM+ACM, 169.254.42.1, nc :9100 |
| pmOS | `ssh user@172.16.42.1` | initramfs: debug shell telnet :23, ACM `/dev/cu.usbmodempostmarketOS*` |

fastboot getvar (stock): product bengal, variant SMP UFS, hw-revision 10000, secure yes, unlocked yes, current-slot a, slot-count 2,
slot a successful=yes retry=6, slot b successful=no retry=0 (b had never booted before us), kernel uefi, off-mode-charge 1, version-bootloader/baseband empty.

## Hardware status in Linux (mainline 7.2.3)
| Block | Chip / driver | Status |
|---|---|---|
| Display | BOE + Himax HX83102P, DSI 4 lane, 1200x2000@60, msm DPU 6.3 + panel-himax-hx83102 (patch 0001) | ✅ confirmed visually; the panel is mounted upside down (rotation 180) |
| Backlight | DCS 0x51 12 bits (0…4095) → SGM37604A (en: pmi632 gpio6) | ✅ confirmed visually; DCS 0x52 (read) is not supported |
| LCD bias | TPS65132 I2C1 0x3e, ±5.7 V, ENP tlmm 111, ENN tlmm 44 | ✅ |
| GPU | Adreno 610, freedreno FD610 (Mesa 26.2.5), zap a610_zap.mbn | ✅ GLES 3.2 and Vulkan (turnip), Plasma at 60 Hz; DDR bandwidth vote (patch 0009) |
| Touch/stylus | Himax HX83102E zero-flash, SPI0 (QUP SE2 4a88000), irq tlmm 86, rst tlmm 54, FW Himax_firmware.bin | ✅ touch fully works; the stylus cannot be tested as we do not have one |
| Wi-Fi | WCN3990 ath10k_snoc, chip_id 0x150, FW WLAN.HL.3.2.4-00564 (through MPSS + rmtfs + tqftpserv) | ✅ scanning (2.4+5 GHz); connection tested |
| BT | WCN3990 (cherokee) on uart3 4a8c000, SOC 0x40020150, crbtfw21.tlv/crnv21.bin | ✅ fully: pairing, HID devices (mouse) |
| USB | DWC3 4e00000, peripheral, HS | ✅ ECM/NCM/ACM; host/OTG tested |
| Type-C | FUSB302 I2C0 0x22 (tcpm), VBUS boost gpio38 (patch 0008) | ✅ OTG and C-to-C charging (Rd), no PD |
| Battery | MM8013 I2C0 0x55 (`mitsumi,mm8013`), 7500 mAh, 328 cycles (29.10) | ✅ charge/discharge and current sign are correct (patch 0005) |
| Charging | PMI632 (smb5) + SMB1355 | ✅ charges (5 V, 1.5 A input); ⚠️ the PMI632 driver is read-only (patch 0004), bootloader settings; SMB1355 is unused |
| Buttons | Power/Vol− (PON pwrkey/resin), Vol+ (pm6125 gpio5) | ✅ the input devices exist, presses tested |
| CPU/thermal | qcom-cpufreq-hw (1.8/2.016 GHz), tsens 16 zones, cooling-maps (our DTS) | ✅ |
| DSP | modem (MPSS), ADSP, CDSP (stock .mbn) | ✅ start |
| Video | Venus (SM6115), stock venus.mbn (patch 0011) | ✅ hardware H.264/HEVC 1080p (v4l2m2m) |
| Audio | 4× AW88258 (I2C0 0x34–0x37, ID 0x1852), ES7210 (I2C1 0x40), WCD937x + PM2250 (rouleur), FSA4480 | ✅ speakers (AW88258, PRIMARY TDM, patches 0012–0016); ❌ ES7210 microphones and USB-C headset |
| Sensors | ICM4x6xx, LTR578, TMF8801, SX932x — through SSC/ADSP | ✅ light, proximity, accelerometer (patched hexagonrpcd + libssc + iio-sensor-proxy) |
| SD | sdhc_2, cd tlmm 88 | ✅ detected and mounted |
| Pogo keyboard | hid-over-i2c 0x60 (I2C0, irq 93) and 0x61 (I2C1, irq 96), the MCU answers | ✅ keyboard 17ef:6103 + touchpad 04f3:3164 (hid-multitouch), nodes in common.dtsi; tested on hardware |
| Cameras | rear OV13B10 (CCI0 0x10, 4 lanes CSIPHY0) + VCM DW9763 (CCI0 0x0c); front S5K4H7 (CCI1 0x10, CSIPHY2); supply — LDOs on gpio112/108/40 (the PM8008 from the stock DT is not fitted) | ✅ rear: CAMSS + libcamera (patches 0017–0022), manual focus; 🟡 front: own S5K4H7 driver + DT (0023–0024), kernel r121 + libcamera r6 (apk repository 02.11) |
| Vibration, RGB LED, Hall sensor (tlmm 36) | — | ❓ not tested |

---


Sources: raw/adb_20261028_232150/ (adb shell without root, uid=shell), raw/fastboot_20261028_232246/,
then root (Magisk, 28.10 evening, raw/root_20261028/) and mainline (tests 3–9). The sections below up to "Additions" were written before root;
refinements and corrections are in the "Additions 2026-10-29" section at the end.
> Now (02.11): Android is removed; **userdata = pmOS rootfs** (GPT: pmOS_boot + pmOS_root), super — an old copy without the subpartition GPT, active slot **b** (boot_b = pmOS), dtbo_b erased.

## Identification (getprop)
| Parameter | Value |
|---|---|
| ro.product.model | Lenovo TB-J606F |
| ro.product.name | LenovoTB-J606F_RU |
| ro.odm.lenovo.sku / tablet | m11_row_wifi / wifi → **Wi-Fi model, no LTE (confirmed)** |
| ro.boot.baseband | apq |
| serial | <SERIAL> |
| Android | 10 (SDK 29), build QKQ1.200730.002 |
| Firmware | TB-J606F_S120184_210520_ROW (incremental TB-J606F_USR_S120184_2105202124_Q00287_ROW) |
| Security patch | 2021-05-05 |
| fingerprint | Lenovo/LenovoTB-J606F_RU/J606F:10/QKQ1.200730.002/S120184_210520_ROW:user/release-keys |
| ro.board.platform | bengal (= SM6115 family) |
| /proc/cpuinfo Hardware | Qualcomm Technologies, Inc BENGALP |
| CPU | 8 cores: 4× part 0x801 (Kryo 260 Silver) + 4× part 0x800 (Kryo 260 Gold), implementer 0x51 → consistent with SM6115(P)/SD662 |
| RAM | MemTotal 5799328 kB → **6 GB, not 4 GB as assumed** |
| Storage | UFS, 4804000.ufshc; userdata 0x199CCD3000 (~110 GiB) → the 128 GB model |
| Stock kernel | Linux 4.19.95-perf+, clang 8.0.16, built 2021-05-20 |
| bootreason | shutdown,userrequested |
| ro.boot.dtb_idx / dtbo_idx | 1 / 9 |

## Bootloader / AVB / slots (fastboot getvar)
- product: bengal, variant: SMP UFS, hw-revision: 10000, secure: yes, **unlocked: yes**
- **current-slot: a**; slot-count 2
- slot a: successful=yes, unbootable=no, retry=6
- slot b: successful=**no**, retry=0 → slot b had never booted before us (now it holds pmOS and is active)
- is-userspace: no (this is the bootloader fastboot, not fastbootd), kernel: uefi, max-download-size 805306368 (768 MiB)
- version-bootloader and version-baseband are empty
- off-mode-charge 1, charger-screen-enabled 1
- ro.boot.verifiedbootstate=orange, vbmeta.device_state=unlocked, veritymode=enforcing, avb 1.1 (vbmeta avb 1.0)
- ro.boot.vbmeta.digest = 5c7f5b1f1fa6d982a97119e4e3e19c2198dc73d488b26be6edbd72d0f748fd82 (sha256, size 5952) → it can be used to check that a downloaded stock image matches the installed one
- dynamic_partitions=true (super 0x300000000 = 12 GiB), separate recovery_a/b (A/B + a separate recovery, as for devices launched with Android 10)

## Partitions (by-name, UFS LUN)
- sda (LUN0): ssd=1 persist=2 misc=3 keystore=4 frp=5 fpinfo=6 lenovocust=7 lenovoraw=8 recovery_a=9 recovery_b=10 vbmeta_system_a=11 vbmeta_system_b=12 metadata=13 super=14 userdata=15
- sdb/sdc (LUN1/2): xbl_a/xbl_config_a (sdb1,2), xbl_b/xbl_config_b (sdc1,2)
- sdd (LUN3): ALIGN_TO_128K_1=1 cdt=2 ddr=3
- sde (LUN4): rpm_a=1 tz_a=2 hyp_a=3 modem_a=4 bluetooth_a=5 mdtpsecapp_a=6 mdtp_a=7 abl_a=8 dsp_a=9 keymaster_a=10 boot_a=11 cmnlib_a=12 cmnlib64_a=13 devcfg_a=14 qupfw_a=15 vbmeta_a=16 dtbo_a=17 imagefv_a=18 uefisecapp_a=19 featenabler_a=20; *_b = 21..40; devinfo=41 dip=42 apdp=43 spunvm=44 splash=45 limits=46 toolsfv=47 logfs=48 cateloader=49 rawdump=50 logdump=51 storsec=52 multiimgoem=53 multiimgqti=54 uefivarstore=55 secdata=56 catefv=57 catecontentfv=58
- sdf (LUN5): ALIGN_TO_128K_2=1 modemst1=2 modemst2=3 fsg=4 fsc=5
- Sizes: boot 96 MiB, recovery 96 MiB, dtbo 24 MiB, vbmeta 64 KiB, dsp 32 MiB, modem 180 MiB, persist 32 MiB, modemst1/2 and fsg 2 MiB each, devinfo 4 KiB, cdt 128 KiB
- Full list: raw/adb_20261028_232150/by_name.txt, raw/fastboot_20261028_232246/getvar_all.txt

## Display
- 1200x2000 (physically portrait), 60 Hz, density 240, 213×216 dpi; Android defaults to landscape (rotation 1)
- Backlight: I2C 1-0036 → driver **sgm37604a**; panel supply: I2C 1-003e → **tps65132** (±5V bias)
- Panel model: **Himax HX83102P (BOE)**, confirmed by the stock cmdline (see "Additions"). Mainline describes the other revision, NT36523W.

## Input
- I2C 0-0060 and 1-0061: hid-over-i2c (i2c_hid) — the MCU of the Lenovo Keyboard Pack pogo keyboard/touchpad (docs/notes/input_keyboard.md); touch is HX83102E on SPI0 (see «Added»).
- SPI: spi0.0, spi0.1 (4a88000.spi), spi1.0 (4a94000.spi), drivers not read (the device dropped off USB)
- Buttons: Vol+ = pm6125 gpio5, Vol− = PON resin, Power = PON pwrkey (tested in pmOS)

## Power / charging
- PMICs: pm6125 (spmi 0), pmi632 (spmi 2), pm2250 (spmi_dlkm, rouleur audio)
- power_supply: battery, bms, customer, main, mm8013, parallel, pc_port, touchpad, usb
- Fuel gauge: **mm8013** (I2C 0-0055)
- Type-C: **fusb302** (I2C 0-0022); USB-C audio switch **fsa4480** (I2C 1-0042)
- Battery: Li-ion, 100% at the time of the check, 4337 mV

## Audio
- Amplifiers: **aw882xx** ×4 (I2C 0-0034..0037), module aw88258_4pa_dlkm
- Microphone ADC: **es7210** (I2C 1-0040)
- Codec: wcd937x + rouleur (pm2250), bolero (rx/tx/va macro), ADSP/q6 (apr)

## Wi-Fi / BT
- wlan.ko (stock qcacld); Wi-Fi MAC <WIFI_MAC>, BT <BT_MAC> (ro.odm.lenovo.*)
- Per the mainline DTS: ath10k snoc (WCN39xx), calibration-variant "Lenovo_P11"
- A separate bluetooth_a/b partition exists (BT firmware, sde5)

## Sensors (through Qualcomm SSC/SLPI on the ADSP, not directly over I2C)
- Accelerometer + gyroscope: TDK icm4x6xx
- Ambient light: Lite-On ltr578
- Proximity / ToF: ams tmf8801
- SAR: Semtech sx932x (I2C 1-0033 virtualsar)
- In pmOS they work through hexagonrpcd (our patch, 0.4.0-r50) + libssc + iio-sensor-proxy (docs/notes/sensors.md).

## Cameras (stock S120184 + checks in mainline, 2026-11-01)
- Rear OV13B10: CCI0 (`i2c-qcom-cci` 0x5c1b000) 0x10, ID 0x560d42, MCLK0 gpio20 19.2 MHz, reset gpio18, 4 lanes CSIPHY0, 560 MHz.
- VCM DW9763: CCI0 0x0c, ID 0xf9 (registers as on the DW9761), VAF supply.
- Front S5K4H7: CCI1 0x10 (not 0x2d from the CamX module), reg 0x0000 = 0x487b, MCLK2 gpio27 (24 MHz), reset gpio19, CSIPHY2 (4 lanes, 732 Mbps); own driver (patch 0023), captures 3264x2448 at 30 fps through CSID0/TFE0; CSID1/TFE1 hangs the tablet.
- Power: the stock DT refers to a PM8008 (I2C1 0x08/0x09), but it does not answer — the rails come from LDOs: gpio112 VANA 2.8 V, gpio108 VDIG 1.05 V,
  gpio40 VAF 2.8 V; CSIPHY — pm6125 L18 1.2 V. Camera subsystem Spectra 340 (TFE) ×3. Details: notes/camera.md.

## Other I2C
0-004e (no driver), 1-0009 (no driver), 1-000c (i2c_pmic)

## IIO
iio:device0 = pmi632 vadc, iio:device1 = pm6125 vadc

## USB ID (macOS, Android)
18d1:4ee7, bcdDevice 4.19, 480 Mb/s (USB 2.0)

## Additions 2026-10-29 (root + mainline)
- Stock /proc/cmdline: `msm_drm.dsi_display0=qcom,mdss_dsi_himax83102p_boe_2k_video:` → **Himax HX83102P panel (BOE)**; touch **Himax HX83102E zero-flash** on SPI0 (QUP SE2, 4a88000), irq tlmm 86, reset tlmm 54; stylus (himax-pen).
- soc0: soc_id 445, family Snapdragon, machine BENGALP, revision 1.0, hw_platform IDP. ABL: UEFI 5.0.210904.BOOT.XF.4.1-00218-KAMORTALAZ-1, Loader Build Sep 4 2021. UFS: MICRON MT128GASAO4U21 0106.
- Battery (mm8013 in mainline): design 7500 mAh, full 6596 mAh, 328 cycles. Stock QG: CHARGE_FULL_DESIGN 7518000.
- Wi-Fi: WCN3990 (ath10k qmi chip_id 0x150, chip_family 0x4002, board_id 0xff, soc_id 0x40670000), FW WLAN.HL.3.2.4-00564-QCAHLSWMTPLZ-1.
- BT: WCN3990 "cherokee", QCA SOC Version 0x40020150, ROM 0x201, firmware crbtfw21.tlv / crnv21.bin.
- GPU: Adreno610v1 (stock kgsl), FD610 in mainline (Mesa 26.2.5), stock frequencies 320–950 MHz.
- CPU (mainline cpufreq-hw): little up to 1804800 kHz, big up to 2016000 kHz.
- aw882xx amplifiers: reg0 = 0x1852 ×4. ES7210 ADC. LCD bias TPS65132 ±5.7 V. Backlight SGM37604A (I2C1 0x36, en = pmi632 gpio6), DCS 12-bit control.
- super layout: system_a 1415360512 @+0x100000, product_a 2540896256 @+0x54700000, vendor_a 708902912 @+0xebf00000 (ext4), *_b empty.
- dtbo_a: 13 entries, ABL picks [9] "Lenovo P11 WIFI PVT" (msm-id 445/420, board-id 34/3).
