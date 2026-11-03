postmarketOS (Plasma Desktop) для Lenovo Tab P11 TB-J606F — ревизия с панелью HX83102P
=====================================================================================

Проект: https://github.com/Yar1klamer/j606f-postmarketos

ЧТО НУЖНО
- Lenovo Tab P11 TB-J606F (Wi-Fi). J606L/J606N и ревизия с панелью NT36523W — не этот архив.
  Ревизию видно в Android: adb shell cat /proc/cmdline | grep -o "dsi_display0=[^ ]*"
  (hx83102p — этот архив; nt36523w — другой).
- Разблокированный загрузчик (fastboot getvar unlocked → yes).
- Компьютер с fastboot (Android platform-tools) и кабель USB-C.
- Все данные Android в userdata будут стёрты. Сделайте копию.

УСТАНОВКА
1. Распакуйте архив целиком в одну папку.
2. Выключите планшет, зажмите Громкость− и Питание → режим fastboot. Подключите к компьютеру.
3. Запустите скрипт:
   - Windows: flash-all.bat (fastboot.exe из platform-tools положите рядом или добавьте в PATH);
   - macOS / Linux: ./flash-all.sh  (или FASTBOOT=/путь/к/fastboot ./flash-all.sh).
4. Скрипт проверит файлы и планшет, спросит подтверждение (введите YES) и прошьёт:
   userdata ← userdata.img, boot_b ← boot.img, сотрёт dtbo_b, сделает активным слот b.
   Слот a (Android: boot_a, dtbo_a, vbmeta_a) и остальные разделы не трогаются.

ПЕРВАЯ ЗАГРУЗКА
- Прошивки Lenovo (DSP, Wi-Fi, Bluetooth, GPU, тач, динамики, датчики) в архиве НЕТ: система
  сама берёт их только для чтения из разделов вашего планшета (modem, bluetooth, dsp, vendor, persist)
  и один раз перезагружается. Ничего в эти разделы не пишется.
- Пользователь: user, пароль: 147147. Смените пароль сразу: в Konsole выполните passwd.
- Датчики (поворот, освещённость) появляются примерно через 2 минуты после загрузки.

ОБНОВЛЕНИЯ
- Обычные обновления системы и порта: sudo apk upgrade (или Discover).
  Репозиторий порта (ядро, пакет устройства) уже подключён.

ВЕРНУТЬСЯ В ANDROID
- Если в слоте a рабочий Android: в fastboot выполните  fastboot --set-active=a  и  fastboot reboot.
  Данные Android (userdata) уже стёрты, Android начнёт с первоначальной настройки.
- Иначе — прошивка стока (Lenovo Rescue and Smart Assistant / QFIL).

ЧТО НЕ РАБОТАЕТ / ИЗВЕСТНО
- Микрофоны и гарнитура (USB-C) — нет. Офлайн-зарядка — в процессе.
- Сон экспериментальный: через пару минут после выхода из сна планшет может упасть в CrashDump
  (чёрный экран с текстом). Тогда зажмите Питание ~15 с. Пока не исправлено, лучше отключить
  автоматический сон: Параметры системы → Управление питанием → «Переходить в спящий режим» — выкл.
- Задняя камера: фокус ручной. Подробно — README проекта на GitHub.

-------------------------------------------------------------------------------------
English, short
- For TB-J606F with the HX83102P panel only. The bootloader must be unlocked. userdata is erased.
- Boot to fastboot (Vol- + Power), run flash-all.bat (Windows) or ./flash-all.sh (macOS/Linux), type YES.
- No Lenovo firmware is shipped: the system reads it from the tablet's own partitions on the first boot
  and reboots once. Login: user / 147147 — change it with passwd.
- Updates: sudo apk upgrade. Back to Android (if slot a has it): fastboot --set-active=a.
- Sleep is experimental: the tablet may crash (CrashDump) a few minutes after a resume.
  Hold Power ~15 s to recover; better turn automatic sleep off in System Settings -> Power Management.
