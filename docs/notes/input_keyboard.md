# Кнопки, датчик Холла, клавиатура (pogo)

- qpnp_pon (pm6125): Power + Vol− (resin), event0. В mainline: pon_pwrkey и pon_resin есть в DTS.
- gpio-keys: Vol+ = pm6125 gpio5, active low. В mainline есть.
- hall-switch-input: tlmm gpio 36 (0x24), обложка или чехол. В mainline не описано; можно gpio-keys с EV_SW SW_LID.
- «keyboard waker» (SW) и dock_pogo: GPIO описаны в power.md.
- Клавиатура и тачпад Lenovo Keyboard Pack: hid-over-i2c `mcu_pogo@60` (I2C0, irq gpio 93) и `mcu_pogo@61` (I2C1, irq gpio 96), hid-descr-addr 0x1, post-power-on-delay 100 мс. В mainline это штатный i2c-hid-of. Нужно ещё питание и сброс MCU (mcu_switch gpio 41, mcu_reset gpio 48, charge_enable gpio 74).
- Вибромотор: pmi632 vibrator@5700 (`qcom,pmi632-vib` есть в mainline).
- RGB-светодиод: pmi632 lpg (`qcom,pmi632-lpg` есть). Вспышка pmi632 flash@d300.

## Mainline (2026-10-29, тест 8)
- `i2cget -y 0 0x60` → 0x00, `i2cget -y 1 0x61` → 0x00: устройства ОТВЕЧАЮТ (ACK). Pogo-MCU внутри планшета живой даже без клавиатуры.
- GPIO (mainline, debugfs): gpio38 (usb_vbus) in low; gpio41 (mcu_switch) in low pull-down; gpio48 (mcu_reset) in high; gpio66 (usb_charge_status) low; gpio67 (dock_status) low → клавиатура, вероятно, не пристыкована; gpio74 (charge_enable) low.
- Следующий шаг: узлы `hid-over-i2c` (i2c0@0x60 irq tlmm 93, i2c1@0x61 irq tlmm 96, hid-descr-addr 0x1, post-power-on-delay-ms 100) + проверка с пристыкованной клавиатурой (нужен пользователь и сама клавиатура).

## Статус в pmOS (29.10, пого — 06.11)
- Power, Vol+, Vol− работают (громкость проверил владелец). Power гасит/включает экран: PowerDevil `PowerButtonAction=128` (локальная настройка, STATE §2).
- Экранная клавиатура: plasma-keyboard (KWin InputMethod, EN/RU) — локальная настройка, в device-пакет не перенесена.
- **Пого-док (Lenovo Keyboard Pack) работает** с 06.11: клавиатура и тачпад. Узлы `hid-over-i2c` (`0x60` на I2C0, `0x61` на I2C1) и pinctrl-состояния для `gpio93`/`gpio96` добавлены в `kernel/dts/sm6115p-lenovo-j606f-common.dtsi`, отдельных проприетарных прошивок не требуется. Признаки в `dmesg`:
  ```
  input: hid-over-i2c 04F3:3164 Touchpad as .../i2c-0/0-0060/...  (hid-multitouch, Mouse + Touchpad)
  input: hid-over-i2c 17EF:6103 Keyboard as .../i2c-1/1-0061/...   (модификаторы + Consumer)
  ```
  IRQ — `LEVEL_LOW`; `EDGE_FALLING` не понадобился. В `gpioinfo`: 93/96 в покое high.
- **`dock_status` (gpio67) не является признаком пристёгнутой клавиатуры**: остаётся low и при работающих клавиатуре/тачпаде. Ничего на него завязывать нельзя.
- Hall (SW_LID), вибромотор, RGB-светодиод, вспышка — в DTS не описаны, не проверялись.
