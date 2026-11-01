# Backlight

## Facts
- Control in stock: **DCS** (`qcom,mdss-dsi-bl-pmic-control-type = "bl_ctrl_dcs"`), levels 1..4095. dmesg shows `dsi_panel_set_backlight ... type:2 lvl:1654`.
- /sys/class/backlight/panel0-backlight max=255 (stock Android scales 0..255 → 0..4095).
- LED driver: **SGM37604A** on I2C1 0x36, stock compatible `sgm,sgm37604a`, enable = **pmi632 gpio6** (`qcom,platform-bklight-en-gpio = <&pmi632_gpios 6 0>`).
- How it works: the panel TCON receives 0x51 over DSI and outputs PWM to the SGM37604A. The SGM37604A must be enabled (gpio) and possibly configured over I2C (current, PWM mode). What the stock driver writes is unknown: the sources or a register dump are needed.

## Mainline
- v7.2.3 has no sgm37604a driver (only sgm3140 flash and the sgm3804 regulator).
- Plan: (1) brightness through DCS in the panel driver (backlight_device from mipi_dsi_dcs_set_display_brightness_large); (2) enable pmi632 gpio6 (gpio-hog or regulator-fixed/enable). If the SGM37604A does not light up after reset without configuration, dump its registers in stock with i2cdump (root) and write a minimal driver or init sequence.

## TODO
- In stock as root: `i2cdump -y 1 0x36` (if Android has i2c-tools) or read through debugfs.

## SGM37604A registers in stock (I2C1 0x36, screen on, Android brightness 121/255), toybox i2cdump -fy 1 0x36
With the screen off the chip does not answer (NACK), apparently powered down through the enable gpio.
```
10: 1f 65 73 6f 00 00 00 00 07 d7 f7 00 ...
```
All other addresses 0x00..0xff = 0x00. Registers 0x10..0x13, 0x18..0x1a are written by the stock driver (or are chip defaults). Datasheet not checked.
File: notes/stock_dt/i2cdump_sgm_screen_on.txt.

## SGM37604A source (2026-10-29): `src/kernel_lenovo_tbj606/drivers/video/backlight/sgm37604a_driver.c` + `include/linux/sgm37604a.h` (GPL-2.0)
The backlight works anyway (DCS through the TCON); the driver is only needed if the chip current/mode has to be set (for example after a cold start without ABL).
