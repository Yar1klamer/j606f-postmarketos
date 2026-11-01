# Камеры

## Железо (стоковый DT S120184 + CamX-модули из стокового vendor)
| | Задняя | Фронтальная |
|---|---|---|
| Сенсор | OV13B10 (два модуля: `ov13b10`, `ov13b10_qt`) | **S5K4H7** (`s5k4h7_lcetron`) — проверено по ID; в стоке ещё модуль OV8856 (`ov8856_kc`), на нашем экземпляре нет |
| CCI | master 0, 0x10 (8-бит 0x20) | master 1, **0x10** (в модуле S5K4H7 указан 0x2d/0x5a — не отвечает) |
| ID | 0x300a = 0x560d42 (драйвер, прочитан) | 0x0000 = 0x487b (прочитан); 0x300a = 54 03 5c |
| CSIPHY | 0, 4 линии (lane count — по драйверу, в .bin не разобрано) | 2, 4 линии (laneAssign 0x3210), 732 Мбит/с на линию |
| MCLK | MCLK0 gpio20, 19.2 МГц | MCLK2 gpio27, **24 МГц** (EXCK 0x1800 в CamX-модуле; в стоковом DT 19.2) |
| reset | gpio18 | gpio19 |
| vio / vana / vdig / vaf | по стоковому DT — PM8008; на деле: vio не переключается, vana gpio112 2.8 В, vdig gpio108 1.05 В, vaf gpio40 2.8 В (общие) | те же |
| Прочее | VCM DW9763 (`dw9763m11`) — CCI0 **0x0c**, ID 0xf9, питание VAF; EEPROM; вспышка PMI632 (flash_0/1) | EEPROM |
| sensor-position-roll | 90 | 270 |

- Питание: стоковый DT ссылается на PM8008 (I2C1 0x08/0x09, reset gpio26, irq gpio25), но на I2C1 0x08/0x09 никто не отвечает,
  в стоке драйвер к нему не привязан — PM8008 не распаян. Рельсы — внешние LDO: gpio112 (CAM_VANA 2.8 В), gpio108 (CAM_VDIG 1.05 В),
  gpio40 (CAM_VAF 2.8 В), их поднимает стоковая последовательность; в DT — regulator-fixed.
- CCI v1.2 0x5c1b000, IRQ 206, 37.5 МГц; пины CCI0 gpio22/23, CCI1 gpio29/30.
- Камера-подсистема — Spectra 340 «TFE», как у QCM2290 (agatti), но по 3 блока: CSIPHY 0x5c52000/53000/54000 (IRQ 72/73/74),
  CSID 0x5c6e000/75000/7c000 (IRQ 210/212/77), TFE +0x1000 (IRQ 211/213/78), TPG 0x5c66000/68000. Потоки SMMU 0x400/0x800/0x820/0x840.
- CSIPHY питание (сток mipi-csi-vdd) — pm6125 L18 1.2 В.

## Mainline 7.2.3
- CAMSS: есть QCM2290 (csid-340, vfe-340), SM6115 нет → патч 0017 (таблицы на 3 PHY/CSID/TFE, compatible `qcom,sm6115-camss`).
- CCI: `i2c-qcom-cci`, совместимость `qcom,msm8996-cci`.
- OV13B10: драйвер только с ACPI-таблицей → патч 0018 (OF match; питание/clk/reset уже через общие API).
- S5K4H7: драйвера нет (mainline и linux-media, поиск 2026-11-01) → свой драйвер, патч 0023 (регистры из CamX-модуля `s5k4h7_lcetron.bin`). OV8856: драйвер есть (на случай другого модуля).
- VCM DW9763: драйвер dw9719 (DW9761-совместим) + патч 0022 (ID 0xf9). Вспышка PMI632: leds-qcom-flash не подходит (старый тип).
- Апстрим: патчей SM6115 CAMSS не нашёл (поиск 2026-10-31).

## Патчи (src/patches, ядро r119–r121)
- 0017 media: qcom: camss: add SM6115 support
- 0018 media: i2c: ov13b10: add OF match table
- 0019 arm64: dts: qcom: sm6115: add CCI and CAMSS
- 0020 arm64: dts: qcom: sm6115p-lenovo-j606f: add cameras (sm6115p-lenovo-j606f-camera.dtsi)
- 0020: GPIO-регуляторы, задняя OV13B10, фронт `samsung,s5k4h7` disabled и вне графа CAMSS (иначе граф не собирается).
- 0021 media: i2c: ov13b10: add get_selection (native 4240x3144, активная (15,17) 4208x3120, crop по режимам).
- 0022 media: i2c: dw9719: add DW9763 (+ выключение питания при неизвестном ID).
- 0023 media: i2c: add Samsung S5K4H7 sensor driver (драйвер + binding `samsung,s5k4h7.yaml`).
- 0024 arm64: dts: qcom: sm6115p-lenovo-j606f: enable the front camera (CCI1 0x10 → CSIPHY2, 4 линии, link-frequency 366 МГц, MCLK2 24 МГц).
- Конфиг: I2C_QCOM_CCI, VIDEO_OV13B10, VIDEO_OV8856, VIDEO_DW9719, V4L2_CCI(_I2C) = m (PM8008 убран). Ядро r120; r121 + VIDEO_S5K4H7=m.
- libcamera (pmaports temp/libcamera): r5 — 0007 helper + свойства ov13b10 (усиление 0x80 = 1x, чёрный 4096, 1.12 мкм);
  r6 — 0008 helper + свойства s5k4h7 (усиление 0x20 = 1x, чёрный 4096, 1.12 мкм, тестовые шаблоны 0–4).
- r121 и libcamera r6 закоммичены, но ещё **не собраны** и не проверены пакетами (фронт проверен тестовым модулем и DTB).
- Рабочее дерево: src/work-cam (git worktree linux-sm61x5-full на 5a88d98 + 0001, 0003–0016 одним коммитом).

## Проверено (2026-11-01, r119 + тестовые DTB через fastboot boot)
- CAMSS, CCI, OV13B10: граф ov13b10 2-0010 → csiphy0 → csid0 → vfe0_rdi0 → /dev/video0.
- Захват RAW: `media-ctl -l '"msm_csiphy0":1->"msm_csid0":0[1],"msm_csid0":1->"msm_vfe0_rdi0":0[1]'`,
  `media-ctl -V` SGRBG10_1X10/2104x1560 по цепочке, `v4l2-ctl -d /dev/video0 --set-fmt-video=width=2104,height=1560,pixelformat=pgAA --stream-mmap`.
  Кадр 4105920 байт (stride 2632). test_pattern=1 — верные полосы, Байер GRBG.
- Реальная сцена на свету — проверено: узнаваемая картинка (exposure 1590, analogue_gain 512), размыта — VCM без драйвера.
- libcamera 0.7.2 (`cam` из libcamera-tools): «Internal back camera», simple + software ISP с GPU-дебайером (EGL, по умолчанию):
  RGB 2104x1560 — 27.6 fps, 1280x720 — 117 fps (режим 1364x768 120 fps). Ранние ~7.5 fps — из-за отладочного лога и длинной выдержки в темноте.
  Нет CameraSensorHelper ov13b10 (AGC без усиления), нет свойств сенсора; драйвер без get_selection (crop).
- Фронт: ID читался тестовым DTB v5 (рельсы always-on, MCLK2 на узле CCI, gpioset gpio19=1, `i2ctransfer -y 3 w2@0x10 0x00 0x00 r2`).

## Фронт S5K4H7 (2026-11-01, r120 + тестовый модуль и DTB через fastboot boot)
- Параметры из CamX-модуля (формат «Parameter Parser V2.0.0»: таблица символов + массивы значений по id):
  один режим 3264x2448 RAW10, line length 3580, frame length 2530, 30.03 fps; VT PLL 24/6×136 → pixel rate 272 МГц,
  OP PLL 6×183 → 732 Мбит/с на линию (link frequency 366 МГц); экспозиция 0x0202 (мин. 4, запас 4), усиление 0x0204
  (0x20 = 1x … 16x), 0x0340 frame length, 0x0101 ориентация, 0x0600 тестовый шаблон (1 цвет, 2 полосы, 3 полосы с
  затуханием, 4 PN9); чёрный 64; матрица 3280x2464, активная (8,8) 3264x2448; включение: reset 0 → рельсы → 5 мс → MCLK → 1 мс → reset 1 → 12 мс.
- Граф: `s5k4h7 3-0010` → msm_csiphy2. Захват RAW: `media-ctl -l '"msm_csiphy2":1->"msm_csid0":0[1],"msm_csid0":1->"msm_vfe0_rdi0":0[1]'`,
  SGRBG10_1X10/3264x2448 по цепочке, `v4l2-ctl -d /dev/video0 --set-fmt-video=width=3264,height=2448,pixelformat=pgAA` (stride 4080).
  test_pattern=2 — правильные полосы (белый … чёрный), Байер **GRBG** при flip 0/0, чёрный 64. Реальный кадр — резкий.
- libcamera: «Internal front camera», `cam -c 2` 1632x1224 — 30.03 fps; simple pipeline сам выбирает csid0 → vfe0_rdi0.
- ⚠️ Путь **csiphy2 → csid1 → vfe1_rdi0** при старте потока вешает планшет намертво (ни USB, ни сети; через несколько
  часов сторожевой таймер → экран Qualcomm CrashDump, выход — долгое нажатие питания). Адреса, IRQ, такты и SMMU CSID1/TFE1
  совпадают со стоковым DT; причина не найдена. Задняя камера тоже работает через CSID0 — CSID1/TFE1 вручную не включать.

## Дальше
1. Задняя: ✅ crop, ✅ AGC в libcamera, ✅ ручной фокус (DW9763: резкость 0 → 286, 450 → 907, 900+ → 79).
   Открыто: автофокуса в soft IPA нет; ориентация/rotation; 
   задержки сенсора и тюнинг ov13b10.yaml; вспышка PMI632.
2. Фронт: ✅ драйвер и DT (0023–0024), ✅ хелпер libcamera (0008). Открыто: сборка и проверка r121/libcamera r6,
   режим 2x2 binning (1632x1224), задержки сенсора, s5k4h7.yaml/цвет, зависание CSID1/TFE1.
3. VCM DW9763, вспышка PMI632.
