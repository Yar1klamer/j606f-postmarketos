# Дисплей

## Факты с устройства (2026-10-28, root)
- /proc/cmdline: `msm_drm.dsi_display0=qcom,mdss_dsi_himax83102p_boe_2k_video:` → **панель Himax HX83102P (BOE, 2K), video mode**.
- В DT стока описаны обе панели: `qcom,mdss_dsi_himax83102p_boe_2k_video` (выбрана, qcom,dsi-default-panel = <0x3F4>) и `qcom,mdss_dsi_nt36523w_boe_2k_video`. Выбор SKU делает ABL через cmdline.
- **Mainline DTS sm6115p-lenovo-j606f.dts описывает только NT36523W (lenovo,j606f-boe-nt36523w).** Для нашего экземпляра это НЕ подходит. Нужен вариант DTS для HX83102P.
- Узел панели стока: stock_dt/panel_hx83102p_boe.dtsi. Расшифрованный on-command (50 DSI-пакетов): stock_dt/panel_hx83102p_on_cmds.txt.
- Ключевые параметры:
  - 1200x2000, 24 bpp, 4 линии (lane_map_0123), burst mode, video mode, 60 Гц
  - HFP 60, HBP 49, HSW 8; VFP 80, VBP 38, VSW 8 → htotal 1317, vtotal 2126, pixel clock ≈ 168.0 МГц (в стоке DRM mode «1200x2000x60x167996vid» подтверждает)
  - физический размер 143 x 235 мм
  - qcom,mdss-dsi-panel-orientation = "180" (как и в mainline для NT36523W: смонтирована вверх ногами)
  - reset: tlmm gpio 82 (0x52), последовательность <1 10ms, 0 10ms, 1 60ms>, `qcom,platform-reset-gpio-always-on`
  - `qcom,mdss-dsi-lp11-init`, `tx-eot-append`, t-clk-post 0x14, t-clk-pre 0x50
  - подсветка: `bl_ctrl_dcs`, диапазон 1..4095 (12 бит, DCS 0x51 двумя байтами); в on-command `51 00 00`, `53 2c`
  - ESD-проверка: чтение регистров 0x09, 0x0A, 0x45
  - off: `28` (display off), `10` (sleep in, 60 ms); pre-off `53 24`; post-off `b9 83 10 2e`, `b1 21` (видимо, deep standby)
- vddio: pm6125_l9 (1.8 В), как в mainline. vdda DSI: pm6125_l18 1.232 В.
- Питание ±5.4 В: tps65132 на I2C1 0x3e, ENP = tlmm gpio 111 (0x6F), ENN = tlmm gpio 44 (0x2C). Регуляторы lcdb_ldo/lcdb_ncp (pmi632) в стоке не используются (use_count 0).
- TE: в mainline DTS gpio81 mdp_vsync (для video mode не обязателен).

## Mainline
- В ядре sm61x5 v7.2.3 есть drivers/gpu/drm/panel/panel-himax-hx83102.c (compatible: boe,nv110wum-l60, csot,pna957qt1-1, holitech,htf065h045, ivo,t109nw41, kingdisplay,kd110n11-51ie, starry,2082109qfh040022-50e, starry,himax83102-j02, waveshare,12.3-dsi-touch-a). Нашей панели там нет.
- План: добавить в panel-himax-hx83102.c описание «lenovo,j606f-boe-hx83102p» с init-sequence из stock_dt/panel_hx83102p_on_cmds.txt и таймингами выше. Альтернатива: сгенерировать отдельный драйвер через linux-mdss-dsi-panel-driver-generator (lmdpdg) из DT стока.
- Для первой загрузки панель не нужна: работает simple-framebuffer, оставленный ABL (адрес в mainline DTS 0x5c000000, 1200x2000, stride 4800). Это проверить: адрес splash-буфера стока должен совпадать (cont_splash в DT стока).

## Статус
**Работает** (29.10): изображение и яркость подтверждены пользователем, 60 Гц, weston/kmscube. В установленном pmOS: DSI-1 connected. Результаты ниже.

## TPS65132 (I2C1 0x3e) в стоке, toybox i2cdump -fy 1 0x3e
`00: 11 11 00 03` → VPOS = VNEG = 0x11 → 4.0 В + 17×0.1 В = **±5.7 В**, reg 0x03 = 0x03 (активный разряд обоих выходов).
В DTS нужно задать regulator-min/max-microvolt = 5700000 для outp/outn (если после холодного старта значение из EEPROM окажется другим).

## ★ Результаты mainline (2026-10-29, тест 5)
- msm DRM + наш драйвер панели: DSI-1 connected/enabled/dpms On, режим 1200x2000@60 (clock 167996). Ошибок при включении панели нет.
- Подсветка: DCS, /sys/class/backlight/5e94000.dsi.0, 0..4095, запись работает. Чтение DCS 0x52 → «msm_dsi_host_cmd_rx:Invalid response cmd» (у этой панели 0x52 нет). TODO: убрать .get_brightness для этой панели.
- Часы DSI: VCO 2015.952 МГц, pclk 167.996, byte 125.997 МГц (4 линии × 1008 Мбит/с).
- Тайминговый движок INTF1 (devmem через python mmap, 0x05e6b800 = MDP 0x5e01000 + 0x6a800): TG_EN=1, FRAME_COUNT +30 за 0.5 с (**ровно 60 Гц**), HSYNC_CTL=0x05250008 (htotal 1317, pulse 8), VSYNC_PERIOD_F0=2799942 (=1317×2126). **Видеопоток генерируется.**
- ~~ПРОБЛЕМА: vsync IRQ~~ **ИСПРАВЛЕНО в понимании (тест 7):** сначала я перепутал регистры. В legacy DPU (≤6.x, dpu_hwio.h) INTR_EN = +0x010, INTR_STATUS = +0x014, INTR_CLEAR = +0x018. Реально: EN (0x5e01010) = 0 в простое, STATUS (0x5e01014) = 0x08000100 (биты 27 vsync и 8 PP0_DONE защёлкнуты и не обслуживаются, пока выключены). Это нормально, vblank включается по запросу.
  Во время `modetest -v`: OR(EN) = 0x08000000 (vsync включён), а drm.debug показывает «updating vblank count … diff=1» каждые ~16.9 мс, то есть **vblank IRQ работает на 60 Гц**.
  ~~Остаётся реальная проблема: page flip завершаются медленно~~ **НЕТ ПРОБЛЕМЫ (тест 8):** это был артефакт: modetest -v без открытого stdin сразу выходит. С `sleep | modetest -v` выходит freq 60.0 Гц, kmscube даёт 59.99 fps. Старый текст оставлен для истории: (modetest -v за 12 с не выводит ни одной строки freq, то есть меньше 60 flip; kmscube -c 120 не завершается за 20 с). Причина, видимо, в пути commit/flip (ожидание ctl start / frame done?), а не в IRQ. Ручное включение бита 27 в EN драйвер сразу снимает (нет callback). Глубокий cpuidle ни при чём (запрет state1 ничего не изменил).
  Следующие шаги: drm.debug=0x1ff (+ msm DPU_DEBUG) во время flip с полными логами; проверить INTR2 (ctl_0 intr_start = TOP0_INTR2 бит 9: EN2 +0x008, STATUS2 +0x00c) — ждёт ли commit «ctl start»; попробовать weston/kmscube с atomic и посмотреть фактический fps; сравнить с другими SM6115-устройствами в mainline.
- Визуальная проверка: на экране оставлена тестовая таблица (8 полос + рамка + «J606F OK»). Ждёт глаз пользователя.
