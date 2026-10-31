# STATE — где мы остановились (2026-10-30, день)

> Текущее состояние порта. Устройство: [DEVICE.md](DEVICE.md). Решения: [docs/DECISIONS.md](docs/DECISIONS.md).
> Подробные заметки по подсистемам: `docs/notes/*.md`.

## 1. Одной строкой
**pmOS (Nura edge) с KDE Plasma Desktop установлен во внутреннюю память и грузится сам** на Lenovo Tab P11 TB-J606F (ревизия Himax HX83102P):
**rootfs в `userdata` (~100 ГиБ)**, boot.img в `boot_b`, **dtbo_b стёрт**, активный слот **b**. Ядро — linux-nura-qcom-sm61x5 7.2.3 с патчами 0001, 0003–0011
(в pmaports **pkgrel 115**; без HACK 0002). Работают: Plasma, Wi-Fi, Bluetooth, батарея, датчики, **тач**, **USB OTG**, зарядка от сетевой USB-C (FUSB302),
GPU с голосованием за DDR (патч 0009, ×2.5–7) и **аппаратное H.264/HEVC-декодирование через Venus** (патч 0011, firmware r2).
Нет: звук, полностью проверенный сон и финальный тест offline-зарядки. Пакеты раздаются через **https://repo.yarnick.ru/j606f** (README; публичный снимок пока старше).
Второй планшет (друг, тоже HX83102P, Android 11 в стоке) работает на образе с его прошивками.

## 2. Состояние устройства прямо сейчас
| Что | Значение |
|---|---|
| Что запущено | pmOS + Plasma Desktop (автологин user), обычная загрузка со слота b |
| Активный слот | **b** (`slot-successful:b` = yes) |
| boot_a | стоковый boot + Magisk; стоковый оригинал в приватном бэкапе |
| boot_b | ядро **r115** (uname `#116`), boot.img записан boot-deploy автоматически; откатный образ перед Venus — `boot_b-before-r112-venus.img` |
| dtbo_b | **стёрт** (`fastboot erase dtbo_b`): ABL не накладывает оверлей, compatible = `lenovo,j606f` |
| dtbo_a, vbmeta_a / vbmeta_b | стоковые |
| userdata (102 ГиБ) | **rootfs pmOS**: GPT (сектор 4096) pmOS_boot 480 МиБ + pmOS_root 102 ГиБ (перенесено поблочно из super с теми же UUID, 29.10) |
| super (12 ГиБ) | старая копия системы, **GPT подразделов удалена** (иначе initramfs выберет super раньше userdata); дамп таблицы для восстановления сохранён |
| Android | **не загрузится** (super перезаписан) — с согласия владельца |
| modem*/persist/fsg/abl/xbl | не трогали (rmtfs в pmOS пишет EFS в modemst1/2, fsg — штатно) |
| Доступ | `ssh user@172.16.42.1` (USB) или по Wi-Fi; на планшете `sudo` без пароля для user и автологин (локальная настройка, **не в образе**) |
| apk | добавлен `@j606f https://repo.yarnick.ru/j606f`; на планшете и в apk-репозитории r115 + device r16 (+ nt36523w r6); в apk-репозитории также общий набор прошивок firmware-lenovo-j606f 0.320208 (сток S320208); на нашем планшете — свой firmware 1-r2 |

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
- mpv (`~/.config/mpv/mpv.conf`: profile=fast, `hwdec=v4l2m2m-copy` — аппаратный Venus H.264/HEVC), glmark2, vkmark;
- `/etc/apk/repositories`: pmOS — `https://mirror.minlexx.ru/postmarketos/{extra-repos/systemd/main,main}`, Alpine — `http://mirror.yandex.ru/mirrors/alpine/edge/{main,community,testing}`
  (mirror.nura.eco из этой сети отдаёт ~500 Б/с; запасной вариант — официальное RWTH Aachen).

## 3. Следующий шаг
1. ✅ **Venus работает**: ядро r115 + firmware r2, аппаратные H.264 и HEVC 1080p проверены через `v4l2m2m-copy` с корректным EOF. Сохранить патчи/APK и опубликовать исходники после review.
2. Сон: r110 исправил USB ep0, r111 дал успешный s2idle; ручной `j606f-sleep` восстанавливает BT, но финальная проверка ADSP/датчиков/USB не завершена.
   Helper пока не отслеживается Git и не включён в device APKBUILD — оформить после повторного теста.
3. Офлайн-зарядка: device r11 различает reboot и charger boot. Завершить финальный цикл: poweroff → charger mode → Power hold → boot → unplug → poweroff.
4. Умолчания в device-пакет (Power = экран, экранная клавиатура EN/RU, без автоблокировки, масштаб 1.4) — у друга это пришлось делать руками.
5. Звук (разъём наушников PM4125/WCD937x; AW88258/ES7210 — порт драйверов Lenovo), автоповорот (ACCEL_MOUNT_MATRIX), упаковка датчиков, запись лимитов зарядника,
   тач Novatek для ревизии NT36523W, перо.

## 4. Как обновлять без переустановки (проверено 29.10)
Полная переустановка (`pmbootstrap install` + `fastboot flash super/boot_b`) сбрасывает локальные настройки и требует fastboot. Вместо неё:
1. На сборочном хосте: `pmbootstrap build <пакеты>` → `.apk` в `pmb-work/packages/edge/aarch64/` (подписаны ключом `pmos@local-*`, он уже есть в `/etc/apk/keys` планшета).
2. Скопировать `.apk` на планшет (`scp`), `sudo apk add -u /tmp/pk/*.apk` — mkinitfs и boot-deploy сами соберут `/boot/boot.img`.
3. Проверить `/boot/boot.img` (cmdline с прежними `pmos_*_uuid`, DTB, initramfs), затем
   `sudo dd if=/boot/boot.img of=/dev/disk/by-partlabel/boot_b bs=4M conv=fsync` и сверить sha256.
4. `sudo systemctl reboot`. Откат — прошлый `boot.img` через `fastboot flash boot_b`.

## 5. Сборка (pmbootstrap)
- `pmbootstrap_v3.cfg`: device lenovo-j606f, **ui plasma-desktop**.
- Зеркала:
  `pmbootstrap config mirrors.alpine http://mirror.yandex.ru/mirrors/alpine/`,
  `pmbootstrap config mirrors.pmaports https://mirror.minlexx.ru/postmarketos/`,
  `pmbootstrap config mirrors.systemd https://mirror.minlexx.ru/postmarketos/extra-repos/systemd/`.
- Ядро собирается cross-native; повторная сборка с ccache ~12 мин, с нуля ~80 мин. Install с Plasma ~25 мин.

## 6. Версии
- pmbootstrap **3.12.1**; pmaports ветка **main** + локальные коммиты; канал **systemd-edge**.
- Ядро: **linux-nura-qcom-sm61x5 7.2.3-r115** в pmaports и на планшете (codeberg.org/sm61x5-mainline/linux v7.2.3-r0 + `kernel/patches/0001, 0003–0011`), uname `7.2.3-sm61x5 #116`; публичный снимок — r109.
- device-lenovo-j606f **r16** на планшете и в pmaports (rootfs → userdata, автозапись boot_b, offline-charger hook, прошивка из modem/bluetooth/super самого планшета — при общем наборе в /lib/firmware/updates, apk-триггер); firmware-lenovo-j606f: личный **1-r2** (из своего бэкапа, не публикуется) или общий **0.320208** из apk-репозитория (`APKBUILD.shared`); hexagonrpcd 0.4.0-r50 (наш патч `sns_reg_version`).
- postmarketos-ui-plasma-desktop 5; Mesa 26.2.5 (freedreno FD610); Alpine edge.
- Стоковая прошивка: TB-J606F_S120184_210520_ROW (Android 10), ABL «Loader Build Info: Sep 4 2021».

## 7. Чек-лист
P0: [x] дисплей+подсветка · [x] стабильная загрузка с внутренней памяти после выключения и включения · [x] тач (HX83102E, патч 0006; перо не проверено) ·
[x] USB-сеть + SSH · [x] Wi-Fi (подключение, DHCP, DNS, интернет) ·
[~] батарея и зарядка: индикация (mm8013), статус зарядника (read-only), зарядка от USB-A и от сетевой USB-C (FUSB302, 5 В); нет офлайн-зарядки и записи лимитов · [x] кнопки (Power гасит/включает экран, громкость проверена владельцем).
P1: [x] GPU + Wayland (Plasma), Vulkan (turnip) · [ ] звук · [x] BT (сопряжение и ввод: мышь Mi Mouse3C) · [x] датчики (свет, приближение, акселерометр; ориентация — подобрать матрицу) · [~] USB OTG (FUSB302) · [~] suspend (r110/r111 + ручной sleep helper, финальная проверка не завершена) · [x] GPU-производительность (DDR votes, 0009) · [x] аппаратное H.264/HEVC-декодирование (Venus, 0011/r115).
P2/P3: пакеты pmaports (ядро pkgrel 115, device r16, device-lenovo-j606f-nt36523w r6, firmware r2 + APKBUILD.shared, hexagonrpcd r50) — в `pmaports/`; apk-репозиторий https://repo.yarnick.ru/j606f; документация — этот репозиторий.
