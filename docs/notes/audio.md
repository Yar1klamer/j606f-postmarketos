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

## 2026-10-31 — старт разработки: разъём наушников (wcd937x)
Сток (stock_live_S120184.dts) уточняет оценку от 29.10: аналоговый кодек — **wcd937x** (split-codec на SoundWire), а не rouleur/PM4125:
- RX-slave на SoundWire rx-macro (swr master 2, `0xa610000`, IRQ 297), TX-slave на SoundWire va-macro (master 3, `0xa740000`, IRQ 296 + wake 79);
- сброс **GPIO92** (у RB2 — GPIO82), питание: vdd-rxtx/vddpx = **pm6125_l9** (1.8 В), vdd-buck = **pm6125_l14** (1.8 В), micbias 1/2/3 = 1.8 В;
- звуковая карта стока: bengal-asoc-snd, гарнитура через mbhc (`qcom,msm-mbhc-gnd-swh = 1`, hphl-swh 0), USB-C аудио через fsa4480.
Mainline 7.2.3: на ADSP (наша стоковая прошивка) уже есть APR-сервисы 3/4/7/8 (core, AFE, ASM, ADM). В ядре есть compatible
`qcom,sm6115-lpass-{rx,tx,va}-macro`, `qcom,wcd9370/9375-codec` (вариант определяется по CHIPID), `qcom,soundwire-v1.6.0`, lpasscc/lpassaudiocc sm6115
и машинный драйвер sm8250.c с `qcom,qrb4210-rb2-sndcard`. Узлов LPASS-макросов и SoundWire в sm6115.dtsi нет ни у нас, ни в upstream:
серия Alexey Klimov «qrb4210-rb2: add wsa audio playback and capture support» v3 (2025-05-22, patchwork series 965505) не влита.
Скачана в `src/audio/upstream-rb2-v3/`; адреса и IRQ её узлов (07) совпадают со стоком. В конфиге пакета выключены SND_SOC_QDSP6, SM8250,
LPASS_{RX,TX,VA}_MACRO, WCD937X_SDW.

План:
1. ядро: узлы LPASS (патч 07 серии) + в j606f-common: wcd937x (GPIO92, L9/L14), swr0/swr1, звуковая карта (MM1 → RX_CODEC_DMA_RX_0 →
   rxmacro/swr1/wcd937x HPH; TX_CODEC_DMA_TX_3 ← txmacro/swr0/wcd937x ADC2 для микрофона гарнитуры); конфиг — эти опции =m;
2. тест без записи boot_b: модули из tdev для работающего r115 в /lib/modules/…/extra, новый DTB через kexec со старым Image
   (при зависании обычное включение возвращает прежний boot_b);
3. проверка без ушей: перечисление wcd937x на SoundWire, карта в /proc/asound, DAPM-путь до HPHL/HPHR, aplay без ошибок;
   прослушивание и определение гарнитуры — владелец, когда будет рядом с планшетом;
4. UCM (HiFi: Headphones/Headset), пакет ядра r116;
5. дальше: динамики AW88258 (порт драйвера из GPL-исходников Lenovo, TDM через LPASS LPI) и ES7210.

### 2026-10-31: результат bring-up WCD937x (подробно — LOG.md)
- Работает при порядке: macros → snd-soc-wcd937x → soundwire-qcom: оба слейва Attached, карта sm4250 «Lenovo-TB-J606F»,
  воспроизведение hw:0,0 и запись hw:0,1 (TX SMIC MUX0 = SWR_MIC1, ADC2 INP2) без ошибок.
- Если шина стартует до кодека: clock stop без слейвов, resume не поднимает кадры (FRM_GEN=0) → нужен патч soundwire-qcom.
- **Разъёма 3.5 мм нет.** WCD937x HPH/ADC2 выведены на USB-C через FSA4480 (i2c-1, 0x42, ID 0x09). Аналоговый USB-C звук
  потребует fcs,fsa4480 + mode/orientation-switch от Type-C (typec@22 на i2c-0) и accessory mode.
- Приоритет меняется: сначала динамики AW88258 (TDM на LPI), затем ES7210 (встроенные микрофоны), USB-C analog — после.

### 2026-10-31: динамики AW88258 (подробно — LOG.md)
- TDM: PRI_TDM_RX_0, LPI gpio6–9 (i2s1_*), 4 слота × 32 бит, 48 кГц, DSP мастер, invert-sync, канал N → усилитель 0x34+N (по acf).
- acf старого формата (0x0a15f908): разбор в aw88258.c; регистры 0x06/0x07 задают канал/слот каждого усилителя.
- Драйвер: src/audio/aw88258/aw88258.c; sm8250 TDM: src/patches/0014; DT: audio.dtsi.
- Без защиты SKT (ADSP): держать ослабление; добавить монитор по aw882xx_monitor.bin до упаковки.
- Тест на планшете тестировщика 2026-10-31: все 4 динамика играют. Каналы 1..4 = левый низ, правый низ, левый верх, правый верх.

### 2026-10-31: звук в пакетах (r116, подробно — LOG.md)
- Ядро r116: 0012 LPASS (patchwork), 0013 драйвер aw88258, 0014 sm8250 TDM (стерео в слотах 0/1 из 4), 0015 soundwire-qcom
  (переинициализация, если после clock stop нет кадров), 0016 dts audio. Конфиг: QDSP6, SM8250, LPASS macros, WCD937X_SDW, AW88258.
- Стерео: L → SpkBL (0x34) + SpkTL (0x36), R → SpkBR (0x35) + SpkTR (0x37). Верхние усилители переведены со слотов 2/3 на 0/1
  через `awinic,rx-slot-mask = <0x3>`.
- Громкость усилителей: потолок -6 dB (контрол 0..168), UCM ставит 168, остальное — программно. Монитор VBAT/температуры по таблицам
  стока: BST_IPEAK и ослабление (последнее не глубже потолка — на деле не срабатывает).
- UCM: conf.d/sm4250/Lenovo-TB-J606F.conf → Lenovo/TB-J606F/HiFi.conf (src/audio/ucm), только Speaker.
- acf: device-пакет достаёт с vendor (firmware-extract), у нас — личная firmware 1-r3; в общем наборе 0.320208 пока нет.
- Нет acf → драйвер откладывает probe (EPROBE_DEFER), firmware-extract после добавления файла перепривязывает один усилитель.
- ПОПРАВКА 2026-10-31 (прослушивание по одному усилителю на нашем планшете): 0x36 — правый верх, 0x37 — левый верх.
  Стерео: L → 0x34 (BL) + 0x37 (TL), R → 0x35 (BR) + 0x36 (TR); верхним задан канал через awinic,rx-channel (r117).
- Аудиобэкенд системы — PulseAudio (не PipeWire): проверять `pactl list short sinks` → HiFi__Speaker__sink.
