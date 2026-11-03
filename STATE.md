# STATE — где мы остановились (2026-11-03)

> Текущее состояние порта. Устройство: [DEVICE.md](DEVICE.md). Решения: [docs/DECISIONS.md](docs/DECISIONS.md).
> Подробные заметки по подсистемам: `docs/notes/*.md`.

## 1. Одной строкой
**pmOS (Nura edge) с KDE Plasma Desktop установлен во внутреннюю память и грузится сам** на Lenovo Tab P11 TB-J606F (ревизия Himax HX83102P):
**rootfs в `userdata` (~100 ГиБ)**, boot.img в `boot_b`, **dtbo_b стёрт**, активный слот **b**. Ядро — linux-lenovo-j606f (linux-nura-qcom-sm61x5 7.2.3 с патчами 0001, 0003–0024)
(в pmaports **pkgrel 121**; без HACK 0002). Работают: Plasma, Wi-Fi, Bluetooth, батарея, датчики, **тач**, **USB OTG**, зарядка от сетевой USB-C (FUSB302),
GPU с голосованием за DDR (патч 0009, ×2.5–7), **аппаратное H.264/HEVC-декодирование через Venus** (патч 0011, firmware r2) и **динамики** (4× AW88258, стерео, 0012–0016), **задняя камера** (OV13B10 + фокус DW9763, CAMSS 0017–0022) и **фронтальная камера** (свой драйвер S5K4H7, 0023–0024); libcamera r6.
Нет: микрофоны, гарнитура (USB-C), стабильный сон (CrashDump после пробуждения) и финальный тест offline-зарядки. Пакеты раздаются через **https://repo.yarnick.ru/j606f** (README).
**Готовый архив для прошивки** (без блобов Lenovo, один скрипт) — [Releases](https://github.com/Yar1klamer/j606f-postmarketos/releases), проверен 03.11.
Второй планшет (тестировщик, тоже HX83102P, Android 11 в стоке) работает на образе с его прошивками.

## 2. Состояние устройства прямо сейчас
| Что | Значение |
|---|---|
| Что запущено | pmOS + Plasma Desktop (автологин user), обычная загрузка со слота b |
| Активный слот | **b** (`slot-successful:b` = yes) |
| boot_a | стоковый boot + Magisk; стоковый оригинал в приватном бэкапе |
| boot_b | ядро **linux-lenovo-j606f r121** (uname `#122`, обе камеры), boot.img записан boot-deploy автоматически; перед этим r121 проверен через `fastboot boot`; откатные образы в приватном бэкапе |
| dtbo_b | **стёрт** (`fastboot erase dtbo_b`): ABL не накладывает оверлей, compatible = `lenovo,j606f` |
| dtbo_a, vbmeta_a / vbmeta_b | стоковые |
| userdata (102 ГиБ) | **rootfs pmOS**: GPT (сектор 4096) pmOS_boot 480 МиБ + pmOS_root 102 ГиБ (перенесено поблочно из super с теми же UUID, 29.10) |
| super (12 ГиБ) | **стоковый** (03.11 восстановлен из бэкапа для проверки архива): vendor доступен извлечению прошивок |
| Android | super снова стоковый, но userdata занят pmOS — Android в слоте a не проверялся |
| modem*/persist/fsg/abl/xbl | не трогали (rmtfs в pmOS пишет EFS в modemst1/2, fsg — штатно) |
| Доступ | `ssh user@172.16.42.1` (USB) или по Wi-Fi; на планшете `sudo` без пароля для user и автологин (локальная настройка, **не в образе**) |
| apk | репозиторий `https://repo.yarnick.ru/j606f` без метки — из device-пакета (`/usr/lib/apk/repositories.d`, ключ в `/usr/lib/apk/keys`), переход выполнен `repo-migrate`; на планшете и в apk-репозитории linux-lenovo-j606f r121 и libcamera r6 (своя сборка pmOS libcamera с хелперами OV13B10 и S5K4H7, все подпакеты кроме -dbg) ; на планшете device r23, в apk-репозитории device r24 (+ nt36523w r14; с 03.11); в apk-репозитории также общий набор прошивок firmware-lenovo-j606f 0.320208 (сток S320208); на нашем планшете — свой firmware 1-r3 (с `awinic/aw882xx_acf.bin`: vendor у нас стёрт) |

Локальные настройки на планшете (пропадут при полной переустановке образа):
- kscreen: DSI-1 `rotation.left` (ландшафт), масштаб 1.4;
- `apk add mesa-vulkan-freedreno fastfetch` (Vulkan: Turnip Adreno 610); `~/.config/fastfetch/config.jsonc` — GPU через Vulkan;
- Bluetooth-мышь Mi Mouse3C сопряжена и доверена (`bluetoothctl`);
- экранная клавиатура: `kwinrc [Wayland] InputMethod=/usr/share/applications/org.kde.plasma.keyboard.desktop`, `VirtualKeyboardMode=2`; `plasmakeyboardrc [General] enabledLocales=en_US,ru_RU`;
  ярлык `~/.local/bin/osk-toggle` + `org.j606f.osk-toggle.desktop` на панели;
- датчики: с device r22 из пакета — дерево `/usr/share/qcom/sm6115/LENOVO/J606F/` (dsp, sensors, socinfo) собирает firmware-extract из разделов планшета,
  drop-in'ы hexagonrpcd с `-R` — в `/usr/lib/systemd/system/hexagonrpcd-adsp-*.service.d/j606f.conf`; датчики поднимаются ~через 2 мин после загрузки;
- `~/.config/kscreenlockerrc`: `[Daemon] Autolock=false, LockOnResume=false` (отключено, пока не было тача; владелец решил так и оставить);
- `~/.config/powerdevilrc`: `PowerButtonAction=128` (Power = вкл/выкл экрана);
- mpv (настройки из device r20: `/etc/mpv/mpv.conf` — profile=fast, hwdec=no; свой `~/.config/mpv/mpv.conf` убран), glmark2, vkmark;
- оболочка zsh + starship, Konsole с JetBrains Mono Nerd и тёмной схемой, KDE: Papirus-Dark, оформление окон Breeze, ночная подсветка;
- локаль ru_RU.UTF-8, NTP (systemd-timesyncd) включён: аппаратные часы PMIC из Linux не пишутся, без сети время берётся из метки timesyncd;
- `/etc/apk/repositories`: pmOS — `https://mirror.minlexx.ru/postmarketos/{extra-repos/systemd/main,main}`, Alpine — `http://mirror.yandex.ru/mirrors/alpine/edge/{main,community,testing}`
  (mirror.nura.eco из этой сети отдаёт ~500 Б/с; запасной вариант — официальное RWTH Aachen).

## 3. Следующий шаг
0. ✅ **Архив «скачал и прошил»** (03.11): device r22 (датчики из пакета), r23 (образу не нужны блобы Lenovo, одна перезагрузка после первой загрузки),
   r24 (zap GPU в initramfs необязателен) — в apk-репозитории. Архив: userdata.img + boot.img + flash-all.{sh,bat} + SHA256SUMS + README.txt ([`release/`](release/)).
   Проверен на нашем планшете со стоковым super: первая загрузка извлекла прошивки из modem, bluetooth, dsp, persist и vendor, GPU (FD610), тач, динамики,
   BT, Wi-Fi, датчики работают. Не проверены flash-all.bat (Windows) и установка при затёртом vendor.
0a. **CrashDump** (у тестировщика — при громкости, перезагрузке страницы в браузере и перезагрузке; у нас — через ~2 мин после пробуждения из s2idle),
   ядро r121. Паники в журнале нет (зависание SoC → watchdog). На выходе из сна — «Watchdog detected hard LOCKUP» в cpuidle_enter_s2idle.
   Дальше: воспроизвести и снять ramoops (`/var/lib/systemd/pstore`) на первой загрузке после сбоя. Пока — совет отключить автоматический сон.
0b. Камеры: обе работают (r121 + libcamera r6). Дальше — автофокус, AGC фронта при контровом свете, тюнинг цвета (ov13b10.yaml, s5k4h7.yaml),
   скрыть сырые узлы CAMSS в PipeWire (правило WirePlumber), вспышка PMI632.
1. ✅ **Venus работает**: ядро r115 + firmware r2, аппаратные H.264 и HEVC 1080p проверены через `v4l2m2m-copy` с корректным EOF. Опубликовано (патч 0011 в репозитории, пакеты в apk-репозитории); в mpv по умолчанию программное декодирование (r20).
2. Сон: r110 исправил USB ep0, r111 дал успешный s2idle; на r121 сон и пробуждение без ошибок USB/ADSP, звук и BT возвращаются.
   С **device r21** (nt36523w r11) помощник сна в пакете: `j606f-sleep.service` останавливает датчики и BT перед сном, `j606f-resume.service`
   (After=suspend.target) поднимает hexagonrpcd-adsp-rootpd/sensorspd и iio-sensor-proxy после. Причина прежнего бага: у hexagonrpcd-adsp-*
   `Conflicts=suspend.target`, systemd гасил их одновременно с нашим хуком, и они не попадали в список на восстановление. 02.11: три цикла сна —
   датчики, ADSP, звук, BT на месте. Не проверены долгий сон (часы) и сон с OTG; при сне из ssh будит UART BT (msmgpio 11) через ~2 с.
3. Офлайн-зарядка: device r11 различает reboot и charger boot. Финальный цикл poweroff → charger → unplug не завершён; экран «hold power button to boot» планируется убрать и сделать офлайн-зарядку иначе.
4. Умолчания в device-пакет (Power = экран, экранная клавиатура EN/RU, без автоблокировки, масштаб 1.4) — у тестировщика это пришлось делать руками.
5. Звук дальше: микрофоны ES7210 (порт драйвера Lenovo), гарнитура через USB-C (FSA4480 + WCD937x); динамики готовы (r117). Автоповорот (ACCEL_MOUNT_MATRIX), упаковка датчиков, запись лимитов зарядника,
   тач Novatek для ревизии NT36523W, перо.

## 4. Как обновлять без переустановки (порядок с r120)
Полная переустановка сбрасывает локальные настройки и требует fastboot. Вместо неё:
1. Собрать пакеты: `pmbootstrap build <пакет>` → `.apk` (подписаны ключом репозитория, он уже есть на планшете).
2. Новое ядро — сначала без записи: тестовый образ = текущий `/boot/boot.img` с vmlinuz и DTB из нового пакета
   ([`scripts/bootimg_replace_dtb.py`](scripts/bootimg_replace_dtb.py)), `systemctl reboot --reboot-argument=bootloader`, `fastboot boot`, проверка.
3. Сохранить копию boot_b и `/etc/apk/world`, затем `sudo apk add <файлы .apk>` — mkinitfs и boot-deploy сами пишут boot_b (device r7+);
   вернуть world из копии, перезагрузиться и проверить `uname -v` (`#<pkgrel+1>`).
4. Опубликовать в apk-репозитории — остальные получают обычным `apk upgrade`. Откат — прошлый boot.img через `fastboot flash boot_b`.

## 5. Сборка (pmbootstrap)
- `pmbootstrap_v3.cfg`: device lenovo-j606f, **ui plasma-desktop**.
- Зеркала:
  `pmbootstrap config mirrors.alpine http://mirror.yandex.ru/mirrors/alpine/`,
  `pmbootstrap config mirrors.pmaports https://mirror.minlexx.ru/postmarketos/`,
  `pmbootstrap config mirrors.systemd https://mirror.minlexx.ru/postmarketos/extra-repos/systemd/`.
- Ядро собирается cross-native; повторная сборка с ccache ~12 мин, с нуля ~80 мин. Install с Plasma ~25 мин.

## 6. Версии
- pmbootstrap **3.12.1**; pmaports ветка **main** + локальные коммиты; канал **systemd-edge**.
- Ядро: **linux-lenovo-j606f 7.2.3-r121** на планшете и в apk-репозитории (до r117 — linux-nura-qcom-sm61x5; codeberg.org/sm61x5-mainline/linux v7.2.3-r0 + `kernel/patches/0001, 0003–0024`), uname `7.2.3-sm61x5 #122`.
- libcamera: **99990.7.2-r6** (pmaports temp/libcamera + 0007 OV13B10, 0008 S5K4H7) на планшете и в apk-репозитории (выше pmOS r4).
- device-lenovo-j606f **r24** в pmaports и apk-репозитории, r23 на нашем планшете (r22: датчики из пакета; r23: без блобов Lenovo; r24: zap необязателен; помощник сна j606f-sleep/j606f-resume, репозиторий порта и его ключ, `/etc/mpv/mpv.conf`, rootfs → userdata, автозапись boot_b, offline-charger hook, UCM динамиков, softdep SoundWire → WCD937x, прошивка из modem/bluetooth/super самого планшета — при общем наборе в /lib/firmware/updates, apk-триггер); firmware-lenovo-j606f: личный **1-r3** (из своего бэкапа, не публикуется) или общий **0.320208** из apk-репозитория (`APKBUILD.shared`); hexagonrpcd 0.4.0-r50 (наш патч `sns_reg_version`).
- postmarketos-ui-plasma-desktop 5; Plasma 6.8.1; Mesa 26.2.5 (freedreno FD610); Alpine edge.
- Стоковая прошивка: TB-J606F_S120184_210520_ROW (Android 10), ABL «Loader Build Info: Sep 4 2021».

## 7. Чек-лист
P0: [x] дисплей+подсветка · [x] стабильная загрузка с внутренней памяти после выключения и включения · [x] тач (HX83102E, патч 0006; перо не проверено) ·
[x] USB-сеть + SSH · [x] Wi-Fi (подключение, DHCP, DNS, интернет) ·
[~] батарея и зарядка: индикация (mm8013), статус зарядника (read-only), зарядка от USB-A и от сетевой USB-C (FUSB302, 5 В); нет офлайн-зарядки и записи лимитов · [x] кнопки (Power гасит/включает экран, громкость проверена владельцем).
P1: [x] GPU + Wayland (Plasma), Vulkan (turnip) · [x] камеры (задняя с ручным фокусом, фронтальная) · [~] звук (динамики ✅ r117; микрофоны и гарнитура — нет) · [x] BT (сопряжение и ввод: мышь Mi Mouse3C) · [x] датчики (свет, приближение, акселерометр; ориентация — подобрать матрицу) · [~] USB OTG (FUSB302) · [~] suspend (r110/r111 + помощник сна в device r21; CrashDump после пробуждения) · [x] GPU-производительность (DDR votes, 0009) · [x] аппаратное H.264/HEVC-декодирование (Venus, 0011/r115).
P2/P3: пакеты pmaports (linux-lenovo-j606f r121, libcamera r6, device r24, device-lenovo-j606f-nt36523w r14, firmware 1-r3 (личный APKBUILD) + APKBUILD.shared (общий 0.320208), hexagonrpcd r50) — в `pmaports/`; apk-репозиторий https://repo.yarnick.ru/j606f; документация — этот репозиторий.
