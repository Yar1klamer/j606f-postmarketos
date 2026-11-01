# Display

## Facts from the device (2026-10-28, root)
- /proc/cmdline: `msm_drm.dsi_display0=qcom,mdss_dsi_himax83102p_boe_2k_video:` → **Himax HX83102P panel (BOE, 2K), video mode**.
- The stock DT describes both panels: `qcom,mdss_dsi_himax83102p_boe_2k_video` (selected, qcom,dsi-default-panel = <0x3F4>) and `qcom,mdss_dsi_nt36523w_boe_2k_video`. ABL selects the SKU through the cmdline.
- **The mainline DTS sm6115p-lenovo-j606f.dts describes only NT36523W (lenovo,j606f-boe-nt36523w).** That does NOT fit our unit. An HX83102P DTS variant is needed.
- Stock panel node: stock_dt/panel_hx83102p_boe.dtsi. Decoded on-command (50 DSI packets): stock_dt/panel_hx83102p_on_cmds.txt.
- Key parameters:
  - 1200x2000, 24 bpp, 4 lanes (lane_map_0123), burst mode, video mode, 60 Hz
  - HFP 60, HBP 49, HSW 8; VFP 80, VBP 38, VSW 8 → htotal 1317, vtotal 2126, pixel clock ≈ 168.0 MHz (the stock DRM mode "1200x2000x60x167996vid" confirms it)
  - physical size 143 x 235 mm
  - qcom,mdss-dsi-panel-orientation = "180" (as in mainline for NT36523W: mounted upside down)
  - reset: tlmm gpio 82 (0x52), sequence <1 10ms, 0 10ms, 1 60ms>, `qcom,platform-reset-gpio-always-on`
  - `qcom,mdss-dsi-lp11-init`, `tx-eot-append`, t-clk-post 0x14, t-clk-pre 0x50
  - backlight: `bl_ctrl_dcs`, range 1..4095 (12 bits, DCS 0x51 with two bytes); the on-command has `51 00 00`, `53 2c`
  - ESD check: reading registers 0x09, 0x0A, 0x45
  - off: `28` (display off), `10` (sleep in, 60 ms); pre-off `53 24`; post-off `b9 83 10 2e`, `b1 21` (apparently deep standby)
- vddio: pm6125_l9 (1.8 V), as in mainline. DSI vdda: pm6125_l18 1.232 V.
- ±5.4 V supply: tps65132 on I2C1 0x3e, ENP = tlmm gpio 111 (0x6F), ENN = tlmm gpio 44 (0x2C). The lcdb_ldo/lcdb_ncp regulators (pmi632) are not used in stock (use_count 0).
- TE: gpio81 mdp_vsync in the mainline DTS (not required for video mode).

## Mainline
- The sm61x5 v7.2.3 kernel has drivers/gpu/drm/panel/panel-himax-hx83102.c (compatible: boe,nv110wum-l60, csot,pna957qt1-1, holitech,htf065h045, ivo,t109nw41, kingdisplay,kd110n11-51ie, starry,2082109qfh040022-50e, starry,himax83102-j02, waveshare,12.3-dsi-touch-a). Our panel is not there.
- Plan: add a "lenovo,j606f-boe-hx83102p" description to panel-himax-hx83102.c with the init sequence from stock_dt/panel_hx83102p_on_cmds.txt and the timings above. Alternative: generate a separate driver with linux-mdss-dsi-panel-driver-generator (lmdpdg) from the stock DT.
- The panel is not needed for the first boot: the simple-framebuffer left by ABL works (address in the mainline DTS 0x5c000000, 1200x2000, stride 4800). To be checked: the stock splash buffer address must match (cont_splash in the stock DT).

## Status
**Works** (29.10): picture and brightness confirmed by the owner, 60 Hz, weston/kmscube. In the installed pmOS: DSI-1 connected. Results below.

## TPS65132 (I2C1 0x3e) in stock, toybox i2cdump -fy 1 0x3e
`00: 11 11 00 03` → VPOS = VNEG = 0x11 → 4.0 V + 17×0.1 V = **±5.7 V**, reg 0x03 = 0x03 (active discharge on both outputs).
The DTS should set regulator-min/max-microvolt = 5700000 for outp/outn (in case the EEPROM value differs after a cold start).

## ★ Mainline results (2026-10-29, test 5)
- msm DRM + our panel driver: DSI-1 connected/enabled/dpms On, mode 1200x2000@60 (clock 167996). No errors when the panel is enabled.
- Backlight: DCS, /sys/class/backlight/5e94000.dsi.0, 0..4095, writing works. Reading DCS 0x52 → "msm_dsi_host_cmd_rx:Invalid response cmd" (this panel has no 0x52). TODO: drop .get_brightness for this panel.
- DSI clocks: VCO 2015.952 MHz, pclk 167.996, byte 125.997 MHz (4 lanes × 1008 Mbps).
- INTF1 timing engine (devmem through python mmap, 0x05e6b800 = MDP 0x5e01000 + 0x6a800): TG_EN=1, FRAME_COUNT +30 in 0.5 s (**exactly 60 Hz**), HSYNC_CTL=0x05250008 (htotal 1317, pulse 8), VSYNC_PERIOD_F0=2799942 (=1317×2126). **The video stream is generated.**
- ~~PROBLEM: vsync IRQ~~ **RESOLVED in understanding (test 7):** at first I mixed up the registers. In the legacy DPU (≤6.x, dpu_hwio.h) INTR_EN = +0x010, INTR_STATUS = +0x014, INTR_CLEAR = +0x018. In fact: EN (0x5e01010) = 0 when idle, STATUS (0x5e01014) = 0x08000100 (bits 27 vsync and 8 PP0_DONE are latched and not serviced while disabled). This is normal, vblank is enabled on demand.
  During `modetest -v`: OR(EN) = 0x08000000 (vsync enabled), and drm.debug shows "updating vblank count … diff=1" every ~16.9 ms, i.e. **the vblank IRQ works at 60 Hz**.
  ~~A real problem remains: page flips complete slowly~~ **NO PROBLEM (test 8):** it was an artefact: modetest -v exits at once without an open stdin. With `sleep | modetest -v` it reports freq 60.0 Hz, kmscube gives 59.99 fps. The old text is kept for history: (modetest -v prints no freq line in 12 s, i.e. fewer than 60 flips; kmscube -c 120 does not finish in 20 s). The cause seemed to be in the commit/flip path (waiting for ctl start / frame done?), not in the IRQ. Setting bit 27 in EN by hand is cleared by the driver at once (no callback). Deep cpuidle is not involved (disabling state1 changed nothing).
  Next steps: drm.debug=0x1ff (+ msm DPU_DEBUG) during a flip with full logs; check INTR2 (ctl_0 intr_start = TOP0_INTR2 bit 9: EN2 +0x008, STATUS2 +0x00c) — whether the commit waits for "ctl start"; try weston/kmscube with atomic and look at the real fps; compare with other SM6115 devices in mainline.
- Visual check: a test chart is left on the screen (8 bars + frame + "J606F OK"). Waiting for the owner's eyes.
