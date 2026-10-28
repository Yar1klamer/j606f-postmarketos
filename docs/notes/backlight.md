# Подсветка

## Факты
- Управление в стоке: **DCS** (`qcom,mdss-dsi-bl-pmic-control-type = "bl_ctrl_dcs"`), уровни 1..4095. В dmesg `dsi_panel_set_backlight ... type:2 lvl:1654`.
- /sys/class/backlight/panel0-backlight max=255 (в стоке Android масштабирует 0..255 → 0..4095).
- LED-драйвер: **SGM37604A** на I2C1 0x36, stock compatible `sgm,sgm37604a`, enable = **pmi632 gpio6** (`qcom,platform-bklight-en-gpio = <&pmi632_gpios 6 0>`).
- Схема по смыслу: TCON панели получает 0x51 по DSI и выдаёт PWM на SGM37604A. SGM37604A надо включить (gpio) и, возможно, настроить по I2C (ток, режим PWM). Что пишет стоковый драйвер, неизвестно: нужны исходники или дамп регистров.

## Mainline
- Драйвера sgm37604a в v7.2.3 нет (есть только sgm3140 flash и sgm3804 regulator).
- План: (1) яркость через DCS в драйвере панели (backlight_device из mipi_dsi_dcs_set_display_brightness_large); (2) включить pmi632 gpio6 (gpio-hog или regulator-fixed/enable). Если SGM37604A после сброса без настройки не светит, снять его регистры в стоке через i2cdump (root) и сделать минимальный драйвер или инициализацию.

## TODO
- В стоке под root: `i2cdump -y 1 0x36` (если i2c-tools есть в Android) или чтение через debugfs.

## Регистры SGM37604A в стоке (I2C1 0x36, экран включён, яркость Android 121/255), toybox i2cdump -fy 1 0x36
При выключенном экране чип не отвечает (NACK), видимо обесточен через enable-gpio.
```
10: 1f 65 73 6f 00 00 00 00 07 d7 f7 00 ...
```
Остальные адреса 0x00..0xff = 0x00. Значения регистров 0x10..0x13, 0x18..0x1a пишет стоковый драйвер (или это дефолты чипа). Datasheet не смотрел.
Файл: notes/stock_dt/i2cdump_sgm_screen_on.txt.
