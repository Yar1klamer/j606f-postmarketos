# Audio

## Facts
- Stock card: bengal-idp-snd-card (q6 ADSP, APR).
- Digital part: bolero (rx/tx/va macro), codec wcd937x + rouleur (PM2250 analog, "pm2250_spmi_dlkm"), mbhc (a headset exists: Headset Jack, Button Jack, input event6/7).
- Speakers: 4 **Awinic aw882xx** amplifiers (I2C0 0x34–0x37), module aw88258_4pa (stock `awinic,aw882xx_smartpa`), calibration files /vendor/firmware/awinic/aw882xx_acf.bin, aw882xx_monitor.bin.
- Microphones: **ES7210** ADC (I2C1 0x40). Plus a DSPG DBMD8 on SPI1 (voice activation).
- USB-C audio: fsa4480.

## Mainline v7.2.3
- wcd937x.c and pm4125.c (rouleur = the PM4125/PM2250 codec) exist; the lpass macros for sm6115 exist (lpasscc-sm6115, lpass-lpi pinctrl sm6115).
- aw88xxx: aw88081, aw88166, aw88261, aw88395, aw88399. **No aw88258**; the closest candidate is to be checked by the ID register.
- es7210: **not** in the kernel.
- Machine driver: sound/soc/qcom/sm8250.c (also used for smaller SoCs). UCM is needed.
- High complexity, P1.

## Amplifier ID
/sys/bus/i2c/devices/0-003{4..7}/reg (sysfs of the stock aw882xx driver): reg 0x00 = **0x1852** on all four. Dumps: raw/root_20261028/aw882xx_0-003*.reg.txt. Which mainline driver matches ID 0x1852 is not checked yet.
- Checked against mainline v7.2.3: CHIP_ID aw88261 0x2113, aw88399 0x2183, aw88395 0x2049, aw88166 0x2066, aw88081 0x2116, aw88083 0x2407. **0x1852 (AW88258) is in no driver** → a new driver or an adaptation is needed (probably closest to aw88395/aw88261: the same "acf" firmware).
- The ADSP starts with the stock firmware (test 8). The audio path by the stock dtbo labels: speakers through LPASS LPI TDM1 (lpi_tdm1_*) → aw882xx; i2s2 (lpi_i2s2_*); codec rouleur (PM2250 → mainline pm4125) + wcd937x; mbhc.

## Assessment (29.10, night) — what can realistically be done
- Headphone jack + headset microphone: mainline has everything (LPASS APR/q6 in sm6115.dtsi, lpass-lpi pinctrl, rx/tx/va macro with sm6115, pm4125, wcd937x,
  the sm8250.c machine driver with `qcom,qrb4210-rb2-sndcard`). Needed: DTS (macros, SoundWire, codec, sound card) + UCM. Headphones are needed.
- AW88258 speakers: no driver; without the correct amplifier initialisation there is a risk of damaging the speakers → only from the Awinic GPL sources.
- ES7210 built-in microphones: no driver. USB-C audio (fsa4480): not started.

## ★ GPL sources (2026-10-29): github.com/adazem009/kernel_lenovo_tbj606 → `src/kernel_lenovo_tbj606/`
- `techpack/audio/asoc/codecs/aw88258_4pa/` (Awinic 2020, GPL-2.0+): the **AW88258** driver, `AW882XX_ID = 0x1852` (= our ID), register map `aw882xx_reg.h`,
  the "acf" firmware loader (`aw_device.c`: header check, register and DSP profiles), calibration, the monitor (temperature/voltage → gain reduction).
  This removes the main risk: the amplifier initialisation comes from the stock driver + the stock aw882xx_acf.bin/aw882xx_monitor.bin, not blindly.
  Path for mainline: a new ASoC codec `aw88258` modelled on sound/soc/codecs/aw88395 (the same acf format) with the registers from aw882xx_reg.h.
- `sound/soc/codecs/es7210.c` (Everest 2014, GPL-2.0): 415 lines, the full init sequence (PGA +3 dB, SCLK/LRCK = 64, TDM).
  In stock it is controlled by the "ES7210_Switch" kcontrol in the machine driver (es7210_start/stop). Mainline needs a proper ASoC codec (a small one).
- `techpack/audio/asoc/bengal.c` (the Lenovo machine driver): TDM defaults to 48 kHz S16_LE, slots through `snd_soc_dai_set_tdm_slot` (slot_offset 0,4,8…28) —
  the TDM parameters for the amplifiers and the ES7210 come from here.
- The order stays: headphone jack (PM4125/WCD937x) → AW88258 speakers (driver port) → ES7210.

## 2026-10-31 — development starts: headphone jack (wcd937x)
The stock (stock_live_S120184.dts) refines the 29.10 assessment: the analog codec is **wcd937x** (a split codec on SoundWire), not rouleur/PM4125:
- RX slave on the SoundWire rx-macro (swr master 2, `0xa610000`, IRQ 297), TX slave on the SoundWire va-macro (master 3, `0xa740000`, IRQ 296 + wake 79);
- reset **GPIO92** (GPIO82 on the RB2), supplies: vdd-rxtx/vddpx = **pm6125_l9** (1.8 V), vdd-buck = **pm6125_l14** (1.8 V), micbias 1/2/3 = 1.8 V;
- stock sound card: bengal-asoc-snd, headset through mbhc (`qcom,msm-mbhc-gnd-swh = 1`, hphl-swh 0), USB-C audio through fsa4480.
Mainline 7.2.3: the ADSP (our stock firmware) already has APR services 3/4/7/8 (core, AFE, ASM, ADM). The kernel has the compatibles
`qcom,sm6115-lpass-{rx,tx,va}-macro`, `qcom,wcd9370/9375-codec` (the variant is detected by CHIPID), `qcom,soundwire-v1.6.0`, lpasscc/lpassaudiocc sm6115
and the sm8250.c machine driver with `qcom,qrb4210-rb2-sndcard`. Neither we nor upstream have LPASS macro and SoundWire nodes in sm6115.dtsi:
Alexey Klimov's series "qrb4210-rb2: add wsa audio playback and capture support" v3 (2025-05-22, patchwork series 965505) is not merged.
Downloaded to `src/audio/upstream-rb2-v3/`; the addresses and IRQs of its nodes (07) match stock. The package config has SND_SOC_QDSP6, SM8250,
LPASS_{RX,TX,VA}_MACRO, WCD937X_SDW disabled.

Plan:
1. kernel: LPASS nodes (patch 07 of the series) + in j606f-common: wcd937x (GPIO92, L9/L14), swr0/swr1, the sound card (MM1 → RX_CODEC_DMA_RX_0 →
   rxmacro/swr1/wcd937x HPH; TX_CODEC_DMA_TX_3 ← txmacro/swr0/wcd937x ADC2 for the headset microphone); config — these options =m;
2. test without writing boot_b: modules from tdev for the running r115 in /lib/modules/…/extra, a new DTB through kexec with the old Image
   (on a hang a normal power-on returns the previous boot_b);
3. checks without ears: wcd937x enumeration on SoundWire, the card in /proc/asound, the DAPM path to HPHL/HPHR, aplay without errors;
   listening and headset detection — the owner, when near the tablet;
4. UCM (HiFi: Headphones/Headset), kernel package r116;
5. then: AW88258 speakers (driver port from the Lenovo GPL sources, TDM through LPASS LPI) and ES7210.

### 2026-10-31: WCD937x bring-up result (details in LOG.md)
- Works with the order: macros → snd-soc-wcd937x → soundwire-qcom: both slaves Attached, the sm4250 card "Lenovo-TB-J606F",
  playback hw:0,0 and capture hw:0,1 (TX SMIC MUX0 = SWR_MIC1, ADC2 INP2) without errors.
- If the bus starts before the codec: clock stop without slaves, resume does not bring the frames up (FRM_GEN=0) → a soundwire-qcom patch is needed.
- **There is no 3.5 mm jack.** The WCD937x HPH/ADC2 are routed to USB-C through the FSA4480 (i2c-1, 0x42, ID 0x09). Analog USB-C audio
  will need fcs,fsa4480 + mode/orientation-switch from Type-C (typec@22 on i2c-0) and accessory mode.
- The priority changes: first the AW88258 speakers (TDM on LPI), then the ES7210 (built-in microphones), USB-C analog afterwards.

### 2026-10-31: AW88258 speakers (details in LOG.md)
- TDM: PRI_TDM_RX_0, LPI gpio6–9 (i2s1_*), 4 slots × 32 bits, 48 kHz, DSP master, invert-sync, channel N → amplifier 0x34+N (per the acf).
- The acf is in the old format (0x0a15f908): parsed in aw88258.c; registers 0x06/0x07 set each amplifier's channel/slot.
- Driver: src/audio/aw88258/aw88258.c; sm8250 TDM: src/patches/0014; DT: audio.dtsi.
- Without SKT protection (ADSP): keep the attenuation; add the monitor from aw882xx_monitor.bin before packaging.
- Test on the tester's tablet 2026-10-31: all 4 speakers play. Channels 1..4 = bottom left, bottom right, top left, top right.

### 2026-10-31: audio in packages (r116, details in LOG.md)
- Kernel r116: 0012 LPASS (patchwork), 0013 aw88258 driver, 0014 sm8250 TDM (stereo in slots 0/1 of 4), 0015 soundwire-qcom
  (re-initialisation if there are no frames after clock stop), 0016 dts audio. Config: QDSP6, SM8250, LPASS macros, WCD937X_SDW, AW88258.
- Stereo: L → SpkBL (0x34) + SpkTL (0x36), R → SpkBR (0x35) + SpkTR (0x37). The top amplifiers were moved from slots 2/3 to 0/1
  with `awinic,rx-slot-mask = <0x3>`.
- Amplifier volume: ceiling -6 dB (control 0..168), UCM sets 168, the rest is in software. The VBAT/temperature monitor per the stock
  tables: BST_IPEAK and attenuation (the latter not deeper than the ceiling — in practice it never triggers).
- UCM: conf.d/sm4250/Lenovo-TB-J606F.conf → Lenovo/TB-J606F/HiFi.conf (src/audio/ucm), Speaker only.
- acf: the device package extracts it from vendor (firmware-extract); here — the personal firmware 1-r3; the shared 0.320208 set does not have it yet.
- No acf → the driver defers the probe (EPROBE_DEFER); after adding the file firmware-extract rebinds one amplifier.
- CORRECTION 2026-10-31 (listening to one amplifier at a time on our tablet): 0x36 — top right, 0x37 — top left.
  Stereo: L → 0x34 (BL) + 0x37 (TL), R → 0x35 (BR) + 0x36 (TR); the top ones get their channel through awinic,rx-channel (r117).
- The system audio backend is PulseAudio (not PipeWire): check `pactl list short sinks` → HiFi__Speaker__sink.
