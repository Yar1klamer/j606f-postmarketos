# Buttons, Hall sensor, keyboard (pogo)

- qpnp_pon (pm6125): Power + Vol− (resin), event0. In mainline: pon_pwrkey and pon_resin are in the DTS.
- gpio-keys: Vol+ = pm6125 gpio5, active low. Present in mainline.
- hall-switch-input: tlmm gpio 36 (0x24), cover or case. Not described in mainline; can be gpio-keys with EV_SW SW_LID.
- "keyboard waker" (SW) and dock_pogo: the GPIOs are described in power.md.
- Lenovo Keyboard Pack keyboard and touchpad: hid-over-i2c `mcu_pogo@60` (I2C0, irq gpio 93) and `mcu_pogo@61` (I2C1, irq gpio 96), hid-descr-addr 0x1, post-power-on-delay 100 ms. In mainline this is the standard i2c-hid-of. The MCU power and reset are also needed (mcu_switch gpio 41, mcu_reset gpio 48, charge_enable gpio 74).
- Vibration motor: pmi632 vibrator@5700 (`qcom,pmi632-vib` exists in mainline).
- RGB LED: pmi632 lpg (`qcom,pmi632-lpg` exists). Flash: pmi632 flash@d300.

## Mainline (2026-10-29, test 8)
- `i2cget -y 0 0x60` → 0x00, `i2cget -y 1 0x61` → 0x00: the devices ANSWER (ACK). The pogo MCU inside the tablet is alive even without the keyboard.
- GPIO (mainline, debugfs): gpio38 (usb_vbus) in low; gpio41 (mcu_switch) in low pull-down; gpio48 (mcu_reset) in high; gpio66 (usb_charge_status) low; gpio67 (dock_status) low → the keyboard is probably not docked; gpio74 (charge_enable) low.
- Next step: `hid-over-i2c` nodes (i2c0@0x60 irq tlmm 93, i2c1@0x61 irq tlmm 96, hid-descr-addr 0x1, post-power-on-delay-ms 100) + a test with the keyboard docked (needs the owner and the keyboard itself).

## Status in pmOS (29.10)
- Power, Vol+, Vol− work (volume checked by the owner). Power turns the screen off/on: PowerDevil `PowerButtonAction=128` (local setting, STATE §2).
- On-screen keyboard: plasma-keyboard (KWin InputMethod, EN/RU) — a local setting, not moved into the device package.
- **Pogo dock (Lenovo Keyboard Pack)** — the `hid-over-i2c` nodes were contributed by kruzeman (PR #1, 06.11, tested on their tablet on r121):
  I2C0 0x60 — Elan touchpad 04f3:3164 (hid-multitouch), I2C1 0x61 — Lenovo keyboard 17ef:6103; IRQ gpio93/gpio96 `LEVEL_LOW`,
  pinctrl as in stock (`bias-disable`, `input-enable`). Kernel: patch 0025 (author kruzeman, nodes moved into the existing i2c0/i2c1/tlmm blocks),
  linux-lenovo-j606f **r122** (`CONFIG_I2C_HID_OF=m`, `HID_MULTITOUCH=m` were already set). dmesg markers:
  `input: hid-over-i2c 04F3:3164 Touchpad …/i2c-0/0-0060`, `input: hid-over-i2c 17EF:6103 Keyboard …/i2c-1/1-0061`.
- `dock_status` (gpio67) stays low even with a working keyboard attached — it is not a docking signal.
- Hall (SW_LID), vibration motor, RGB LED, flash — not described in the DTS, not tested.
