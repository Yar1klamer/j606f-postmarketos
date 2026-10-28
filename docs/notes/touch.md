# Тачскрин и стилус

## Факты с устройства
- SPI0 (QUP 4a88000.spi), CS0: `himax,hxcommon`, драйвер стока himax_tp, spi-max-frequency 10 МГц, spi-cpha.
  - irq: tlmm gpio 86 (0x56), флаги 0x2008; reset: tlmm gpio 54 (0x36)
  - panel/display coords 1200x2000
  - узел: stock_dt/spi_4a88000_touch.dtsi
- На том же SPI, CS1, описан `novatek,NVT-ts-spi` (для второго SKU с NT36523W), драйвер к нему не привязан.
- input: "himax-touchscreen" (event2) и "himax-pen" (event3) → **есть стилус (Lenovo Precision Pen)**.
- dmesg: чип **HX83102E**, режим **zero flash**: прошивку `Himax_firmware.bin` грузит хост после каждого resume (`It will update fw after resume in zero flash mode!`, `himax_mcu_firmware_update_0f`). Файлы /vendor/firmware/Himax_firmware.bin и Himax_mpfw.bin есть в BACKUP/firmware/vendor_firmware.tar.
- Есть «direction» (ориентация, cmd 2) и USB-detect (чип переключает режим при подключённом USB).

## Mainline
- В v7.2.3 нет драйвера HX83102 по SPI: есть только himax_hx83112b.c и himax_hx852x.c (I2C) и нет generic spi-hid.
- На LKML были серии:
  - Tylor Yang, «HID: touchscreen: Add initial support for Himax HID-over-SPI», v2/v3, 2023-09/10
  - Allen Lin, «HID: Add support for Himax HX83102j touchscreen», v1–v4, 2024-03/04, включая загрузку прошивки из файла и panel follower
  
  Мерж не подтверждён. Наш чип HX83102E, не J; совместимость протокола неизвестна.
- Варианты: (1) портировать серию Allen Lin hid-himax и проверить с HX83102E; (2) портировать downstream himax_tp (Lenovo kernel source, если там есть hx83102e) как out-of-tree модуль. Это самый трудоёмкий пункт P0.

## Статус
Не проверено. Риск высокий (нет драйвера).

## Стоковый драйвер (из стокового ядра 4.19, 2026-10-29)
- В стоковом Image (raw/stock_kernel/Image, распакован из boot) драйвер Himax встроен (не модуль): строки «Himax Touch Driver Version:», «HX83102A/B/D/E», «Himax_firmware.bin», «Himax_mpfw.bin», «g_core_fp», «himax,hxcommon», «himax,irq-gpio», «himax,rst-gpio», «himax,3v3-gpio», «himax-pen».
  Список символов himax_*/hx83102*_: notes/stock_dt/stock_kernel_himax_symbols.txt.
- Это стандартный GPL-драйвер Himax «hxchipset» (himax_common.c, himax_ic_core.c, himax_ic_HX83102.c, himax_platform_SPI.c) с поддержкой zero-flash (`himax_mcu_firmware_update_0f`). Lenovo исходники не выложили. Похожий код есть во многих Android-ядрах (Xiaomi/Moto/…), но конкретный репозиторий я не нашёл: веб-поиск ничего не дал, а поиск кода на GitHub требует входа.
- В DT стока есть «himax,3v3-gpio»: возможно, отдельное питание тача (в нашем узле стока его нет, только irq 86 / rst 54).

## План порта тача
1. Найти GPL-исходники hxchipset с HX83102E (поиск по «hx83102e_sense_off» / «himax_mcu_firmware_update_0f» в Android-ядрах; может помочь пользователь с аккаунтом GitHub).
2. Собрать как внешний модуль под 7.2.3 (так же, как panel/tps65132 через /build/ext), убрать Android-специфику (fb notifier → drm panel follower, wakelock и т. п.).
3. DT: &spi2 (QUP SE2, 4a88000) okay, узел himax_ts@0 (spi-cpha, 10 МГц, irq tlmm 86, reset tlmm 54) + пины QUP SE2 из стока.
4. Прошивка: /lib/firmware/Himax_firmware.bin (из BACKUP/firmware/vendor_firmware.tar).
Альтернатива: серия Allen Lin «HID: Add support for Himax HX83102j» (LKML 2024, hid-himax, грузит прошивку из файла), но чип у нас E, протокол может отличаться.
