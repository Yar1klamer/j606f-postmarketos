# STATE — где мы остановились (2026-10-29)

> Читать первым после потери контекста. Полная хронология: [WORKLOG.md](WORKLOG.md). Устройство: [DEVICE.md](DEVICE.md).
> Решения, команды, грабли, TODO: [NOTES.md](NOTES.md). Подробные заметки по подсистемам: `docs/notes/*.md`.

## 1. Одной строкой
**pmOS (Nura edge) установлен во внутреннюю память и грузится сам** на Lenovo Tab P11 TB-J606F (ревизия Himax HX83102P):
rootfs в `super`, boot.img в `boot_b` (`out/pmos/boot-dbg3-utmi.img`), активный слот **b**. Обычная загрузка → USB-сеть + SSH (`ssh user@172.16.42.1`). Wi-Fi, BT, экран, GPU, DSP работают.

## 2. Состояние устройства прямо сейчас
| Что | Значение |
|---|---|
| Что запущено | pmOS, обычная загрузка со слота b (29.10) |
| Активный слот | **b** |
| boot_a | стоковый boot + Magisk (пользователь поставил Magisk до бэкапа); стоковый оригинал сохранён в приватном бэкапе |
| boot_b | `out/pmos/boot-dbg3-utmi.img` (sha256 92a0e5db…): ядро+initramfs pmOS, cmdline + clk_ignore_unused pd_ignore_unused panic=10, DTB + `qcom,select-utmi-as-pipe-clk` |
| dtbo_a / dtbo_b, vbmeta_a / vbmeta_b | стоковые, побайтно одинаковые (sha256 326cbcbc… / af75b84f…) |
| super (`/dev/sda14`, 12 ГиБ) | **rootfs pmOS**: `fastboot flash super out/pmos/lenovo-j606f.img` (Android-sparse, 937228412 байт, sha256 e7e2e7c3…). Внутри GPT с секторами 4096: pmOS_boot + pmOS_root |
| userdata (`/dev/sda15`, 102 ГиБ) | ext4, метка `j606f_work`: рабочее место pmbootstrap (`/mnt/work/alpine/...`) |
| Android | **не загрузится** (super перезаписан, userdata отформатирован) — пользователь разрешил снести |
| modem*/persist/fsg/abl/xbl | не трогали (кроме того, что rmtfs в pmOS пишет EFS в modemst1/2, fsg — см. NOTES) |

## 3. Следующий шаг
1. ~~Тест P0 выкл/вкл~~ ГОТОВО (29.10). Проверить `slot-successful:b` (`fastboot getvar slot-successful:b`) после нескольких загрузок; если ABL откатится на a — разобраться с qbootctl.
2. Пересобрать образ с device-пакетом r2 (локальный коммит f0ab532 в src/pmaports-main: cmdline с clk_ignore_unused/pd_ignore_unused, modules-load mm8013, DTB с utmi):
   на планшете `/mnt/work/alpine/work/pmaports-main` применить патч коммита f0ab532 (`git format-patch -1` на Mac → wget → `git am`), затем `sh /mnt/work/pmb.sh build device-lenovo-j606f`, `sh /mnt/work/pmb_install.sh`; забрать sparse-образ и boot.img; `fastboot flash super …`, `fastboot flash boot_b …`.
   ВНИМАНИЕ: pmbootstrap install перегенерирует UUID → нужно прошивать super и boot_b вместе.

## 4. Что собрано и где
### Mac, приватный проект `~/Documents/pm for p11/pmos-j606f` (НЕ публикуется: серийники, бэкапы, блобы)
- `BACKUP/partitions/*.img` — 84 раздела (всё кроме userdata), `BACKUP/README.md` с sha256; `BACKUP/stock/boot_a_stock_from_magisk.img` — стоковый boot.
- `BACKUP/firmware/*.tar` — /vendor/firmware_mnt, /vendor/firmware, /vendor/dsp, /vendor/bt_firmware, /vendor/etc/wifi, /mnt/vendor/persist.
- `out/pmos/boot.img` — boot.img от pmbootstrap (cmdline без clk_ignore_unused → USB не работает!).
- `out/pmos/boot-dbg1.img` — тот же + `clk_ignore_unused pd_ignore_unused panic=10` (**рабочий**).
- `out/pmos/boot-dbg2-shell.img` — + `pmos.debug-shell` (telnet-shell initramfs).
- `out/pmos/lenovo-j606f.img` — sparse rootfs (прошит в super).
- `out/devbuild6/out/` — модули panel-himax-hx83102, tps65132-regulator, mm8013, ubwc_config, qcom_pd_mapper (.ko) и DTB `sm6115p-lenovo-j606f-hx83102p.dtb` (76788 байт, с abl-sink и thermal), собраны на планшете.
- `out/fw/qcom/sm6115/LENOVO/J606F/*.mbn` — прошивки (pil_squash), `out/fwpkg-v1/` — раскладка для firmware-пакета.
- `out/debug-boot-hx83102p-test9-thermal.img` — отладочный boot (готовое ядро + свой busybox-initramfs).
- `dl/linux-nura-qcom-sm61x5-7.2.3-r0/x/` — распакованный бинарный пакет ядра (vmlinuz, dtbs, модули, config).
- `src/pmaports-main/` — клон pmaports (main, e1d0e17) + локальные коммиты 9f25afd, 02cd3cd (device/firmware пакеты, ядро возвращено к апстриму).
- `src/pmbootstrap/` — pmbootstrap 46ee403 (3.12.1). `src/linux-sm61x5-full/` — linux v7.2.3-r0 (5a88d98).
- `out/sshkey/j606f_test` — тестовый ключ для отладочной среды. `out/pmos_user_password.txt` — пароль user в pmOS.

### Планшет, `/dev/sda15` → `/mnt/work` (ext4)
- `/mnt/work/alpine` — Alpine edge chroot (python3, git, multipath-tools…), внутри `/work/pmbootstrap`, `/work/pmaports-main` (с теми же локальными коммитами), `/work/pmb` (work pmbootstrap, version 8, cache_distfiles с архивом ядра).
- `/mnt/work/pmb.sh` — `pmbootstrap --as-root -y <args>` в chroot, лог `/mnt/work/pmb_last.log`; `/mnt/work/pmb_install.sh` — install с паролем из `/mnt/work/.pw`.
- `/mnt/work/alpine/reboot_bl.py` — reboot в bootloader (syscall 142, RESTART2 "bootloader").

## 5. Версии
- pmbootstrap **3.12.1** (git 46ee403); pmaports ветка **main** (e1d0e17 + локальные), канал **systemd-edge** (mirrordir alpine edge).
- Ядро: **linux-nura-qcom-sm61x5 7.2.3-r0** (бинарный пакет с mirror.nura.eco; исходники codeberg.org/sm61x5-mainline/linux тег v7.2.3-r0, commit 5a88d98), uname `7.2.3-sm61x5`.
- postmarketos-initramfs 3.12.5-r0; Mesa 26.2.5 (freedreno FD610); Alpine edge (clang/llvm 23).
- Стоковая прошивка: TB-J606F_S120184_210520_ROW (Android 10), ABL «Loader Build Info: Sep 4 2021», UEFI 5.0.210904.

## 6. Незавершённые задачи (по приоритету)
1. ~~boot_b + слот b~~ ГОТОВО (29.10); остался тест выключения/включения кнопкой.
2. **device-lenovo-j606f**:
   - `deviceinfo_kernel_cmdline="console=tty0 fbcon=rotate:2 clk_ignore_unused pd_ignore_unused"` (без них USB-гаджет: «dwc3 4e00000.usb: failed to enable ep0out»);
   - `/usr/lib/modules-load.d/j606f.conf` с `mm8013` (нет автозагрузки: alias только `i2c:mm8013`, modalias устройства `of:Nfuel-gaugeT(null)Cmitsumi,mm8013`);
   - pkgrel++, `pmbootstrap checksum device-lenovo-j606f`, `pmbootstrap install`, перепрошить super (fastboot, sparse!) и boot_b.
4. **GitHub**: репозиторий собран локально, push не сделан (нужно, чтобы пользователь создал пустой репозиторий и сделал `git push`; токен в чате НЕ использовать, его надо отозвать).
5. UI (пользователь не выбрал: Phosh / Plasma Mobile / GNOME Mobile; ориентация ландшафт) — пока `console`.
6. Тач HX83102E (нет драйвера), звук (AW88258/ES7210), датчики (hexagonrpcd), зарядник, suspend, MAC Wi-Fi/BT, клавиатура pogo.

## 7. Чек-лист
P0: [x] дисплей+подсветка (подтверждено пользователем) · [x] стабильная загрузка с внутренней памяти после выключения и включения (слот b, 29.10, подтверждено пользователем + ssh) ·
[ ] тач · [~] USB SSH работает в установленном pmOS, по Wi-Fi не проверено · [~] Wi-Fi видит сети, подключение не проверено ·
[~] батарея: в отладке mm8013 работал, в pmOS модуль не грузится; заряд идёт на HW-дефолтах · [ ] кнопки (нажатия не проверены).
P1: [x] GPU + Wayland (weston 60 fps, подтверждено визуально) · [ ] звук · [~] BT сканирует · [ ] датчики · [ ] suspend.
P2/P3: черновики pmaports-пакетов готовы; документация — этот репозиторий.
