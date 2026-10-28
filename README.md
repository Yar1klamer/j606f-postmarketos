# postmarketOS для Lenovo Tab P11 (TB-J606F)

Порт [postmarketOS](https://postmarketos.org) (с 2026 года проект называется **Nura**) на планшет
**Lenovo Tab P11 TB-J606F** (Wi-Fi) на основе **mainline-ядра Linux 7.2**
([linux-nura-qcom-sm61x5](https://codeberg.org/sm61x5-mainline/linux)).

> **Статус: ранний bring-up.** Ядро, дисплей, GPU, Wayland, Wi-Fi, Bluetooth и USB-сеть работают;
> тача, звука и датчиков пока нет. Как повседневная система ещё не годится. Подробности ниже и в [docs/STATE.md](docs/STATE.md).

![weston на TB-J606F (снимок буфера композитора)](docs/img/weston_screenshot.png)

---

## Содержание
- [Устройство](#устройство)
- [Что работает](#что-работает)
- [Главная особенность: загрузчик Lenovo и dtbo](#главная-особенность-загрузчик-lenovo-и-dtbo)
- [Структура репозитория](#структура-репозитория)
- [Сборка](#сборка)
- [Установка](#установка)
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
| Экран | 11", 2000×1200, **две ревизии**: BOE + Novatek NT36523W или **BOE + Himax HX83102P** (этот порт) |
| Тач | Himax HX83102E (zero-flash, SPI) + стилус; у второй ревизии Novatek |
| Wi-Fi / BT | WCN3990 (ath10k_snoc / btqca) |
| Батарея | 7500 мА·ч, fuel gauge MM8013, зарядник PMI632 + SMB1355 |
| Звук | 4× Awinic AW88258, ES7210, WCD937x / PM2250 |
| Датчики | через Qualcomm SSC (ADSP): ICM4x6xx, LTR578, TMF8801, SX932x |

Ревизия определяется по `/proc/cmdline` стокового Android:
`msm_drm.dsi_display0=qcom,mdss_dsi_himax83102p_boe_2k_video` означает ревизию Himax (этот порт).

## Что работает

Проверено на mainline 7.2.3 через `fastboot boot`. Доказательства (команды и вывод) в [docs/WORKLOG.md](docs/WORKLOG.md).

| Подсистема | Статус | Примечание |
|---|---|---|
| Загрузка ядра | ✅ | через «отстойник» для стокового dtbo (см. ниже) |
| UFS, разметка | ✅ | |
| Дисплей HX83102P + подсветка | ✅ | свой драйвер панели (init из стокового DT), 60 Гц, DCS-яркость 0…4095 |
| GPU Adreno 610 | ✅ | Mesa freedreno, GLES 3.2, kmscube 60 fps |
| Wayland (weston) | ✅ | DRM + GL, 60 fps |
| USB-сеть, SSH | ✅ | гаджет ECM/ACM |
| Wi-Fi | ✅ сканирование | ath10k, подключение не проверено |
| Bluetooth | ✅ сканирование | btqca, нужен ручной BD-адрес |
| Батарея | ✅ | mm8013; заряд идёт на аппаратных настройках |
| cpufreq, thermal, троттлинг CPU | ✅ | cooling-maps добавлены в DTS |
| Modem / ADSP / CDSP | ✅ стартуют | стоковые прошивки |
| Перезагрузка в bootloader | ✅ | reboot-mode PON |
| Тачскрин и стилус | ❌ | нет mainline-драйвера HX83102E |
| Звук | ❌ | нет драйверов AW88258, ES7210 |
| Датчики (поворот, свет) | ❌ | hexagonrpcd/SSC пока не поднялся |
| Зарядник (управление) | ❌ | нет драйвера PMI632/SMB1355 |
| Suspend, камеры, клавиатура | ❓ | не проверялось |

## Главная особенность: загрузчик Lenovo и dtbo

ABL этого планшета **всегда** накладывает оверлей из раздела `dtbo` (запись «Lenovo P11 WIFI PVT») на DTB из boot.img.
В mainline DTB нет `__symbols__`, наложение не удаётся, и ABL отвечает `Booting OKAY`, но ядро не запускает.

Решение без записи в `dtbo`:
[`kernel/dts/sm6115p-lenovo-j606f-abl-sink.dtsi`](kernel/dts/sm6115p-lenovo-j606f-abl-sink.dtsi) добавляет выключенный узел `/abl-sink`
с узлом-phandle на каждую метку из `__fixups__` стокового оверлея (138 штук) и `__symbols__`, которые указывают на эти узлы.
Оверлей ложится в «отстойник», ядро его не трогает. Генератор: [`scripts/gen_abl_sink_dtsi.py`](scripts/gen_abl_sink_dtsi.py).

Побочный эффект: ABL заменяет корневые `model`/`compatible` на `qcom,bengalp-idp`. Из-за этого `ubwc_config` и `qcom_pd_mapper`
не узнают SoC. Временно это обходит патч `0002-HACK` (добавляет `qcom,bengalp`). Чистое решение — прошить пустой dtbo
([`docs/notes/install_plan.md`](docs/notes/install_plan.md)).

Ещё одна особенность: `fastboot boot` работает **один раз за сессию bootloader**. Перед каждой попыткой нужен `fastboot reboot bootloader`.

## Структура репозитория

```
kernel/
  patches/                 патчи к linux-nura-qcom-sm61x5 7.2.3
    0001-…-HX83102P.patch   панель BOE/Himax HX83102P в panel-himax-hx83102.c
    0002-HACK-…patch        qcom,bengalp для ubwc_config/pd_mapper (обход ABL)
    0003-…-HX83102P-SKU.patch  DTS ревизии HX83102P + abl-sink.dtsi + Makefile
    config-j606f.fragment   опции ядра (HX83102, TPS65132, MM8013, NT36523)
  dts/                     те же DTS отдельными файлами
pmaports/device/testing/
  device-lenovo-j606f/     device-пакет (deviceinfo, modules-initfs, APKBUILD)
  firmware-lenovo-j606f/   firmware-пакет (APKBUILD; блобы вы извлекаете со своего устройства)
scripts/                   инструменты: разбор boot.img/dtbo/super, бэкап, отладочный initramfs,
                           сборка на самом планшете, прокси для USB-сети, установка
docs/
  STATE.md                 текущее состояние и чек-лист
  WORKLOG.md               полный журнал работ (команды, вывод, результат)
  DECISIONS.md             принятые решения и почему
  DEVICE_INFO.md           факты об устройстве
  COMMANDS.md              проверенные команды
  notes/                   заметки по подсистемам (display, touch, wifi_bt, power, audio, sensors, boot …)
```

> **Чего здесь нет и не будет:** дампов разделов, прошивок Lenovo, серийных номеров, MAC-адресов, ключей и паролей.
> Прошивки извлекаются с **вашего** устройства (см. ниже).

## Сборка

### 1. Прошивки со своего устройства
Нужен root (Magisk) в стоковом Android:
```bash
bash scripts/phase0_root.sh                 # сбор сведений
bash scripts/backup_partitions.sh           # полный бэкап, sha256 сверяется
# прошивки: /vendor/firmware_mnt (modem_a), /vendor/firmware, /vendor/bt_firmware
python3 -I scripts/pil_squash.py adsp.mbn  image/adsp.mdt      # .mdt + .bNN → .mbn
python3 -I scripts/pil_squash.py cdsp.mbn  image/cdsp.mdt
python3 -I scripts/pil_squash.py modem.mbn image/modem.mdt
python3 -I scripts/pil_squash.py a610_zap.mbn a610_zap.mdt
```
Из них собирается `firmware-lenovo-j606f-1.tar` (раскладка в APKBUILD пакета):
`qcom/sm6115/LENOVO/J606F/{a610_zap,adsp,cdsp,modem,wlanmdsp}.mbn`, `qca/{crbtfw21.tlv,crnv21.bin}`.

### 2. pmaports
```bash
git clone https://gitlab.postmarketos.org/postmarketOS/pmaports.git
cp -r pmaports/device/testing/device-lenovo-j606f   <pmaports>/device/testing/
cp -r pmaports/device/testing/firmware-lenovo-j606f <pmaports>/device/testing/
cp firmware-lenovo-j606f-1.tar <pmaports>/device/testing/firmware-lenovo-j606f/
# ядро: добавить kernel/patches/000*.patch в source= пакета linux-nura-qcom-sm61x5,
# применить config-j606f.fragment к его config, затем:
pmbootstrap checksum linux-nura-qcom-sm61x5 device-lenovo-j606f firmware-lenovo-j606f
```
> Временный вариант (в этом репозитории): device-пакет кладёт уже собранные модули и DTB поверх бинарного
> `linux-nura-qcom-sm61x5 7.2.3-r0`, чтобы не пересобирать ядро. Модули и DTB собираются скриптом
> [`scripts/device_build_inner.sh`](scripts/device_build_inner.sh).

### 3. pmbootstrap
```bash
pmbootstrap init         # device: lenovo-j606f
pmbootstrap install
pmbootstrap export
```
Проверено, что pmbootstrap 3.12 работает **на самом планшете** (aarch64, под mainline, в chroot на userdata)
с зеркалами через HTTP-прокси на соседнем компьютере ([`scripts/device_pmb_env.sh`](scripts/device_pmb_env.sh),
[`scripts/mirror_proxy.py`](scripts/mirror_proxy.py)).

## Установка

Рекомендуемая схема: **слот b** под pmOS, слот a не трогаем.
```bash
fastboot boot boot.img                     # сначала всегда проверка без записи
fastboot flash boot_b boot.img
# rootfs-образ (pmOS_boot + pmOS_root) → super или userdata;
# initramfs pmOS сам найдёт подразделы (losetup -P, sector size 4096)
fastboot --set-active=b && fastboot reboot
```
Подробно, с откатом: [`docs/notes/install_plan.md`](docs/notes/install_plan.md), скрипт с проверкой разделов и sha256:
[`scripts/device_install_pmos.sh`](scripts/device_install_pmos.sh).

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
- **Тач HX83102E:** нужны GPL-исходники Himax «hxchipset» (в стоковом ядре драйвер встроен: `himax_mcu_firmware_update_0f`, `hx83102e_*`). [Заметки](docs/notes/touch.md).
- **Звук:** драйвер AW88258 (ID 0x1852) и ES7210, машинный драйвер для SM6115. [Заметки](docs/notes/audio.md).
- **Датчики:** раскладка файлов hexagonrpcd / libssc. [Заметки](docs/notes/sensors.md).
- **dtbo:** проверить пустой dtbo вместо «отстойника» и убрать HACK 0002.
- **MAC Wi-Fi/BT** из persist, **зарядник**, **suspend**, клавиатура на pogo-пинах.
- Апстрим: DTS ревизии HX83102P и панель → LKML; пакеты → pmaports (с учётом
  [AI policy postmarketOS](https://docs.postmarketos.org/policies-and-processes/development/ai-policy.html)).

## Благодарности и лицензии
- Mainline-поддержка SM6115 и исходный DTS `sm6115p-lenovo-j606f.dts`: Linaro, Konrad Dybcio и сообщество linux-msm.
- Ядро `linux-nura-qcom-sm61x5`: [sm61x5-mainline](https://codeberg.org/sm61x5-mainline/linux), Barnabás Czémán.
- Драйвер `panel-himax-hx83102`: Cong Yang и др.; postmarketOS/Nura, pmbootstrap, Mesa freedreno.

Лицензии:
- патчи ядра и DTS: **GPL-2.0** (DTS: GPL-2.0+ OR BSD-3-Clause, как в исходниках);
- скрипты и документация этого репозитория: **MIT** ([LICENSE](LICENSE));
- прошивки Lenovo/Qualcomm проприетарные и **в репозиторий не входят**.

> ⚠️ Вы делаете всё на свой страх и риск. Разблокировка загрузчика и прошивка могут привести к потере данных
> или неработоспособности устройства. Никогда не трогайте `modem*`, `persist`, `fsg`, `xbl`, `abl` без бэкапа.
