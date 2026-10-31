# postmarketOS для Lenovo Tab P11 (TB-J606F)

Порт [postmarketOS](https://postmarketos.org) (с 2026 года проект называется **Nura**) на планшет
**Lenovo Tab P11 TB-J606F** (Wi-Fi) на основе **mainline-ядра Linux 7.2**
([linux-nura-qcom-sm61x5](https://codeberg.org/sm61x5-mainline/linux)).

> **Статус: pmOS (Nura edge) с KDE Plasma Desktop ставится во внутреннюю память и грузится сам.** Работают дисплей, GPU (OpenGL ES и Vulkan),
> Plasma (Wayland), Wi-Fi, **Bluetooth (полностью: сопряжение и устройства ввода)**, USB-сеть/SSH, кнопки, батарея и статус зарядки.
> Работают датчики (свет, приближение, акселерометр), **тачскрин** (порт GPL-драйвера Lenovo для HX83102E), **USB OTG** и зарядка от сетевой USB-C,
> GPU после исправления голосования за память DDR (патч 0009) быстрее в 2.5–7 раз. Работает **аппаратное H.264/HEVC-декодирование через Venus** (патч 0011).
> **Работают динамики** (4× AW88258, стерео, с ядра r117 + device r17); микрофонов и гарнитуры через USB-C пока нет.
> Сон и offline-зарядка находятся на стадии финальной проверки.
> Обновления ставятся через **apk-репозиторий** (см. [ниже](#обновления-через-apk-репозиторий)). Подробности — в [STATE.md](STATE.md).

**Автор порта и apk-репозитория — [@nnshould](https://t.me/nnshould) (Telegram).** Вопросы по репозиторию, установке и помощь — туда.

![KDE Plasma Desktop на TB-J606F](docs/img/plasma_desktop.png)

<details>
<summary>Ещё скриншоты</summary>

| fastfetch | Информация о системе (KInfoCenter) |
|---|---|
| ![fastfetch: Nura edge, Linux 7.2.3-sm61x5, KDE Plasma 6.8.1, Turnip Adreno 610](docs/img/plasma_fastfetch.png) | ![KInfoCenter: Plasma 6.8.1, Qt 6.11.1, ядро 7.2.3-sm61x5](docs/img/plasma_infocenter.png) |

Ранний этап bring-up — weston на mainline-ядре (снимок буфера композитора):

![weston](docs/img/weston_screenshot.png)
</details>

---

## Содержание
- [Устройство](#устройство)
- [Что работает](#что-работает)
- [Главная особенность: загрузчик Lenovo и dtbo](#главная-особенность-загрузчик-lenovo-и-dtbo)
- [Структура репозитория](#структура-репозитория)
- [Сборка](#сборка)
- [Установка](#установка)
- [Обновления через apk-репозиторий](#обновления-через-apk-репозиторий)
- [Откат на Android](#откат-на-android)
- [Отладочная среда без rootfs](#отладочная-среда-без-rootfs)
- [Известные проблемы и планы](#известные-проблемы-и-планы)
- [Благодарности и лицензии](#благодарности-и-лицензии)

## Устройство

| | |
|---|---|
| Модель | Lenovo Tab P11, TB-J606F (Wi-Fi, без LTE), 2020 |
| SoC | Qualcomm SM6115P «bengalp» (Snapdragon 662), soc_id 445 |
| CPU | 4× Kryo 260 Gold до 2.016 ГГц + 4× Kryo 260 Silver до 1.8 ГГц |
| GPU | Adreno 610 |
| RAM / память | 4 или 6 ГБ / UFS 64 или 128 ГБ (проверено на 6/128) |
| Экран | 11", 2000×1200, **две ревизии**: BOE + **Himax HX83102P** (основная, проверена) и BOE + Novatek NT36523W (свой DTB и device-пакет, не проверено) |
| Тач | Himax HX83102E (zero-flash, SPI) + стилус; у второй ревизии Novatek |
| Wi-Fi / BT | WCN3990 (ath10k_snoc / btqca) |
| Батарея | 7500 мА·ч, fuel gauge MM8013, зарядник PMI632 + SMB1355 |
| Звук | 4× Awinic AW88258, ES7210, WCD937x / PM2250 |
| Датчики | через Qualcomm SSC (ADSP): ICM4x6xx, LTR578, TMF8801, SX932x |

Ревизия определяется по `/proc/cmdline` стокового Android:
`msm_drm.dsi_display0=qcom,mdss_dsi_himax83102p_boe_2k_video` означает ревизию Himax (этот порт).

## Что работает

Проверено в установленном pmOS (ядро 7.2.3 с патчами до 0016, Plasma Desktop), сначала — через `fastboot boot`. Подробности по подсистемам — в [`docs/notes/`](docs/notes/).

| Подсистема | Статус | Примечание |
|---|---|---|
| Загрузка ядра | ✅ | со стёртым `dtbo` (или через «отстойник» для стокового dtbo, см. ниже) |
| UFS, разметка | ✅ | |
| microSD | ✅ | sdhc_2: карта определяется и монтируется, discard работает (проверено на втором планшете) |
| Дисплей HX83102P + подсветка | ✅ | свой драйвер панели (init из стокового DT), 60 Гц, DCS-яркость 0…4095 |
| GPU Adreno 610 | ✅ | Mesa freedreno (GLES 3.2) и **Vulkan** через turnip (`mesa-vulkan-freedreno`). Патч 0009: GPU голосует за пропускную способность DDR (в sm6115.dtsi её не было) — glmark2-es2 277 → 694, vkmark 87 → 599 |
| Видеодекодирование Venus | ✅ | **Аппаратные H.264 и HEVC 1080p** через `v4l2m2m-copy` (патч 0011, ядро r115 + per-device firmware r2); проверены полные файлы с корректным EOF. Для просмотра в mpv программное декодирование плавнее (копирование кадров из Venus теряет кадры), см. ниже |
| Видео в mpv | ✅ | device r20+ кладёт `/etc/mpv/mpv.conf`: `profile=fast` (масштабирование по умолчанию на 2000×1200 не успевает — без него теряется 50–75% кадров) и `hwdec=no`. 1080p H.264 30/60 fps — 0/3 пропуска из 360/720, HEVC — 0/28 |
| Wayland, KDE Plasma Desktop | ✅ | weston и Plasma (kwin_wayland) на GPU, 60 Гц; автологин и ландшафт настраиваются вручную |
| Экранная клавиатура | ✅ | plasma-keyboard (EN/RU), значок на панели; см. [заметки](docs/notes/input_keyboard.md) |
| Кнопки Power, Vol± | ✅ | Power гасит/включает экран (настройка PowerDevil) |
| USB-сеть, SSH | ✅ | гаджет ECM/ACM |
| USB OTG (хост) | ✅ | Type-C через FUSB302 + внешний 5 В буст (gpio38), патч 0008; USB 2.0, без PD. Проверено с USB-ресивером мыши. После выхода из режима хоста USB-сеть к ПК не работает до перезагрузки (dwc3 «failed to enable ep0out») |
| Зарядка | ✅ | от сетевых зарядников USB-A и USB-C (C-to-C), павербанка и USB-порта ПК; всегда 5 В (без PD/QC), вход до 1.5 А: от сетевых в батарею ~1.0–1.4 А, от ПК медленнее. Для C-to-C FUSB302 выставляет Rd (патч 0008), без него такие зарядки не включаются. Слабый зарядник или кабель: PMI632 снижает ток (AICL), и при включённом экране заряда может не хватать |
| Wi-Fi | ✅ | ath10k (WCN3990): подключение WPA2, DHCP, интернет |
| Bluetooth | ✅ полностью | WCN3990 (btqca): поиск, сопряжение, HID-устройства (проверено с мышью); постоянный адрес задаёт bootmac |
| Батарея | ✅ | fuel gauge mm8013 (патч 0005: правильный знак тока по ABI, связь с зарядником, Li-ion) — Plasma/UPower показывают заряд/разряд верно |
| cpufreq, thermal, троттлинг CPU | ✅ | cooling-maps добавлены в DTS |
| Modem / ADSP / CDSP | ✅ стартуют | стоковые прошивки |
| Перезагрузка в bootloader | ✅ | reboot-mode PON |
| Тачскрин | ✅ | HX83102E (zero-flash, SPI): порт драйвера Lenovo (патч 0006), прошивка `Himax_firmware.bin` со своего устройства; следует за панелью при гашении экрана |
| Стилус | ❓ | устройство `himax-pen` есть, с пером не проверено |
| Динамики | ✅ | 4× AW88258 (свой драйвер, патч 0013) на PRIMARY TDM (0014): стерео, левая пара — левый канал, правая — правый; громкость усилителей ограничена −6 дБ (защиты динамиков стока на DSP нет), монитор батареи/температуры как в стоке; настройки усилителей `awinic/aw882xx_acf.bin` — с vendor своего планшета. UCM: устройство «Speaker» в PulseAudio |
| Микрофоны, гарнитура | ❌ | ES7210 — нужен порт драйвера; гарнитура идёт через USB-C (WCD937x за FSA4480, кодек и SoundWire уже поднимаются) |
| Датчики (акселерометр, свет, приближение) | ✅ | Qualcomm SSC на ADSP: hexagonrpcd (свой патч, `pmaports/temp/hexagonrpcd`) + libssc + iio-sensor-proxy; файлы SSC — со своего устройства. Матрица ориентации акселерометра ещё не подобрана |
| Управление зарядкой (PMI632) | ⚠️ только чтение | свой read-only драйвер (патч 0004): онлайн, статус, тип USB, лимиты. Заряжает на настройках загрузчика (4.40 В / 3 А, вход 1.5 А): лимит входа не поднимается под зарядник на 3 А, нет PD/QC, порога заряда и параллельного SMB1355 |
| Сон (s2idle) | ⚠️ экспериментально | r110 исправил USB ep0, r111 успешно выполнил s2idle 37 с; ручной helper восстанавливает BT, но полная проверка ADSP/датчиков не завершена |
| Офлайн-зарядка | ⚠️ частично | device r11: charger mode из PON reason + reboot mark, обычный reboot проверен; полный цикл poweroff/charger/unplug ещё не завершён |
| Камеры, клавиатура на pogo-пинах | ❓ | не проверялось |

## Главная особенность: загрузчик Lenovo и dtbo

ABL этого планшета **всегда** накладывает оверлей из раздела `dtbo` (запись «Lenovo P11 WIFI PVT») на DTB из boot.img.
В mainline DTB нет `__symbols__`, наложение не удаётся, и ABL отвечает `Booting OKAY`, но ядро не запускает.

**Простое решение (проверено): стереть dtbo слота, с которого грузится pmOS** — `fastboot erase dtbo_b`.
Тогда ABL берёт DTB из boot.img как есть (подсказал коллега, тоже портирующий pmOS на этот планшет). Стоковый `dtbo_a` при этом не трогается.

Решение без записи в `dtbo` (если стирать нельзя):
[`kernel/dts/sm6115p-lenovo-j606f-abl-sink.dtsi`](kernel/dts/sm6115p-lenovo-j606f-abl-sink.dtsi) добавляет выключенный узел `/abl-sink`
с узлом-phandle на каждую метку из `__fixups__` стокового оверлея (138 штук) и `__symbols__`, которые указывают на эти узлы.
Оверлей ложится в «отстойник», ядро его не трогает. Генератор: [`scripts/gen_abl_sink_dtsi.py`](scripts/gen_abl_sink_dtsi.py).

Побочный эффект: ABL заменяет корневые `model`/`compatible` на `qcom,bengalp-idp`. Из-за этого `ubwc_config` и `qcom_pd_mapper`
не узнают SoC. Это обходил патч `0002-HACK` (добавляет `qcom,bengalp`; лежит в `kernel/patches/` для этого случая).
**Сейчас используется стёртый dtbo_b**, поэтому пакет ядра собирается **без** HACK 0002, а abl-sink остаётся в DTB как страховка.

Ещё одна особенность: `fastboot boot` работает **один раз за сессию bootloader**. Перед каждой попыткой нужен `fastboot reboot bootloader`.

## Структура репозитория

```
kernel/
  patches/                 патчи к linux-nura-qcom-sm61x5 7.2.3 (пакет linux-lenovo-j606f)
    0001-…-HX83102P.patch   панель BOE/Himax HX83102P в panel-himax-hx83102.c
    0002-HACK-…patch        qcom,bengalp для ubwc_config/pd_mapper (только если dtbo не стёрт; в пакет не входит)
    0003-…-HX83102P-SKU.patch  DTS ревизии HX83102P + abl-sink.dtsi + Makefile
    0004-…-PMI632-charger…patch  read-only драйвер зарядника PMI632 (SMB5) + узел в DTS
    0005-…-mm8013-…patch      mm8013: знак current_now, power-supplies → зарядник, TECHNOLOGY=Li-ion
    0006-…-HX83102E-…patch    тачскрин Himax HX83102E (порт драйвера Lenovo) + узел в DTS
    0007-…-NT36523W-SKU.patch общая часть DTS (common.dtsi) + DTB ревизии NT36523W
    0008-…-USB-C-OTG…patch     USB-C OTG: FUSB302 (I2C0 0x22) + VBUS-буст по gpio38, dwc3 dual-role
    0009-…-GPU-DDR-bandwidth…  голосование GPU за пропускную способность DDR (gfx-mem + opp-peak-kBps из стока)
    0010-…-UTMI…resume.patch  восстановление USB UTMI clock после сна
    0011-…-Venus-video-codec.patch  SM6115 Venus: DTS, vcodec0 HW_CTRL, стоковая firmware и EOS quirk
    0012-…-LPASS-devices.patch  SM6115 LPASS: макросы RX/TX/VA, SoundWire, LPI pinctrl
    0013-…-AW88258-…patch     драйвер усилителей Awinic AW88258 (динамики)
    0014-…-primary-TDM-…patch  sm8250: воспроизведение на PRIMARY_TDM_RX_0 (4 усилителя, стерео)
    0015-…-soundwire-…patch   soundwire-qcom: восстановление после clock stop без устройств
    0016-…-j606f-add-audio.patch  DTS звука J606F (audio.dtsi)
    config-j606f.fragment   опции ядра (HX83102, TPS65132, MM8013, NT36523, CHARGER_QCOM_PMI632, TOUCHSCREEN_HIMAX_HX83102E, TYPEC_FUSB302)
  himax83102p-port/         как получен 0006: port.py (исходники Lenovo → 7.2), make_patch.sh, Kconfig/Makefile
  dts/                     те же DTS отдельными файлами
pmaports/device/testing/
  linux-lenovo-j606f/      пакет ядра: linux-nura-qcom-sm61x5 7.2.3 + патчи 0001, 0003–0016 (pkgrel 118); своё имя, чтобы апстримный пакет его не заменил
  device-lenovo-j606f-nt36523w/  device-пакет ревизии NT36523W (не проверен)
  device-lenovo-j606f/     device-пакет (deviceinfo: rootfs → userdata, автозапись boot_b при обновлении; modules-initfs, прошивка GPU в initramfs, bootmac)
  firmware-lenovo-j606f/   firmware-пакет (APKBUILD — свой тарбол; APKBUILD.shared — общий набор S320208 из apk-репозитория)
pmaports/temp/hexagonrpcd/ hexagonrpcd 0.4.0-r50 с патчем: отдаёт ADSP файл sns_reg_version (нужно для датчиков SSC)
scripts/                   инструменты: разбор boot.img/dtbo/super, бэкап, отладочный initramfs,
                           сборка на самом планшете, прокси для USB-сети, установка
STATE.md                   ← НАЧАТЬ ЗДЕСЬ: текущее состояние, версии, следующий шаг
DEVICE.md                  всё про планшет: железо, разделы, режимы загрузки, статус
docs/
  DECISIONS.md             принятые решения и почему (подробно)
  COMMANDS.md              проверенные команды
  notes/                   заметки по подсистемам (display, touch, wifi_bt, power, audio, sensors, boot …)
```

> **Чего здесь нет и не будет:** дампов разделов, прошивок Lenovo, серийных номеров, MAC-адресов, ключей и паролей.
> Прошивки берутся с **вашего** устройства или из общего набора стока в apk-репозитории (см. ниже), но не из git.

## Сборка

### 1. Прошивки
Проще всего ничего не делать: `device-lenovo-j606f-nonfree-firmware` тянет `firmware-lenovo-j606f` из
[apk-репозитория](#обновления-через-apk-репозиторий). Это **общий набор стока S320208** (Android 11) с версией `0.320208`.
DSP-прошивку **вашего** планшета device-пакет (r16+) берёт из его собственных разделов и кладёт перед этим набором (см. ниже).
Свой бэкап нужен, только если хочется полностью свою прошивку. Пакет из него (`pkgver 1`) всегда главнее общего набора.

#### Свой бэкап
Нужен root (Magisk) в стоковом Android:
```bash
bash scripts/phase0_root.sh                 # сбор сведений
bash scripts/backup_partitions.sh           # полный бэкап, sha256 сверяется
bash scripts/collect_firmware.sh            # снять прошивки → FIRMWARE/<дата>/*.tar и сразу собрать тарбол
```
`collect_firmware.sh` (только чтение) снимает `/vendor/firmware_mnt`, `/vendor/firmware`, `/vendor/bt_firmware` и файлы датчиков,
затем [`scripts/build_firmware_package.sh`](scripts/build_firmware_package.sh) склеивает `.mdt` + `.bNN` → `.mbn`
([`pil_squash.py`](scripts/pil_squash.py)) и пишет `FIRMWARE/<дата>/firmware-lenovo-j606f-1.tar` с проверкой состава:
`qcom/sm6115/LENOVO/J606F/{a610_zap,adsp,cdsp,modem,venus,wlanmdsp}.mbn`, `qca/{crbtfw21.tlv,crnv21.bin}`,
`Himax_firmware.bin` и `Himax_mpfw.bin` (тач). Уже снятые архивы можно упаковать отдельно:
`bash scripts/build_firmware_package.sh FIRMWARE/<дата>`. `venus.mbn` нужен для аппаратного видео (ядро r115+).

Прошивки у разных планшетов различаются — ставьте только тарбол со **своего** устройства и не публикуйте его.

#### Прошивка с самого планшета
Её берёт `/usr/lib/j606f/firmware-extract` из device-lenovo-j606f (r12+; в r16 — нынешняя схема). Он запускается при установке и
обновлении device-пакета, apk-триггером при любой смене пакета прошивки и при каждой загрузке. Разделы монтируются только для
чтения, в них ничего не пишется:
- `modem_a/b` (NON-HLOS, остаётся от стока): `adsp`, `cdsp`, `modem`, `venus` (`.mdt` + `.bNN` → `.mbn` через `pil-squasher`), `wlanmdsp`;
- `bluetooth_a/b`: `qca/crbtfw21.tlv`, `qca/crnv21.bin`;
- `vendor_a/b` внутри super (`make-dynpart-mappings`, ext4 `ro,noload`): GPU `a610_zap`, тач `Himax_*.bin` и настройки усилителей динамиков
  `awinic/aw882xx_acf.bin` (r17+; без него звуковая карта ждёт файл и поднимется, как только он появится).

Если стоит общий набор (метка `/usr/share/j606f/firmware-shared`), файлы из `modem` и `bluetooth` идут в `/lib/firmware/updates`.
Ядро и tqftpserv ищут там раньше, поэтому DSP работают на прошивке своего стока. Это важно: с ADSP от другой версии Android
падают датчики. Проверено на планшете со стоком Android 10 (S120184) и установленным набором S320208: загрузились свои
ADSP/CDSP/WLAN/Venus, датчики работают. GPU и тач из vendor кладутся в `/lib/firmware`, только если их нет ни в одном пакете:
версии из набора работают на обоих стоках. С личным пакетом (`pkgver 1`) копии из `updates` удаляются, работает пакет как есть.

Super не трогается при установке в userdata. Если он перезаписан (ранние установки этого порта), GPU и тач берутся из пакета.
Что взято с планшета, записано в `/var/lib/j606f/firmware-extract.list`.

Свежий образ: на первой загрузке DSP стартуют с общим набором, а своя прошивка копируется в `updates` уже по ходу.
Поэтому после первой загрузки перезагрузите планшет ещё раз (в журнале: `running DSPs use the new firmware after the next reboot`).

### 2. pmaports
```bash
git clone https://gitlab.postmarketos.org/postmarketOS/pmaports.git
cp -r pmaports/device/testing/device-lenovo-j606f    <pmaports>/device/testing/
cp -r pmaports/device/testing/firmware-lenovo-j606f  <pmaports>/device/testing/
cp -r pmaports/device/testing/linux-lenovo-j606f    <pmaports>/device/testing/   # ядро 7.2.3 + патчи 0001, 0003–0016
cp -r pmaports/temp/hexagonrpcd                      <pmaports>/temp/              # для датчиков (см. docs/notes/sensors.md)
# прошивка: либо свой тарбол
cp firmware-lenovo-j606f-1.tar <pmaports>/device/testing/firmware-lenovo-j606f/
pmbootstrap checksum firmware-lenovo-j606f   # тарбол у каждого свой
# либо общий набор S320208 (тарбол скачается из https://repo.yarnick.ru/j606f/distfiles/, sha512 в APKBUILD)
cp <pmaports>/device/testing/firmware-lenovo-j606f/APKBUILD.shared <pmaports>/device/testing/firmware-lenovo-j606f/APKBUILD
```
> Пакет ядра здесь (`linux-lenovo-j606f`) — апстримный `linux-nura-qcom-sm61x5` 7.2.3 с добавленными патчами из [`kernel/patches/`](kernel/patches/) и опциями
> из `config-j606f.fragment`. Первая установка делалась иначе: бинарное ядро 7.2.3-r0 + модули/DTB, собранные отдельно
> ([`scripts/device_build_inner.sh`](scripts/device_build_inner.sh));
этот путь больше не используется.

### 3. pmbootstrap
```bash
pmbootstrap init         # device: lenovo-j606f
pmbootstrap install
pmbootstrap export
```
Проверено на x86_64 Ubuntu 22.04 (ядро собирается cross-native) и **на самом планшете** (aarch64, под mainline, в chroot на userdata,
[`scripts/device_pmb_env.sh`](scripts/device_pmb_env.sh)). Если зеркало медленное, поможет кэширующий прокси
[`scripts/mirror_proxy.py`](scripts/mirror_proxy.py) на соседнем компьютере.

## Установка

> **Ревизия с панелью Novatek NT36523W** (`dsi_display0=…nt36523w…`): отдельный device `lenovo-j606f-nt36523w`,
> инструкция — [`docs/notes/install_nt36523w.md`](docs/notes/install_nt36523w.md) (в железе пока не проверено, тача нет).

Рекомендуемая схема: **rootfs в userdata** (~100 ГиБ), boot.img в **boot_b**, dtbo_b стёрт, слот a не трогаем.
**userdata стирается целиком** (данные Android пропадут).
```bash
fastboot flash userdata lenovo-j606f.img   # rootfs (pmOS_boot + pmOS_root), образ sparse: только fastboot, не dd!
fastboot boot boot.img                     # проверка ядра без записи (fastboot boot — 1 раз за сессию bootloader)
# если загрузилось: снова в fastboot (reboot bootloader из Linux или Vol− + Power), затем
fastboot flash boot_b boot.img             # userdata и boot_b — из одного pmbootstrap install (UUID)
fastboot erase dtbo_b                      # ABL перестаёт накладывать стоковый оверлей
fastboot --set-active=b && fastboot reboot
```
С device-пакетом r6 `pmbootstrap flasher flash_rootfs` сам пишет в userdata (`deviceinfo_flash_fastboot_partition_rootfs="userdata"`).
- **Не держите pmOS-разметку сразу в двух разделах.** initramfs берёт первый раздел с двумя подразделами в порядке
  `/proc/diskstats`, а super (sda14) идёт раньше userdata (sda15). На чистом устройстве в super лежат разделы Android, это не мешает.
  Если раньше ставили pmOS в super, удалите там GPT ([install_plan](docs/notes/install_plan.md)).
- Этот порт сначала стоял в super и был перенесён в userdata поблочно ([install_plan](docs/notes/install_plan.md)). Чистую установку сразу в userdata по командам выше
  мы не проверяли: если корень не занял весь раздел, растяните его (`sfdisk`/`resize2fs`).

Подробно, с откатом: [`docs/notes/install_plan.md`](docs/notes/install_plan.md).
[`scripts/device_install_pmos.sh`](scripts/device_install_pmos.sh) — старый скрипт установки в **super** из запущенного mainline (история).

## Обновления через apk-репозиторий

Собранные пакеты порта (ядро, device-пакеты, hexagonrpcd) лежат в подписанном apk-репозитории
**https://repo.yarnick.ru/j606f** (ключ `pmos@local-6ae27901`). Репозиторий ведёт [@nnshould](https://t.me/nnshould) (Telegram) — по вопросам о нём писать туда.
Там же лежит общий набор прошивок стока S320208: `firmware-lenovo-j606f-0.320208` (Android 11; исходный тарбол — в `j606f/distfiles/`).
Он нужен тем, у кого нет своего бэкапа. Личная сборка (`1-rN`) всегда новее, apk её не заменит.

**С device-lenovo-j606f r18 настраивать ничего не нужно:** device-пакет сам кладёт адрес репозитория
(`/usr/lib/apk/repositories.d/j606f.list`) и его ключ (`/usr/lib/apk/keys/`), apk 3 читает их наравне с `/etc/apk`.
Образ, собранный из этого pmaports, обновляется обычным `apk upgrade` с первой загрузки.
Метка `@j606f` больше не нужна: ядро порта называется `linux-lenovo-j606f`, и ни один пакет из обычных репозиториев его не заменит.

Переход для установок с device ≤ r17 (один раз; ключ из прошлых инструкций у вас уже есть, иначе — первая строка):
```bash
[ -f /etc/apk/keys/pmos@local-6ae27901.rsa.pub ] || sudo wget -O /etc/apk/keys/pmos@local-6ae27901.rsa.pub https://repo.yarnick.ru/pmos@local-6ae27901.rsa.pub
echo "https://repo.yarnick.ru/j606f" | sudo tee -a /etc/apk/repositories
sudo apk update
sudo apk add linux-lenovo-j606f device-lenovo-j606f device-lenovo-j606f-nonfree-firmware
sudo /usr/lib/j606f/repo-migrate
sudo reboot
```
`repo-migrate` убирает из `/etc/apk/repositories` старую строку `@j606f …` (и временную строку выше: адрес теперь в device-пакете),
а из `/etc/apk/world` — `linux-nura-qcom-sm61x5`, метки `@j606f` и закрепления версий пакетов порта; затем `apk upgrade`
удаляет старый пакет ядра (его файлы уже принадлежат `linux-lenovo-j606f`). Копии исходных файлов — `*.before-j606f-<время>` рядом.
Ревизия **NT36523W**: вместо `device-lenovo-j606f` и его `-nonfree-firmware` — `device-lenovo-j606f-nt36523w device-lenovo-j606f-nt36523w-nonfree-firmware`
(device-пакеты двух ревизий вместе не ставятся, см. [install_nt36523w](docs/notes/install_nt36523w.md)).
`hexagonrpcd` ставьте, только если настроены датчики (без drop-in'ов с `-R` ADSP падает в цикле, см. [датчики](docs/notes/sensors.md)).
Он сохранил апстримное имя: наша сборка 0.4.0-r50 (патч `sns_reg_version`) выше Alpine 0.4.0-r3, но если в Alpine выйдет 0.4.1,
apk поставит её и патч пропадёт (датчики, не загрузка) — пока патч не принят в hexagonrpc, после такого обновления проверяйте датчики.

Обновление:
```bash
sudo apk update && sudo apk upgrade && sudo reboot
```
С **device-lenovo-j606f r16** DSP-прошивка своего стока (в т. ч. `venus.mbn` для видео) берётся из разделов самого планшета и
стоит перед общим набором, см. [Прошивки](#1-прошивки). Если общий набор ставится этим же обновлением, хватает одной перезагрузки.
С **device-lenovo-j606f r7** включён `deviceinfo_flash_kernel_on_update`: после обновления ядра или initramfs boot-deploy сам пишет
`boot.img` в `boot` + суффикс текущего слота (`boot_b`) — в выводе apk видно `Flashing boot.img to 'boot_b'`. Ручной `dd` больше не нужен
(на device ≤ r6 — нужен: `sudo dd if=/boot/boot.img of=/dev/disk/by-partlabel/boot_b bs=4M conv=fsync`).
Если новое ядро не загрузится или питание пропало во время записи — в fastboot (Vol− + Power) `fastboot flash boot_b <прошлый boot.img>`;
перед обновлением ядра удобно сохранить копию: `sudo head -c $(stat -c %s /boot/boot.img) /dev/disk/by-partlabel/boot_b > ~/boot_b-backup.img`.
Проверка после перезагрузки: `uname -v` показывает `#<pkgrel+1>-nura-qcom-sm61x5` (например, r118 → `#119`), `apk list -I | grep -E 'device-lenovo|linux-lenovo'` — device r20 и linux-lenovo-j606f r118 или новее.
Звук: `pactl list short sinks` показывает `alsa_output.platform-sound.HiFi__Speaker__sink`.
В репозиторий попадают пакеты порта и ровно один пакет прошивки — общий набор S320208, сверенный по sha256 при публикации.
Любые другие firmware, в том числе личные сборки с бэкапов, и всё с `license = proprietary` отсекаются.

## Откат на Android
- Перед любой записью сделайте полный бэкап ([`scripts/backup_partitions.sh`](scripts/backup_partitions.sh)).
- `fastboot --set-active=a` вернёт загрузку со слота a, если он не трогался.
- Полный откат: EDL + [qdl](https://github.com/linux-msm/qdl) и стоковая прошивка Lenovo (см. вики postmarketOS для этого устройства).

## Отладочная среда без rootfs

Для bring-up без установки: [`scripts/make_debug_bootimg.py`](scripts/make_debug_bootimg.py) собирает boot.img
(header v2) из готового ядра, DTB и маленького initramfs на busybox:
- USB-гаджет ECM (сеть) + ACM (`/dev/cu.usbmodem*` на macOS), link-local адрес 169.254.42.1;
- nc-shell на порту 9100 ([`scripts/tcp_run.sh`](scripts/tcp_run.sh)), ACM-shell ([`scripts/acm_run.py`](scripts/acm_run.py));
- страховочный `reboot -f` через 300 с без контакта с хостом;
- `scripts/cycle_boot.sh`: перезагрузка → bootloader → `fastboot boot` → ожидание сети.

## Известные проблемы и планы
- **Тач:** работает (порт драйвера Lenovo из [adazem009/kernel_lenovo_tbj606](https://github.com/adazem009/kernel_lenovo_tbj606), патч 0006). Перо не проверено. [Заметки](docs/notes/touch.md).
- **Звук:** динамики работают (r117). Дальше — микрофоны ES7210 (порт драйвера Lenovo) и аналоговая гарнитура через USB-C (FSA4480). Защиты динамиков стока (алгоритм на ADSP) в mainline нет, поэтому громкость усилителей ограничена. Изредка после загрузки ADSP поднимается не до конца и звуковой карты нет — помогает перезагрузка. [Заметки](docs/notes/audio.md).
- **Датчики:** работают; осталось подобрать `ACCEL_MOUNT_MATRIX` для автоповорота и упаковать файлы SSC. [Заметки](docs/notes/sensors.md).
- **Хранилище:** корень pmOS в userdata (~100 ГиБ), см. [install_plan](docs/notes/install_plan.md).
- **Зарядник:** заряжает, но драйвер только читает. Дальше — лимит входа по Type-C/APSD (сейчас 1.5 А даже от зарядника на 3 А), порог заряда, JEITA; быстрая зарядка (PD/QC, параллельный SMB1355) — отдельная большая работа. [Заметки](docs/notes/power.md).
- **Сон:** r110/r111 и ручной helper дают успешный s2idle, но требуется полная проверка ADSP/датчиков и упаковка. **Офлайн-зарядка:** device r11 реализует charger mode, осталось финальное тестирование unplug/poweroff.
- **Venus:** аппаратное H.264/HEVC-декодирование работает (0011/r115), но в mpv `hwdec=v4l2m2m-copy` теряет кадры на выводе (1080p30 ~180 из 360, 1080p60 ~550 из 720) — дорогое копирование кадров обратно; zero-copy (`v4l2m2m`) mpv здесь не поднимает. VA-API/Firefox и энкодер пока не проверялись.
- **Vulkan и vsync:** Vulkan-приложения в режиме FIFO (vsync) получают 48 кадров/с вместо 60 (каждый 5-й vblank пропускается; Mesa 26.2 + KWin 6.8, протокол wp_fifo_v1); OpenGL — честные 60. Причина пока не найдена.
- Клавиатура на pogo-пинах, датчик Холла, вибромотор/светодиод, камеры, заводские MAC из persist (сейчас bootmac генерирует стабильные из serialno).
- **Настройки по умолчанию** (автологин, ландшафт, кнопка Power, экранная клавиатура, drop-in'ы hexagonrpcd) пока сделаны вручную на планшете, в пакеты не перенесены (STATE.md §2).
- **Зеркала:** если mirror.nura.eco медленный, задайте другие (у нас из России быстро работают эти):
  ```bash
  pmbootstrap config mirrors.alpine   http://mirror.yandex.ru/mirrors/alpine/
  pmbootstrap config mirrors.pmaports https://mirror.minlexx.ru/postmarketos/
  pmbootstrap config mirrors.systemd  https://mirror.minlexx.ru/postmarketos/extra-repos/systemd/
  ```
  Официальный список: https://nura.eco/mirrors/ (например, RWTH Aachen). Зеркала git: `newgit.minlexx.ru/alexeymin/{pmaports,pmbootstrap}-mirror`.
- Апстрим: DTS ревизии HX83102P и панель → LKML; пакеты → pmaports (с учётом
  [AI policy postmarketOS](https://docs.postmarketos.org/policies-and-processes/development/ai-policy.html)).

## Благодарности и лицензии
- Автор порта, сборки и apk-репозитория: [@nnshould](https://t.me/nnshould) (Telegram, GitHub Yar1klamer).
- Mainline-поддержка SM6115 и исходный DTS `sm6115p-lenovo-j606f.dts`: Linaro, Konrad Dybcio и сообщество linux-msm.
- Ядро `linux-nura-qcom-sm61x5`: [sm61x5-mainline](https://codeberg.org/sm61x5-mainline/linux), Barnabás Czémán.
- Драйвер `panel-himax-hx83102`: Cong Yang и др.; postmarketOS/Nura, pmbootstrap, Mesa freedreno.
- За помощь тестирования и нахождения багов в порте - @dogotrigger ( Telegram )

Лицензии:
- патчи ядра и DTS: **GPL-2.0** (DTS: GPL-2.0+ OR BSD-3-Clause, как в исходниках);
- скрипты и документация этого репозитория: **MIT** ([LICENSE](LICENSE));
- прошивки Lenovo/Qualcomm проприетарные и **в git-репозиторий не входят**; общий набор стока S320208 раздаётся только
  apk-репозиторием в виде стоковых образов (только `.mdt` + `.bNN` склеены в `.mbn`).

> ⚠️ Вы делаете всё на свой страх и риск. Разблокировка загрузчика и прошивка могут привести к потере данных
> или неработоспособности устройства. Никогда не трогайте `modem*`, `persist`, `fsg`, `xbl`, `abl` без бэкапа.
