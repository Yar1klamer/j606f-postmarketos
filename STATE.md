# STATE — где мы остановились (2026-10-29, ночь)

> Читать первым после потери контекста. Полная хронология: [WORKLOG.md](WORKLOG.md). Устройство: [DEVICE.md](DEVICE.md).
> Решения, команды, грабли, TODO: [NOTES.md](NOTES.md). Подробные заметки по подсистемам: `docs/notes/*.md`.

## 1. Одной строкой
**pmOS (Nura edge) с KDE Plasma Desktop установлен во внутреннюю память и грузится сам** на Lenovo Tab P11 TB-J606F (ревизия Himax HX83102P):
rootfs в `super`, boot.img в `boot_b`, **dtbo_b стёрт**, активный слот **b**. Ядро — наша сборка linux-nura-qcom-sm61x5 7.2.3 **pkgrel 103** (патчи 0001, 0003, 0004; без HACK 0002).
Автологин в Plasma, альбомная ориентация, Wi-Fi подключён, батарея и зарядник видны, Bluetooth включается сам. Тача, звука и датчиков нет.

## 2. Состояние устройства прямо сейчас
| Что | Значение |
|---|---|
| Что запущено | pmOS + Plasma Desktop (автологин user), обычная загрузка со слота b |
| Активный слот | **b** (`slot-successful:b` = yes) |
| boot_a | стоковый boot + Magisk; стоковый оригинал в приватном бэкапе |
| boot_b | `/boot/boot.img` с самого планшета (ядро r103, device r5), записан `dd` в `/dev/disk/by-partlabel/boot_b` |
| dtbo_b | **стёрт** (`fastboot erase dtbo_b`): ABL не накладывает оверлей, compatible = `lenovo,j606f` |
| dtbo_a, vbmeta_a / vbmeta_b | стоковые |
| super (12 ГиБ) | rootfs pmOS с Plasma (образ ~4.1 ГБ, sparse), прошит `fastboot flash super`; внутри GPT с секторами 4096: pmOS_boot + pmOS_root |
| userdata (102 ГиБ) | ext4 `j606f_work`: старое рабочее место pmbootstrap на планшете |
| Android | **не загрузится** (super перезаписан) — с согласия владельца |
| modem*/persist/fsg/abl/xbl | не трогали (rmtfs в pmOS пишет EFS в modemst1/2, fsg — штатно) |
| Доступ | `ssh user@172.16.42.1` (USB) или по Wi-Fi; на планшете `sudo` без пароля для user и автологин (локальная настройка, **не в образе**) |

Локальные настройки на планшете (пропадут при полной переустановке образа):
- kscreen: DSI-1 `rotation.left` (ландшафт), масштаб 1.4;
- `systemctl mask iio-sensor-proxy` (дёргал ADSP раз в секунду, датчики пока не работают);
- `/etc/apk/repositories`: pmOS-зеркало **RWTH Aachen** (`https://ftp.halifax.rwth-aachen.de/postmarketos/…`) + Alpine dl-cdn; mirror.nura.eco из этой сети отдаёт ~500 Б/с.

## 3. Следующий шаг
1. Bluetooth: сопряжение клавиатуры/мыши (адрес теперь задаёт bootmac, контроллер powered).
2. Кнопки (Power/Vol±) — проверить нажатия (`evtest`), suspend/resume.
3. Зарядник, шаг 2: запись лимитов (ICL под сетевой адаптер, JEITA), только после проверки от адаптера.
4. Звук (AW88258, ES7210), датчики (hexagonrpcd/SSC), тач (нужны исходники Himax hxchipset или разбор стокового драйвера).
5. В образ: автологин/ориентация по умолчанию для планшета (решить, что из этого место в device-пакете).

## 4. Как обновлять без переустановки (проверено 29.10)
Полная переустановка (`pmbootstrap install` + `fastboot flash super/boot_b`) сбрасывает локальные настройки и требует fastboot. Вместо неё:
1. На сборочном хосте: `pmbootstrap build <пакеты>` → `.apk` в `pmb-work/packages/edge/aarch64/` (подписаны ключом `pmos@local-*`, он уже есть в `/etc/apk/keys` планшета).
2. Скопировать `.apk` на планшет (`scp`), `sudo apk add -u /tmp/pk/*.apk` — mkinitfs и boot-deploy сами соберут `/boot/boot.img`.
3. Проверить `/boot/boot.img` (cmdline с прежними `pmos_*_uuid`, DTB, initramfs), затем
   `sudo dd if=/boot/boot.img of=/dev/disk/by-partlabel/boot_b bs=4M conv=fsync` и сверить sha256.
4. `sudo systemctl reboot`. Откат — прошлый `boot.img` через `fastboot flash boot_b`.

## 5. Сборка (Ubuntu-хост)
- `~/j606f/{pmbootstrap, pmaports, pmb-work}`; `~/.config/pmbootstrap_v3.cfg`: device lenovo-j606f, **ui plasma-desktop**, jobs 4, ssh_keys.
- Ядро собирается cross-native; повторная сборка с ccache ~12 мин, с нуля ~80 мин. Install с Plasma ~25 мин (медленный диск ВМ).
- `pmb-work/cache_apk_*` принадлежат root: чистить через `sudo`.

## 6. Версии
- pmbootstrap **3.12.1**; pmaports ветка **main** + локальные коммиты; канал **systemd-edge**.
- Ядро: **linux-nura-qcom-sm61x5 7.2.3-r103** (codeberg.org/sm61x5-mainline/linux v7.2.3-r0 + `kernel/patches/0001, 0003, 0004`), uname `7.2.3-sm61x5`.
- device-lenovo-j606f **r5** (cmdline с clk_ignore_unused, mm8013 modules-load, прошивка GPU в initramfs, bootmac); firmware-lenovo-j606f r0.
- postmarketos-ui-plasma-desktop 5; Mesa 26.2.5 (freedreno FD610); Alpine edge.
- Стоковая прошивка: TB-J606F_S120184_210520_ROW (Android 10), ABL «Loader Build Info: Sep 4 2021».

## 7. Чек-лист
P0: [x] дисплей+подсветка · [x] стабильная загрузка с внутренней памяти после выключения и включения · [ ] тач ·
[x] USB-сеть + SSH · [x] Wi-Fi (подключение, DHCP, DNS, интернет) ·
[~] батарея и зарядка: индикация (mm8013) и статус зарядника (pmi632-charger, read-only) работают, заряд на настройках загрузчика (4.40 В / 3 А) · [ ] кнопки.
P1: [x] GPU + Wayland (Plasma) · [ ] звук · [~] BT (powered, сканирует, сопряжение не проверено) · [ ] датчики · [ ] suspend.
P2/P3: пакеты pmaports (ядро pkgrel 103, device r5, firmware) — в `pmaports/`, собираются и ставятся; документация — этот репозиторий.
