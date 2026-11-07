# Отзывы пользователей и внешние вклады

## 07.11 — PR #1 (kruzeman): пого-док Lenovo Keyboard Pack
**Итог:** патч 0025 → ядро r122, проверено на нашем планшете, опубликовано в apk-репозитории, PR слит 07.11.
github.com/Yar1klamer/j606f-postmarketos/pull/1, ветка автора `feat/pogo-hid-i2c`, один коммит 09db393 (06.11).
- Суть: два узла `hid-over-i2c` в `kernel/dts/sm6115p-lenovo-j606f-common.dtsi`: I2C0 0x60 (Elan 04f3:3164, тачпад, irq gpio93)
  и I2C1 0x61 (Lenovo 17ef:6103, клавиатура, irq gpio96), `hid-descr-addr = <0x1>`, `post-power-on-delay-ms = <100>`, `IRQ_TYPE_LEVEL_LOW`,
  pinctrl как в стоке. Автор проверил на железе (r121, свой DTB). Совпадает с нашим планом из notes/input_keyboard.md (адреса и IRQ из стокового DT).
  Адреса не пересекаются: на I2C0 — fusb302 0x22, AW88258 0x34–0x37, mm8013 0x55; на I2C1 в нашем DT ничего нет (SMB1355 0x0c не описан и не трогается).
- Наш разбор:
  1. **Само по себе пользователям ничего не даст**: `kernel/dts/` в репозитории — снимок, ядро собирается из `kernel/patches/` (APKBUILD
     linux-lenovo-j606f). Нужен патч 0025 (автор — kruzeman), pkgrel 122, сборка, проверка на нашем планшете, публикация в apk-репозитории.
     Также private src/dts и notes — иначе следующий export_repo.py перезапишет изменения PR.
  2. STATE.md: PR добавляет пункт «0d», а 0d у нас уже занят (UEFI/Windows, 5e959a9) → переименовать (0e).
  3. docs/notes/boot.md: утверждение «dtc теряет байт в свойствах, начинающихся с 0x00» сомнительно — в upstream dtc
     `util_is_printable_string()` отвергает пустые строки (`s == ss`), так что `00 31 51 00` печатается как `<0x315100>` и round-trip честный.
     Скорее всего, виноват другой инструмент автора. Совет «сначала побайтовый
     round-trip + cmp» сам по себе полезен — оставить, но без обвинения dtc (или с версией dtc и воспроизводимым примером).
  4. Мелочи: `interrupt-parent` рядом с `interrupts-extended` лишний (fusb302 у нас без него); второй блок `&tlmm` в конце файла —
     лучше в существующий; `scripts/fdtread.py`: мёртвая строка 182 (распаковка, сразу перезаписанная), нет shebang при режиме 755.
  5. Ветка english — перевести самим после слияния.

## 07.11 — отзыв тестера с 4PDA (TB-J606F HX83102P, **4 ГБ RAM**)
Установил pmOS в слот **a** (Android + Magisk в слоте b), прошёл путь Plasma → Phosh. Что из этого берём в работу:
- **4 ГБ-версия существует** (у нас 6 ГБ): Plasma тяжеловата. → в README упомянуть; подумать о варианте образа с Phosh.
- **Установка в слот a**: свой вариант скрипта (`flash boot_a`, `erase dtbo_a`, `--set-active=a`). → flash-all.sh/.bat: выбор слота
  (например `SLOT=a ./flash-all.sh`), по умолчанию b; предупреждение, что userdata общая.
- **Phosh**: phoc.ini `[output:DSI-1] rotate = 180` (панель в DT перевёрнута) + udev `LIBINPUT_CALIBRATION_MATRIX="-1 0 1 0 -1 1 0 0 1"`
  для himax-touchscreen и himax-pen. → можно положить в device-пакет (для Phosh) после проверки; в Plasma у нас kscreen rotation.left.
- **Автоповорот**: iio-sensor-proxy у тестера слал «мусорные» ориентации и ронял сессию (Phosh); тестер читает акселерометр через `ssccli`
  и крутит `wlr-randr` своим сервисом. → это наш открытый TODO `ACCEL_MOUNT_MATRIX` (hwdb в device-пакете); ssccli подтверждает, что SSC-акселерометр жив.
- **tuned powersave** — интерфейс «как кисель», помогает balanced. → проверить профиль tuned по умолчанию в образе (у нас tuned.service падает).
- **USB PD 9 В**: включённый тестером PD (своими PDO) уводил ICL в ноль; компромисс — только 5 В. У нас в DT `pd-disable` — совпадает, менять не надо.
- Сон замаскировал (CrashDump, известная проблема 0a); Power — свой watcher на pm8941_pwrkey для blank/unblank.
- Phosh на первом запуске ловил CrashDump (pstore пуст) — неясно, собирать подробности при повторе.
- ALS «не в IIO» — у нас свет идёт через libssc в iio-sensor-proxy; у тестера proxy замаскирован, поэтому и нет.

## 07.11 — Telegram (тот же kruzeman): «магнитная клава с тачбаром не работают, dmesg не реагирует» → сам прислал PR #1 (см. выше).
