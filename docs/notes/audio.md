# Звук

## Факты
- Карта стока: bengal-idp-snd-card (q6 ADSP, APR).
- Цифровая часть: bolero (rx/tx/va macro), кодек wcd937x + rouleur (PM2250 analog, «pm2250_spmi_dlkm»), mbhc (гарнитура есть: Headset Jack, Button Jack, input event6/7).
- Динамики: 4 усилителя **Awinic aw882xx** (I2C0 0x34–0x37), модуль aw88258_4pa (стоковый `awinic,aw882xx_smartpa`), калибровки /vendor/firmware/awinic/aw882xx_acf.bin, aw882xx_monitor.bin.
- Микрофоны: АЦП **ES7210** (I2C1 0x40). Плюс DSPG DBMD8 на SPI1 (голосовая активация).
- USB-C аудио: fsa4480.

## Mainline v7.2.3
- wcd937x.c и pm4125.c (rouleur = PM4125/PM2250-кодек) есть; lpass macro для sm6115 есть (lpasscc-sm6115, lpass-lpi pinctrl sm6115).
- aw88xxx: aw88081, aw88166, aw88261, aw88395, aw88399. **aw88258 нет**; ближайший кандидат проверять по ID-регистру.
- es7210: **нет** в ядре.
- Машинный драйвер: sound/soc/qcom/sm8250.c (используется и для младших SoC). Нужен UCM.
- Сложность высокая, P1.

## ID усилителей
/sys/bus/i2c/devices/0-003{4..7}/reg (sysfs стокового драйвера aw882xx): reg 0x00 = **0x1852** у всех четырёх. Дампы: raw/root_20261028/aw882xx_0-003*.reg.txt. Какому mainline-драйверу соответствует ID 0x1852, ещё не сверено.
- Сверено с mainline v7.2.3: CHIP_ID aw88261 0x2113, aw88399 0x2183, aw88395 0x2049, aw88166 0x2066, aw88081 0x2116, aw88083 0x2407. **0x1852 (AW88258) нет ни в одном драйвере** → нужен новый драйвер или адаптация (ближе всего, вероятно, aw88395/aw88261: те же «acf»-прошивки).
- ADSP стартует со стоковой прошивкой (тест 8). Путь звука по стоковым меткам dtbo: динамики через LPASS LPI TDM1 (lpi_tdm1_*) → aw882xx; i2s2 (lpi_i2s2_*); кодек rouleur (PM2250 → mainline pm4125) + wcd937x; mbhc.

## Оценка (29.10, ночь) — что реально сделать
- Разъём наушников + микрофон гарнитуры: в mainline есть всё (LPASS APR/q6 в sm6115.dtsi, lpass-lpi pinctrl, rx/tx/va macro с sm6115, pm4125, wcd937x,
  машинный драйвер sm8250.c с `qcom,qrb4210-rb2-sndcard`). Нужно: DTS (macro, SoundWire, кодек, звуковая карта) + UCM. Нужны наушники.
- Динамики AW88258: драйвера нет; без правильной инициализации усилителя есть риск повредить динамики → только по GPL-исходникам Awinic.
- Встроенные микрофоны ES7210: драйвера нет. USB-C аудио (fsa4480): не начато.

## ★ GPL-исходники (2026-10-29): github.com/adazem009/kernel_lenovo_tbj606 → `src/kernel_lenovo_tbj606/`
- `techpack/audio/asoc/codecs/aw88258_4pa/` (Awinic 2020, GPL-2.0+): драйвер **AW88258**, `AW882XX_ID = 0x1852` (= наш ID), карта регистров `aw882xx_reg.h`,
  загрузчик прошивки «acf» (`aw_device.c`: проверка заголовка, профили регистров и DSP), калибровка, монитор (температура/напряжение → снижение усиления).
  Это снимает главный риск: инициализация усилителя берётся из стокового драйвера + стоковые aw882xx_acf.bin/aw882xx_monitor.bin, а не вслепую.
  Путь для mainline: новый ASoC-кодек `aw88258` по образцу sound/soc/codecs/aw88395 (тот же формат acf) с регистрами из aw882xx_reg.h.
- `sound/soc/codecs/es7210.c` (Everest 2014, GPL-2.0): 415 строк, полная последовательность инициализации (PGA +3 дБ, SCLK/LRCK = 64, TDM).
  Управление в стоке — kcontrol «ES7210_Switch» в машинном драйвере (es7210_start/stop). В mainline нужен нормальный ASoC-кодек (небольшой).
- `techpack/audio/asoc/bengal.c` (машинный драйвер Lenovo): TDM по умолчанию 48 кГц S16_LE, слоты через `snd_soc_dai_set_tdm_slot` (slot_offset 0,4,8…28) —
  отсюда брать параметры TDM для усилителей и ES7210.
- Порядок остаётся: разъём наушников (PM4125/WCD937x) → динамики AW88258 (порт драйвера) → ES7210.
