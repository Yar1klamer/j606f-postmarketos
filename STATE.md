# STATE — где мы остановились (2026-10-29, ночь)

> Читать первым после потери контекста. Полная хронология: [WORKLOG.md](WORKLOG.md). Устройство: [DEVICE.md](DEVICE.md).
> Решения, команды, грабли, TODO: [NOTES.md](NOTES.md). Подробные заметки по подсистемам: `docs/notes/*.md`.

## 1. Одной строкой
**pmOS (Nura edge) с KDE Plasma Desktop установлен во внутреннюю память и грузится сам** на Lenovo Tab P11 TB-J606F (ревизия Himax HX83102P):
**rootfs в `userdata` (~100 ГиБ)**, boot.img в `boot_b`, **dtbo_b стёрт**, активный слот **b**. Ядро — наша сборка linux-nura-qcom-sm61x5 7.2.3 **pkgrel 106** (патчи 0001, 0003, 0004, 0005, 0006; без HACK 0002).
Автологин в Plasma, альбомная ориентация, Wi-Fi, Bluetooth (мышь), батарея и зарядник, датчики (свет, приближение, акселерометр), **тач** (HX83102E, порт драйвера Lenovo). Звука нет.

## 2. Состояние устройства прямо сейчас
| Что | Значение |
|---|---|
| Что запущено | pmOS + Plasma Desktop (автологин user), обычная загрузка со слота b |
| Активный слот | **b** (`slot-successful:b` = yes) |
| boot_a | стоковый boot + Magisk; стоковый оригинал в приватном бэкапе |
| boot_b | `/boot/boot.img` с самого планшета (ядро r106, device r5; device r6 собран в pmaports, на планшет не ставился), записан `dd` в `/dev/disk/by-partlabel/boot_b` |
| dtbo_b | **стёрт** (`fastboot erase dtbo_b`): ABL не накладывает оверлей, compatible = `lenovo,j606f` |
| dtbo_a, vbmeta_a / vbmeta_b | стоковые |
| userdata (102 ГиБ) | **rootfs pmOS**: GPT (сектор 4096) pmOS_boot 480 МиБ + pmOS_root 102 ГиБ (перенесено поблочно из super с теми же UUID, 29.10) |
| super (12 ГиБ) | старая копия системы, **GPT подразделов удалена** (иначе initramfs выберет super раньше userdata); дамп таблицы для восстановления сохранён |
| Android | **не загрузится** (super перезаписан) — с согласия владельца |
| modem*/persist/fsg/abl/xbl | не трогали (rmtfs в pmOS пишет EFS в modemst1/2, fsg — штатно) |
| Доступ | `ssh user@172.16.42.1` (USB) или по Wi-Fi; на планшете `sudo` без пароля для user и автологин (локальная настройка, **не в образе**) |

Локальные настройки на планшете (пропадут при полной переустановке образа):
- kscreen: DSI-1 `rotation.left` (ландшафт), масштаб 1.4;
- `apk add mesa-vulkan-freedreno fastfetch` (Vulkan: Turnip Adreno 610); `~/.config/fastfetch/config.jsonc` — GPU через Vulkan;
- Bluetooth-мышь Mi Mouse3C сопряжена и доверена (`bluetoothctl`);
- экранная клавиатура: `kwinrc [Wayland] InputMethod=/usr/share/applications/org.kde.plasma.keyboard.desktop`, `VirtualKeyboardMode=2`; `plasmakeyboardrc [General] enabledLocales=en_US,ru_RU`;
  ярлык `~/.local/bin/osk-toggle` + `org.j606f.osk-toggle.desktop` на панели;
- датчики: `/usr/share/qcom/sm6115/LENOVO/J606F/` (dsp, sensors, socinfo — со своего устройства), hexagonrpcd 0.4.0-r50 (наш патч), drop-in'ы
  `/etc/systemd/system/hexagonrpcd-adsp-{rootpd,sensorspd}.service.d/j606f.conf` с `-R …/J606F`; iio-sensor-proxy включён, датчики работают (`monitor-sensor`: свет, приближение, акселерометр);
- `~/.config/kscreenlockerrc`: `[Daemon] Autolock=false, LockOnResume=false` (отключено, пока не было тача; владелец решил так и оставить);
- `~/.config/powerdevilrc`: `PowerButtonAction=128` (Power = вкл/выкл экрана);
- `/etc/apk/repositories`: pmOS — `https://mirror.minlexx.ru/postmarketos/{extra-repos/systemd/main,main}`, Alpine — `http://mirror.yandex.ru/mirrors/alpine/edge/{main,community,testing}`
  (mirror.nura.eco из этой сети отдаёт ~500 Б/с; запасной вариант — официальное RWTH Aachen).

## 3. Следующий шаг
1. Автоповорот: подобрать ACCEL_MOUNT_MATRIX (udev-правило), нужен владелец — поворачивать планшет.
2. Звук: разъём наушников и микрофон гарнитуры (PM4125/WCD937x, DTS + UCM); динамики AW88258 и микрофоны ES7210 — нет драйверов.
3. Упаковать датчики: drop-in'ы hexagonrpcd и зависимость от hexagonrpcd r50 — в device-пакет; файлы прошивки — приватно.
4. Зарядник, шаг 2: запись лимитов (ICL под сетевой адаптер, JEITA), только после проверки от адаптера.
5. Тач: работает (патч 0006). Проверить перо (Lenovo Precision Pen). Экран блокировки и экранную клавиатуру владелец решил оставить как есть (29.10). suspend/resume.
6. Ревизия NT36523W (планшет друга): DTB и device `lenovo-j606f-nt36523w` готовы (ядро r107, патч 0007), инструкция `docs/notes/install_nt36523w.md`.
   Ждём от друга `FIRMWARE/` (scripts/collect_firmware.sh) → собрать образ. Потом: тач Novatek NT36523 (порт драйвера Lenovo), USB OTG.

## 4. Как обновлять без переустановки (проверено 29.10)
Полная переустановка (`pmbootstrap install` + `fastboot flash super/boot_b`) сбрасывает локальные настройки и требует fastboot. Вместо неё:
1. На сборочном хосте: `pmbootstrap build <пакеты>` → `.apk` в `pmb-work/packages/edge/aarch64/` (подписаны ключом `pmos@local-*`, он уже есть в `/etc/apk/keys` планшета).
2. Скопировать `.apk` на планшет (`scp`), `sudo apk add -u /tmp/pk/*.apk` — mkinitfs и boot-deploy сами соберут `/boot/boot.img`.
3. Проверить `/boot/boot.img` (cmdline с прежними `pmos_*_uuid`, DTB, initramfs), затем
   `sudo dd if=/boot/boot.img of=/dev/disk/by-partlabel/boot_b bs=4M conv=fsync` и сверить sha256.
4. `sudo systemctl reboot`. Откат — прошлый `boot.img` через `fastboot flash boot_b`.

## 5. Сборка (Ubuntu-хост)
- `~/j606f/{pmbootstrap, pmaports, pmb-work}`; `~/.config/pmbootstrap_v3.cfg`: device lenovo-j606f, **ui plasma-desktop**, jobs 4, ssh_keys.
  `pmbootstrap config mirrors.alpine http://mirror.yandex.ru/mirrors/alpine/`,
  `pmbootstrap config mirrors.pmaports https://mirror.minlexx.ru/postmarketos/`,
  `pmbootstrap config mirrors.systemd https://mirror.minlexx.ru/postmarketos/extra-repos/systemd/`.
- Ядро собирается cross-native; повторная сборка с ccache ~12 мин, с нуля ~80 мин. Install с Plasma ~25 мин (медленный диск ВМ).
- `pmb-work/cache_apk_*` принадлежат root: чистить через `sudo`.

## 6. Версии
- pmbootstrap **3.12.1**; pmaports ветка **main** + локальные коммиты; канал **systemd-edge**.
- Ядро: **linux-nura-qcom-sm61x5 7.2.3-r106** (codeberg.org/sm61x5-mainline/linux v7.2.3-r0 + `kernel/patches/0001, 0003, 0004, 0005, 0006`), uname `7.2.3-sm61x5`.
- device-lenovo-j606f **r5** на планшете, **r6** в pmaports (rootfs → userdata); cmdline с clk_ignore_unused, mm8013 modules-load, прошивка GPU в initramfs, bootmac; firmware-lenovo-j606f r0; hexagonrpcd 0.4.0-r50 (наш патч `sns_reg_version`).
- postmarketos-ui-plasma-desktop 5; Mesa 26.2.5 (freedreno FD610); Alpine edge.
- Стоковая прошивка: TB-J606F_S120184_210520_ROW (Android 10), ABL «Loader Build Info: Sep 4 2021».

## 7. Чек-лист
P0: [x] дисплей+подсветка · [x] стабильная загрузка с внутренней памяти после выключения и включения · [x] тач (HX83102E, патч 0006; перо не проверено) ·
[x] USB-сеть + SSH · [x] Wi-Fi (подключение, DHCP, DNS, интернет) ·
[~] батарея и зарядка: индикация (mm8013) и статус зарядника (pmi632-charger, read-only) работают, заряд на настройках загрузчика (4.40 В / 3 А) · [x] кнопки (Power гасит/включает экран, громкость проверена владельцем).
P1: [x] GPU + Wayland (Plasma), Vulkan (turnip) · [ ] звук · [x] BT (сопряжение и ввод: мышь Mi Mouse3C) · [x] датчики (свет, приближение, акселерометр; ориентация — подобрать матрицу) · [ ] suspend.
P2/P3: пакеты pmaports (ядро pkgrel 107 в pmaports, на планшете 106; device-lenovo-j606f-nt36523w r0; device r6, firmware r1, hexagonrpcd r50) — в `pmaports/`, собираются и ставятся; документация — этот репозиторий.
