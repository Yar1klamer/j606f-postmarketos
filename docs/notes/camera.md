# Cameras

## Hardware (stock DT S120184 + CamX modules from the stock vendor)
| | Rear | Front |
|---|---|---|
| Sensor | OV13B10 (two modules: `ov13b10`, `ov13b10_qt`) | **S5K4H7** (`s5k4h7_lcetron`) — confirmed by ID; stock also has an OV8856 module (`ov8856_kc`), not fitted on our unit |
| CCI | master 0, 0x10 (8-bit 0x20) | master 1, **0x10** (the S5K4H7 module lists 0x2d/0x5a — does not answer) |
| ID | 0x300a = 0x560d42 (driver, read) | 0x0000 = 0x487b (read); 0x300a = 54 03 5c |
| CSIPHY | 0, 4 lanes (lane count from the driver, not decoded from the .bin) | 2, 4 lanes (laneAssign 0x3210), 732 Mbps per lane |
| MCLK | MCLK0 gpio20, 19.2 MHz | MCLK2 gpio27, **24 MHz** (EXCK 0x1800 in the CamX module; 19.2 in the stock DT) |
| reset | gpio18 | gpio19 |
| vio / vana / vdig / vaf | PM8008 per the stock DT; in reality: vio is not switched, vana gpio112 2.8 V, vdig gpio108 1.05 V, vaf gpio40 2.8 V (shared) | the same |
| Other | VCM DW9763 (`dw9763m11`) — CCI0 **0x0c**, ID 0xf9, VAF supply; EEPROM; PMI632 flash (flash_0/1) | EEPROM |
| sensor-position-roll | 90 | 270 |

- Power: the stock DT refers to a PM8008 (I2C1 0x08/0x09, reset gpio26, irq gpio25), but nothing answers at I2C1 0x08/0x09
  and stock binds no driver to it — the PM8008 is not fitted. The rails are external LDOs: gpio112 (CAM_VANA 2.8 V), gpio108 (CAM_VDIG 1.05 V),
  gpio40 (CAM_VAF 2.8 V), raised by the stock power sequence; in the DT — regulator-fixed.
- CCI v1.2 0x5c1b000, IRQ 206, 37.5 MHz; pins CCI0 gpio22/23, CCI1 gpio29/30.
- The camera subsystem is a Spectra 340 "TFE", as on QCM2290 (agatti), but with 3 of each block: CSIPHY 0x5c52000/53000/54000 (IRQ 72/73/74),
  CSID 0x5c6e000/75000/7c000 (IRQ 210/212/77), TFE +0x1000 (IRQ 211/213/78), TPG 0x5c66000/68000. SMMU streams 0x400/0x800/0x820/0x840.
- CSIPHY supply (stock mipi-csi-vdd) — pm6125 L18 1.2 V.

## Mainline 7.2.3
- CAMSS: QCM2290 is there (csid-340, vfe-340), SM6115 is not → patch 0017 (tables for 3 PHY/CSID/TFE, compatible `qcom,sm6115-camss`).
- CCI: `i2c-qcom-cci`, compatible with `qcom,msm8996-cci`.
- OV13B10: the driver has only an ACPI table → patch 0018 (OF match; power/clk/reset already go through the generic APIs).
- S5K4H7: no driver (mainline and linux-media, searched 2026-11-01) → own driver, patch 0023 (registers from the CamX module `s5k4h7_lcetron.bin`). OV8856: a driver exists (in case of the other module).
- VCM DW9763: the dw9719 driver (DW9761-compatible) + patch 0022 (ID 0xf9). PMI632 flash: leds-qcom-flash does not fit (old type).
- Upstream: no SM6115 CAMSS patches found (searched 2026-10-31).

## Patches (src/patches, kernel r119–r121)
- 0017 media: qcom: camss: add SM6115 support
- 0018 media: i2c: ov13b10: add OF match table
- 0019 arm64: dts: qcom: sm6115: add CCI and CAMSS
- 0020 arm64: dts: qcom: sm6115p-lenovo-j606f: add cameras (sm6115p-lenovo-j606f-camera.dtsi)
- 0020: GPIO regulators, rear OV13B10, front `samsung,s5k4h7` disabled and outside the CAMSS graph (otherwise the graph does not complete).
- 0021 media: i2c: ov13b10: add get_selection (native 4240x3144, active (15,17) 4208x3120, crop per mode).
- 0022 media: i2c: dw9719: add DW9763 (+ power off on an unknown ID).
- 0023 media: i2c: add Samsung S5K4H7 sensor driver (driver + binding `samsung,s5k4h7.yaml`).
- 0024 arm64: dts: qcom: sm6115p-lenovo-j606f: enable the front camera (CCI1 0x10 → CSIPHY2, 4 lanes, link-frequency 366 MHz, MCLK2 24 MHz).
- Config: I2C_QCOM_CCI, VIDEO_OV13B10, VIDEO_OV8856, VIDEO_DW9719, V4L2_CCI(_I2C) = m (PM8008 removed). Kernel r120; r121 + VIDEO_S5K4H7=m.
- libcamera (pmaports temp/libcamera): r5 — 0007 helper + ov13b10 properties (gain 0x80 = 1x, black 4096, 1.12 µm);
  r6 — 0008 helper + s5k4h7 properties (gain 0x20 = 1x, black 4096, 1.12 µm, test patterns 0–4).
- r121 and libcamera r6 are committed but **not built yet** and not tested as packages (the front camera was tested with a test module and DTB).
- Working tree: src/work-cam (git worktree of linux-sm61x5-full at 5a88d98 + 0001, 0003–0016 as one commit).

## Tested (2026-11-01, r119 + test DTBs through fastboot boot)
- CAMSS, CCI, OV13B10: graph ov13b10 2-0010 → csiphy0 → csid0 → vfe0_rdi0 → /dev/video0.
- RAW capture: `media-ctl -l '"msm_csiphy0":1->"msm_csid0":0[1],"msm_csid0":1->"msm_vfe0_rdi0":0[1]'`,
  `media-ctl -V` SGRBG10_1X10/2104x1560 along the chain, `v4l2-ctl -d /dev/video0 --set-fmt-video=width=2104,height=1560,pixelformat=pgAA --stream-mmap`.
  Frame 4105920 bytes (stride 2632). test_pattern=1 — correct bars, GRBG Bayer.
- A real scene in daylight — tested: a recognisable picture (exposure 1590, analogue_gain 512), blurry — VCM without a driver.
- libcamera 0.7.2 (`cam` from libcamera-tools): "Internal back camera", simple + software ISP with the GPU debayer (EGL, the default):
  RGB 2104x1560 — 27.6 fps, 1280x720 — 117 fps (mode 1364x768 120 fps). The early ~7.5 fps came from the debug log and the long exposure in the dark.
  No ov13b10 CameraSensorHelper (AGC without gain), no sensor properties; the driver had no get_selection (crop).
- Front: the ID was read with test DTB v5 (rails always-on, MCLK2 on the CCI node, gpioset gpio19=1, `i2ctransfer -y 3 w2@0x10 0x00 0x00 r2`).

## Front S5K4H7 (2026-11-01, r120 + test module and DTB through fastboot boot)
- Parameters from the CamX module ("Parameter Parser V2.0.0" format: a symbol table + value arrays by id):
  a single 3264x2448 RAW10 mode, line length 3580, frame length 2530, 30.03 fps; VT PLL 24/6×136 → pixel rate 272 MHz,
  OP PLL 6×183 → 732 Mbps per lane (link frequency 366 MHz); exposure 0x0202 (min 4, margin 4), gain 0x0204
  (0x20 = 1x … 16x), 0x0340 frame length, 0x0101 orientation, 0x0600 test pattern (1 solid colour, 2 bars, 3 bars fading
  to grey, 4 PN9); black 64; array 3280x2464, active (8,8) 3264x2448; power-up: reset 0 → rails → 5 ms → MCLK → 1 ms → reset 1 → 12 ms.
- Graph: `s5k4h7 3-0010` → msm_csiphy2. RAW capture: `media-ctl -l '"msm_csiphy2":1->"msm_csid0":0[1],"msm_csid0":1->"msm_vfe0_rdi0":0[1]'`,
  SGRBG10_1X10/3264x2448 along the chain, `v4l2-ctl -d /dev/video0 --set-fmt-video=width=3264,height=2448,pixelformat=pgAA` (stride 4080).
  test_pattern=2 — correct bars (white … black), **GRBG** Bayer with flip 0/0, black 64. A real frame is sharp.
- libcamera: "Internal front camera", `cam -c 2` 1632x1224 — 30.03 fps; the simple pipeline picks csid0 → vfe0_rdi0 by itself.
- ⚠️ The **csiphy2 → csid1 → vfe1_rdi0** path hangs the tablet hard when streaming starts (no USB, no network; hours later
  the watchdog → the Qualcomm CrashDump screen, exit with a long press of Power). The CSID1/TFE1 addresses, IRQs, clocks and SMMU
  match the stock DT; the cause is not found. The rear camera also works through CSID0 — do not enable CSID1/TFE1 by hand.

## Next
1. Rear: ✅ crop, ✅ AGC in libcamera, ✅ manual focus (DW9763: sharpness 0 → 286, 450 → 907, 900+ → 79).
   Open: the soft IPA has no autofocus; orientation/rotation;
   sensor delays and ov13b10.yaml tuning; PMI632 flash.
2. Front: ✅ driver and DT (0023–0024), ✅ libcamera helper (0008). Open: build and test r121/libcamera r6,
   a 2x2 binned mode (1632x1224), sensor delays, s5k4h7.yaml/colour, the CSID1/TFE1 hang.
3. VCM DW9763, PMI632 flash.
