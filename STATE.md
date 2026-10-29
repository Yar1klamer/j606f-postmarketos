# STATE — где мы остановились (2026-10-30, утро)

> Читать первым после потери контекста. Полная хронология: [WORKLOG.md](WORKLOG.md). Устройство: [DEVICE.md](DEVICE.md).
> Решения, команды, грабли, TODO: [NOTES.md](NOTES.md). Подробные заметки по подсистемам: `docs/notes/*.md`.

## 1. Одной строкой
**pmOS (Nura edge) с KDE Plasma Desktop установлен во внутреннюю память и грузится сам** на Lenovo Tab P11 TB-J606F (ревизия Himax HX83102P):
**rootfs в `userdata` (~100 ГиБ)**, boot.img в `boot_b`, **dtbo_b стёрт**, активный слот **b**. Ядро — linux-nura-qcom-sm61x5 7.2.3 с патчами 0001, 0003–0009
(в pmaports **pkgrel 109**; без HACK 0002). Работают: Plasma, Wi-Fi, Bluetooth, батарея, датчики, **тач**, **USB OTG** и зарядка от сетевой USB-C (FUSB302),
GPU с голосованием за DDR (патч 0009, ×2.5–7). Нет: звук, сон (dwc3/ADSP), офлайн-зарядка. Пакеты раздаются через **https://repo.yarnick.ru/j606f** (README).
Второй планшет (друг, тоже HX83102P, Android 11 в стоке) работает на образе с его прошивками.

## 2. Состояние устройства прямо сейчас
| Что | Значение |
|---|---|
| Что запущено | pmOS + Plasma Desktop (автологин user), обычная загрузка со слота b |
| Активный слот | **b** (`slot-successful:b` = yes) |
| boot_a | стоковый boot + Magisk; стоковый оригинал в приватном бэкапе |
| boot_b | ядро **r109** из пакета (uname `#110`), boot.img собран mkinitfs на планшете и записан `dd` |
| dtbo_b | **стёрт** (`fastboot erase dtbo_b`): ABL не накладывает оверлей, compatible = `lenovo,j606f` |
| dtbo_a, vbmeta_a / vbmeta_b | стоковые |
| userdata (102 ГиБ) | **rootfs pmOS**: GPT (сектор 4096) pmOS_boot 480 МиБ + pmOS_root 102 ГиБ (перенесено поблочно из super с теми же UUID, 29.10) |
| super (12 ГиБ) | старая копия системы, **GPT подразделов удалена** (иначе initramfs выберет super раньше userdata); дамп таблицы для восстановления сохранён |
| Android | **не загрузится** (super перезаписан) — с согласия владельца |
| modem*/persist/fsg/abl/xbl | не трогали (rmtfs в pmOS пишет EFS в modemst1/2, fsg — штатно) |
| Доступ | `ssh user@172.16.42.1` (USB) или по Wi-Fi; на планшете `sudo` без пароля для user и автологин (локальная настройка, **не в образе**) |
| apk | добавлен `@j606f https://repo.yarnick.ru/j606f`; ядро r109 стоит, оно же в репозитории |

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
- mpv (`~/.config/mpv/mpv.conf`: profile=fast — Adreno не тянул шейдерное масштабирование 1080p→2000×1200), glmark2, vkmark;
- `/etc/apk/repositories`: pmOS — `https://mirror.minlexx.ru/postmarketos/{extra-repos/systemd/main,main}`, Alpine — `http://mirror.yandex.ru/mirrors/alpine/edge/{main,community,testing}`
  (mirror.nura.eco из этой сети отдаёт ~500 Б/с; запасной вариант — официальное RWTH Aachen).

## 3. Следующий шаг
1. Ядро **r109** стоит и опубликовано (тач, fusb302 из пакета, зарядка C-to-C, vkmark 540). OTG-хост на r109 проверен (ресивер мыши).
   У друга после apk upgrade OTG «не работает» — скорее всего не сделан `dd` boot.img в boot_b (ядро не сменилось). Проверить у него `uname -v`.
2. Решение владельца: `deviceinfo_flash_kernel_on_update="true"` в device-lenovo-j606f (boot-deploy сам пишет boot_b после обновления; риск — битое ядро/обрыв питания → fastboot).
3. Сон: dwc3 HS-only теряет ep0 после CoreSoftReset (сон, смена роли host→device), ADSP падает при засыпании (проверить с остановленными hexagonrpcd/iio-sensor-proxy);
   вариант для dwc3 — перевести USB на «плоскую» привязку qcom,snps-dwc3. Автосон PowerDevil пока выключить.
4. Офлайн-зарядка: свой хук initramfs (androidboot.mode=charger → экран с процентом, Power → загрузка) или `fastboot oem off-mode-charge 0`.
5. Умолчания в device-пакет (Power = экран, экранная клавиатура EN/RU, без автоблокировки, масштаб 1.4) — у друга это пришлось делать руками.
6. Звук (разъём наушников PM4125/WCD937x; AW88258/ES7210 — порт драйверов Lenovo), автоповорот (ACCEL_MOUNT_MATRIX), упаковка датчиков, запись лимитов зарядника,
   тач Novatek для ревизии NT36523W, перо.

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
- Ядро: **linux-nura-qcom-sm61x5 7.2.3-r109** в pmaports, **r109** в репозитории и на планшете (codeberg.org/sm61x5-mainline/linux v7.2.3-r0 + `kernel/patches/0001, 0003–0009`), uname `7.2.3-sm61x5`.
- device-lenovo-j606f **r5** на планшете, **r6** в pmaports и репозитории (rootfs → userdata); cmdline с clk_ignore_unused, mm8013 modules-load, прошивка GPU в initramfs, bootmac; firmware-lenovo-j606f r1 (у каждого свой, не публикуется); hexagonrpcd 0.4.0-r50 (наш патч `sns_reg_version`).
- postmarketos-ui-plasma-desktop 5; Mesa 26.2.5 (freedreno FD610); Alpine edge.
- Стоковая прошивка: TB-J606F_S120184_210520_ROW (Android 10), ABL «Loader Build Info: Sep 4 2021».

## 7. Чек-лист
P0: [x] дисплей+подсветка · [x] стабильная загрузка с внутренней памяти после выключения и включения · [x] тач (HX83102E, патч 0006; перо не проверено) ·
[x] USB-сеть + SSH · [x] Wi-Fi (подключение, DHCP, DNS, интернет) ·
[~] батарея и зарядка: индикация (mm8013), статус зарядника (read-only), зарядка от USB-A и от сетевой USB-C (FUSB302, 5 В); нет офлайн-зарядки и записи лимитов · [x] кнопки (Power гасит/включает экран, громкость проверена владельцем).
P1: [x] GPU + Wayland (Plasma), Vulkan (turnip) · [ ] звук · [x] BT (сопряжение и ввод: мышь Mi Mouse3C) · [x] датчики (свет, приближение, акселерометр; ориентация — подобрать матрицу) · [~] USB OTG (FUSB302) · [ ] suspend (dwc3/ADSP) · [x] GPU-производительность (DDR votes, 0009).
P2/P3: пакеты pmaports (ядро pkgrel 109, device r6, device-lenovo-j606f-nt36523w r0, firmware r1, hexagonrpcd r50) — в `pmaports/`; apk-репозиторий https://repo.yarnick.ru/j606f; документация — этот репозиторий.
