# Power, battery, charging, Type-C

## Facts (root, 2026-10-28)
- PMICs: pm6125 (SPMI sid 0), pmi632 (sid 2/3), pm2250 (rouleur audio codec).
- Battery: Li-ion, **CHARGE_FULL_DESIGN = 7518000 µAh (7518 mAh)**.
- The "battery" power_supply takes voltage and current from **mm8013** (I2C0 0x55, matching 4353 mV / −259 mA); "bms" = Qualcomm QG (pmi632 qpnp-qg, `QG-K` in dmesg).
- Charger: pmi632 qpnp-smb5 (typec port0 lives there too). Parallel charger **smb1355** (power_supply "parallel", model_name smb1355; I2C1 0x0c `qcom,i2c-pmic` with the i2c_pmic driver; I2C1 0x09 without a driver).
- Type-C: in stock the typec class comes from the pmi632 smb5. I2C0 has fusb302 (0x22, driver bound) and rt1711h (0x4e, driver not bound, apparently an alternative SKU), both with irq tlmm gpio 97.
- fsa4480 (I2C1 0x42): USB-C audio switch.
- Vbus for pogo: dock_pogo (usb_vbus gpio 38, charge_enable gpio 74, dock_status gpio 67, usb_charge_status gpio 66, mcu_switch gpio 41, mcu_reset gpio 48).

## Mainline v7.2.3
- mm8013: present (`mitsumi,mm8013`, drivers/power/supply/mm8013.c). Change the stock compatible `qcom,mm8013` to `mitsumi,mm8013`.
- pmi632: pmi632.dtsi exists (typec `qcom,pmi632-typec`, vbus-reg, adc5, adc-tm5, gpio, lpg, vib).
- pmi632 charger: **no driver** (qcom_smbx knows only pm660 and pmi8998) → our own read-only driver, patch 0004 (below). Without a driver charging most likely runs on the hardware defaults (to be checked: current and voltage with USB connected).
- smb1355: no driver.
- fusb302: a driver exists (tcpm/fusb302.c). But in stock typec is handled by the pmi632. Find out what is connected to the CC lines.

## Status (29.10)
- mm8013: works (100%, 4.39 V, 328 cycles); loaded in pmOS through modules-load (device r3+). Patch 0005 (kernel r105): current_now sign per the ABI, link to the charger, Li-ion — UPower/Plasma show charging/discharging correctly.
- Charging runs on the bootloader settings (FCC 3 A, FV 4.40 V); the pmi632 charger driver is read-only (patch 0004, below). CPU thermal throttling is wired up (test 9).

## Thermal in mainline (2026-10-29)
- cpu*-thermal zones: trip 90 °C passive, 95 °C passive, 110 °C critical (shutdown); gpu-thermal: 85 °C passive, 110 °C critical; the others 115/125 °C.
- Cooling devices: only ath10k_thermal and devfreq-5900000.gpu. **No CPU cooling (cpufreq) registered** → Linux does not throttle the CPU by temperature (the hardware LMH/OSM remains). ~~TODO~~ **Done (test 9):** `#cooling-cells` in cpu0–7 and cooling-maps in our DTS, cooling_device cpufreq-cpu0/cpu4.
- Under full load on 8 cores + GPU: 42 → 65 °C in 4 min (the test was stopped by my 65 °C safety limit).
## Charging without a driver (2026-10-29)
- Idle with USB from the Mac: mm8013 current_now −136…−141 mA, charge_now grows (+1 mAh in ~20 s) → charging runs on the pmi632 HW defaults. Under full load the drain is ≈ +160 mA beyond USB.

## PMI632 (SMB5) charger driver, step 1 — read only (2026-10-29)
- Patch `0004-power-supply-add-read-only-Qualcomm-PMI632-charger-driver.patch`: drivers/power/supply/qcom_pmi632_charger.c + Kconfig CHARGER_QCOM_PMI632 + node
  `&spmi_bus { pmic@2 { charger@1000 { compatible = "qcom,pmi632-charger"; reg = <0x1000>; }; }; }`. Registers from Qualcomm's smb5-reg.h / qpnp-smb5.c (smb5_pmi632_params) (GPL-2.0).
- power_supply `pmi632-charger` (USB): ONLINE, STATUS, CHARGE_TYPE, USB_TYPE (APSD), HEALTH, INPUT_CURRENT_LIMIT (ICL_STATUS), CONSTANT_CHARGE_CURRENT/VOLTAGE (FCC/FV cfg). Polled every 5 s.
- Values left by the bootloader (Mac USB port): FCC 0x3c = 3.0 A, FV 0x50 = 4.40 V (= the stock profile), ICL max 1.5 A, ICL actually 950 mA, APSD = SDP, status FULLON/Fast.
- Step 2 (not done): writing the USB ICL for a DCP adapter (up to 3 A), JEITA (1.5 A and 4.2 V at 45–50 °C), step charging, SMB1355 (parallel, I2C1 0x0c).

## Lenovo sources (2026-10-29): github.com/adazem009/kernel_lenovo_tbj606 → `src/kernel_lenovo_tbj606/drivers/power/supply/qcom/`
- `qpnp-smb5.c` (`smb5_pmi632_params`, `PMI632_MAX_ICL_UA 3000000`, JEITA), `smb5-lib.c/.h`, `smb5-reg.h` — the stock charger logic with Lenovo changes
  (for step 2: ICL for DCP/adapter, JEITA, step charging).
- `smb1355-charger.c` — the SMB1355 parallel charger (I2C1 0x0c), a reference for a mainline driver.
- `qg-*.c` — Qualcomm QG (pmi632 fuel gauge) and the battery profile; `mm8013.c` — the Lenovo version (compare with mainline and patch 0005).

## USB-C: OTG and C-to-C charging (2026-10-30, patch 0008)
- The PMI632 Type-C block is in micro-USB mode (0x1570 = 0x03) — CC is handled by the FUSB302B (I2C0 0x22, ID 0x91, INT gpio97). VBUS for devices comes from an external boost on gpio38
  (stock: fusb302 → pogo_psy usb_vbus_ctl), not from the PMI632 OTG. DTS: regulator-fixed usb_otg_vbus (gpio38) → fusb302 vbus-supply; connector dual/dual, try sink, pd-disable.
- OTG: a mouse receiver is detected (hid-generic), the charger is offline meanwhile (no loop).
- Charging: C-to-C charging now starts (Rd from the FUSB302): 5 V / 3 A per Rp, ~+1.36 A into the battery, PMI632 ICL 1.5 A (hardware defaults). PD is disabled.
- Offline charging: when a charger is connected to the powered-off tablet, ABL boots the kernel with androidboot.mode=charger. Since device r8/r11 the initramfs hook
  `20-j606f-charger.sh` handles it (a «Charging: N%» screen, Power ≥2 s — normal boot, charger removed — poweroff; r11 tells a reboot from a charger boot).
  The final poweroff → charger → unplug cycle is not finished; the owner wants to drop the «hold power button to boot» screen and do offline charging differently (later).

## Charger tests (2026-10-31, kernel r118, read-only PMI632 driver)
| Source | Cable | Type-C (FUSB302) | PMI632: APSD type / input limit | Battery current |
|---|---|---|---|---|
| Xiaomi MDY-15-EK (USB-A, 5 V/3 A without a proprietary protocol) | A→C | sink, default | OCP / 1.5 A | +1.05 A (4.15 V) |
| Lenovo wall charger (USB-C) | C→C | sink, Rp 3.0 A | OCP / 1.5 A | +1.36 A (4.20 V) |
| Mac USB port (earlier) | A→C | sink | SDP / ~0.95 A | charges |
| Sony (USB-A), the tester's tablet | A→C | sink, default | OCP / ICL 1.5 A, but AICL lowered the input to 0.55 A | 0 (3.73 V, screen on) |
| Power bank, the tester's tablet | A→C | sink, default | DCP / 1.5 A, AICL 1.5 A | +1.02 A (3.81 V) |
- The bootloader leaves: HVDCP (QC) enabled (0x1362 = 0x0c), input in USB51 mode without HC (0x1366 = 0x02), ICL 1.5 A (0x1370 = 0x1e),
  FCC 3 A, FV 4.40 V.
- The Sony "wall" charger on the tester's tablet (snapshots raw/charger/tester-sony.txt, tester-powerbank.txt, one boot, 17:41/17:42):
  APSD detected it the same way as our chargers (OCP, 0x1308 = 0x02), the input limit of 1.5 A is set (0x1106 = 0x1e), but the hardware
  AICL lowered the actual limit to 550 mA (0x1107 = 0x0b, INPUT_CURRENT_LIMIT 550000): under load the USBIN voltage drops
  below the AICL threshold — the charger or cable cannot deliver that much. 5 V × 0.55 A ≈ 2.7 W all go to the system with the screen on,
  battery current 0. Power bank: DCP (0x1308 = 0x08), AICL holds 1.5 A, +1.02 A. The DCP/HVDCP hypothesis is wrong; it cannot be fixed in software (without
  writing the AICL threshold, which should not be done). To check: another cable with this charger, the rating on its case, the current with
  the screen off.
- Headroom: with Rp 3.0 A (the Lenovo charger) the input limit stays at 1.5 A — set the ICL from the driver by Rp/APSD (step 2).
- State snapshot: power_supply, /sys/class/typec, /sys/kernel/debug/usb/tcpm-0-0022 and the PMI632 registers
  `grep -E "^1[0-6][0-9a-f]{2}:" /sys/kernel/debug/regmap/0-02/registers`.
