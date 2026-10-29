# postmarketOS для Lenovo Tab P11 (TB-J606F)

Порт [postmarketOS](https://postmarketos.org) (с 2026 года проект называется **Nura**) на планшет
**Lenovo Tab P11 TB-J606F** (Wi-Fi) на основе **mainline-ядра Linux 7.2**
([linux-nura-qcom-sm61x5](https://codeberg.org/sm61x5-mainline/linux)).

> **Статус: pmOS (Nura edge) с KDE Plasma Desktop ставится во внутреннюю память и грузится сам.** Работают дисплей, GPU (OpenGL ES и Vulkan),
> Plasma (Wayland), Wi-Fi, **Bluetooth (полностью: сопряжение и устройства ввода)**, USB-сеть/SSH, кнопки, батарея и статус зарядки.
> Тача, звука и датчиков пока нет: управление Bluetooth-мышью/клавиатурой, текст — экранной клавиатурой. Подробности ниже и в [STATE.md](STATE.md).

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

Проверено на mainline 7.2.3 через `fastboot boot`. Доказательства (команды и вывод) в [WORKLOG.md](WORKLOG.md).

| Подсистема | Статус | Примечание |
|---|---|---|
| Загрузка ядра | ✅ | со стёртым `dtbo` (или через «отстойник» для стокового dtbo, см. ниже) |
| UFS, разметка | ✅ | |
| Дисплей HX83102P + подсветка | ✅ | свой драйвер панели (init из стокового DT), 60 Гц, DCS-яркость 0…4095 |
| GPU Adreno 610 | ✅ | Mesa freedreno (GLES 3.2, kmscube 60 fps) и **Vulkan** через turnip (`mesa-vulkan-freedreno`) |
| Wayland, KDE Plasma Desktop | ✅ | weston и Plasma (kwin_wayland) на GPU, 60 Гц; автологин и ландшафт настраиваются вручную |
| Экранная клавиатура | ✅ | plasma-keyboard (EN/RU), значок на панели; см. [NOTES.md](NOTES.md) п. 39 |
| Кнопки Power, Vol± | ✅ | Power гасит/включает экран (настройка PowerDevil) |
| USB-сеть, SSH | ✅ | гаджет ECM/ACM |
| Wi-Fi | ✅ | ath10k (WCN3990): подключение WPA2, DHCP, интернет |
| Bluetooth | ✅ полностью | WCN3990 (btqca): поиск, сопряжение, HID-устройства (проверено с мышью); постоянный адрес задаёт bootmac |
| Батарея | ✅ | fuel gauge mm8013 (патч 0005: правильный знак тока по ABI, связь с зарядником, Li-ion) — Plasma/UPower показывают заряд/разряд верно |
| cpufreq, thermal, троттлинг CPU | ✅ | cooling-maps добавлены в DTS |
| Modem / ADSP / CDSP | ✅ стартуют | стоковые прошивки |
| Перезагрузка в bootloader | ✅ | reboot-mode PON |
| Тачскрин и стилус | ❌ | нет mainline-драйвера HX83102E |
| Звук | ❌ | нет драйверов AW88258, ES7210 |
| Датчики (поворот, свет) | ❌ | hexagonrpcd/SSC пока не поднялся |
| Зарядник PMI632 | ⚠️ только статус | свой read-only драйвер (патч 0004): онлайн, статус, тип USB, лимиты; заряд на настройках загрузчика (4.40 В / 3 А). SMB1355 нет |
| Suspend, камеры, клавиатура | ❓ | не проверялось |

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
  patches/                 патчи к linux-nura-qcom-sm61x5 7.2.3
    0001-…-HX83102P.patch   панель BOE/Himax HX83102P в panel-himax-hx83102.c
    0002-HACK-…patch        qcom,bengalp для ubwc_config/pd_mapper (только если dtbo не стёрт; в пакет не входит)
    0003-…-HX83102P-SKU.patch  DTS ревизии HX83102P + abl-sink.dtsi + Makefile
    0004-…-PMI632-charger…patch  read-only драйвер зарядника PMI632 (SMB5) + узел в DTS
    0005-…-mm8013-…patch      mm8013: знак current_now, power-supplies → зарядник, TECHNOLOGY=Li-ion
    config-j606f.fragment   опции ядра (HX83102, TPS65132, MM8013, NT36523, CHARGER_QCOM_PMI632)
  dts/                     те же DTS отдельными файлами
pmaports/device/testing/
  linux-nura-qcom-sm61x5/  пакет ядра 7.2.3 с патчами 0001, 0003, 0004, 0005 (pkgrel 105)
  device-lenovo-j606f/     device-пакет (deviceinfo, modules-initfs, прошивка GPU в initramfs, bootmac)
  firmware-lenovo-j606f/   firmware-пакет (APKBUILD; блобы вы извлекаете со своего устройства)
scripts/                   инструменты: разбор boot.img/dtbo/super, бэкап, отладочный initramfs,
                           сборка на самом планшете, прокси для USB-сети, установка
STATE.md                   ← НАЧАТЬ ЗДЕСЬ: текущее состояние, пути, версии, следующий шаг
WORKLOG.md                 полная хронология (команды, вывод, ошибки, тупики)
DEVICE.md                  всё про планшет: железо, разделы, режимы загрузки, статус
NOTES.md                   решения, грабли, команды, ссылки, TODO
docs/
  DECISIONS.md             принятые решения и почему (подробно)
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
cp -r pmaports/device/testing/device-lenovo-j606f    <pmaports>/device/testing/
cp -r pmaports/device/testing/firmware-lenovo-j606f  <pmaports>/device/testing/
cp -r pmaports/device/testing/linux-nura-qcom-sm61x5 <pmaports>/device/testing/   # ядро 7.2.3 + патчи 0001–0003 (pkgrel 101)
cp firmware-lenovo-j606f-1.tar <pmaports>/device/testing/firmware-lenovo-j606f/
pmbootstrap checksum firmware-lenovo-j606f   # тарбол у каждого свой
```
> Пакет ядра здесь — апстримный `linux-nura-qcom-sm61x5` 7.2.3 с добавленными патчами из [`kernel/patches/`](kernel/patches/) и опциями
> из `config-j606f.fragment`. Первая установка делалась иначе: бинарное ядро 7.2.3-r0 + модули/DTB, собранные отдельно
> ([`scripts/device_build_inner.sh`](scripts/device_build_inner.sh)); этот путь описан в [WORKLOG.md](WORKLOG.md).

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

Рекомендуемая схема: **слот b** под pmOS, слот a не трогаем.
```bash
fastboot flash super lenovo-j606f.img      # rootfs (pmOS_boot + pmOS_root), образ sparse: только fastboot, не dd!
fastboot boot boot.img                     # проверка ядра без записи (fastboot boot — 1 раз за сессию bootloader)
# если загрузилось: снова в fastboot (reboot bootloader из Linux или Vol− + Power), затем
fastboot flash boot_b boot.img             # super и boot_b — из одного pmbootstrap install (UUID)
fastboot erase dtbo_b                      # ABL перестаёт накладывать стоковый оверлей
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
- **Зарядник:** запись лимитов (ток от сетевого адаптера, JEITA), параллельный SMB1355 — после проверки read-only драйвера.
- **suspend**, кнопки, клавиатура на pogo-пинах, заводские MAC из persist (сейчас bootmac генерирует стабильные из serialno).
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
- Mainline-поддержка SM6115 и исходный DTS `sm6115p-lenovo-j606f.dts`: Linaro, Konrad Dybcio и сообщество linux-msm.
- Ядро `linux-nura-qcom-sm61x5`: [sm61x5-mainline](https://codeberg.org/sm61x5-mainline/linux), Barnabás Czémán.
- Драйвер `panel-himax-hx83102`: Cong Yang и др.; postmarketOS/Nura, pmbootstrap, Mesa freedreno.

Лицензии:
- патчи ядра и DTS: **GPL-2.0** (DTS: GPL-2.0+ OR BSD-3-Clause, как в исходниках);
- скрипты и документация этого репозитория: **MIT** ([LICENSE](LICENSE));
- прошивки Lenovo/Qualcomm проприетарные и **в репозиторий не входят**.

> ⚠️ Вы делаете всё на свой страх и риск. Разблокировка загрузчика и прошивка могут привести к потере данных
> или неработоспособности устройства. Никогда не трогайте `modem*`, `persist`, `fsg`, `xbl`, `abl` без бэкапа.
