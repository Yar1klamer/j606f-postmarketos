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
**Работает (29.10)**: касания в Plasma попадают точно (подтвердил владелец). Стилус: устройство есть, с пером не проверено. Подробно — раздел «Порт» ниже.

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

## ★ GPL-исходники найдены (2026-10-29): github.com/adazem009/kernel_lenovo_tbj606
Ядро Lenovo 4.19 для TB-J606F/L/X (ветки lineage-17.1/18.1/19.1, halium-10/11; на нём у другой ревизии работает Droidian/Ubuntu Touch).
Частичный клон (lineage-18.1, f6bb9c6): `src/kernel_lenovo_tbj606/` (не публикуется, лежит только у нас).
- `drivers/input/touchscreen/himax83102p/` — **тот самый драйвер стока** (GPL-2.0, Himax 2019): HX83102E, `HX_ZERO_FLASH`, `Himax_firmware.bin` + `Himax_mpfw.bin`,
  `spi_driver` с `compatible = "himax,hxcommon"`; в нём есть `hx83102e_sense_off`, `himax_mcu_firmware_update_0f` (символы, которые мы искали в стоковом Image).
  Импортирован коммитом a56fd12c01 (2024-08-09), правка wakeup_source 1a2dfc0533. Конфиг стока: `TOUCHSCREEN_HIMAX_CHIPSET/COMMON/INCELL/IC_HX83102=y`, DEBUG и INSPECT.
- DT-свойства драйвера: `himax,irq-gpio`, `himax,rst-gpio`, `himax,3v3-gpio`, `himax,pon-gpio`, `himax,lcm-rst`, `himax,panel-coords`, `himax,display-coords`,
  `report_type`, регуляторы `vdd`/`avdd`.
- Что менять для mainline 7.2: убрать downstream-API (`drm_panel_notifier`/`fb_notifier` → `drm_panel_follower`, как i2c-hid), `<linux/hqsysfs.h>`, `asm/segment.h`,
  `kallsyms`, `buffer_head`; отключить DEBUG/INSPECT (proc-интерфейсы); charger-notifier (USB-режим) можно оставить через power_supply.
  HX83102P — TDDI (дисплей и тач в одном чипе), сброс общий с панелью (`himax,lcm-rst`) → порядок включения должен идти за панелью (panel follower).
- План: собрать как внешний модуль под 7.2.3 → DT-узел в `&spi2` (QUP SE2, irq tlmm 86, reset tlmm 54, `panel = <&panel>`) → прошивка из BACKUP/firmware/vendor_firmware.tar.

## ★ Порт на 7.2 — работает (2026-10-29)
- Исходник: `src/himax83102p-port/orig/` (Lenovo), скрипт `port.py` → `out/`; в ядро — патч `0006-Input-add-Himax-HX83102E-touchscreen-for-Lenovo-J606F.patch`
  (каталог drivers/input/touchscreen/himax_hx83102e/, `CONFIG_TOUCHSCREEN_HIMAX_HX83102E=m`), генератор патча `make_patch.sh`.
- Что изменено: см. LOG 29.10 и докстринг port.py. Главное: один модуль, без kallsyms/debug/inspection, gpiod, proc_ops, timespec64, strscpy, hrtimer_setup,
  drm_panel_follower (prepared → resume с перезаливкой прошивки, unpreparing → suspend), spi_device_id «hxcommon», parent у input-устройств,
  `touchscreen-inverted-x/y` и разрешение осей пера (8 ед./мм).
- Ориентация: панель стоит на 180° (`rotation = <180>`, DRM «panel orientation: Upside Down», KWin это учитывает), а тач отдаёт координаты корпуса →
  без инверсии касания отражены через центр. Тест по 4 углам (экран в ландшафте, как держит владелец): ЛВ (1109,114), ПВ (1050,1855), ПН (218,1859), ЛН (192,133).
  Проверено сначала udev-матрицей `LIBINPUT_CALIBRATION_MATRIX="-1 0 1 0 -1 1"` → «точно», затем перенесено в драйвер (DT-свойства).
- Лог probe: «detect IC HX83102E successfully» → через 2 с «Forced upgrade» → «Update FW success», FW_VER D403, CID 1741, BOE/P11; IRQ tlmm 86 edge falling.
- Прошивка: `Himax_firmware.bin`, `Himax_mpfw.bin` — в firmware-lenovo-j606f r1 (тарбол локальный, не публикуется).
- Грабли: `pkill -f` в ssh убивает свою же оболочку (снова); `udevadm info` сразу после insmod показывает свойства до обработки правил — ждать `udevadm settle`;
  на этом образе нет /etc/udev/rules.d (создать).
