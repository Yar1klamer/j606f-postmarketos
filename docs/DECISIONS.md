# DECISIONS

## 2026-10-28 — Фаза 1: что есть в апстриме (проверено по сети в этот день)

### Переименование проекта (наблюдение, не догадка)
- https://wiki.postmarketos.org/* отвечает 301 → https://wiki.nura.eco/* (проверено `curl -sI`)
- В GitLab-проекте pmaports описание «Nura package build recipes», у pmbootstrap «...install Nura». Последний тег pmbootstrap 3.12.1. Ветка по умолчанию pmaports: `main` (не master).
- Новые ядра в pmaports называются linux-nura-*.
- Страницу вики устройства прочитать не удалось: wiki.nura.eco закрыт Anubis (защита от ботов, error 9e4edb5b6b850c41). Обходить защиту не буду; попрошу пользователя открыть страницу в браузере.
- В шаблоне MR pmaports есть ссылка на AI policy: https://docs.postmarketos.org/policies-and-processes/development/ai-policy.html. **Прочитать до отправки чего-либо в апстрим (P3).**

### pmaports
- `device-lenovo-j606f` **нет** ни в main/community/testing/downstream/archived, истории коммитов по этим путям тоже нет (GitLab API tree+commits, ветка main).
- `device/testing/linux-nura-qcom-sm61x5`: pkgver 7.2.3, «Close to mainline linux kernel for Qualcomm Snapdragon SM61x5», maintainer Barnabas Czeman, исходники https://codeberg.org/sm61x5-mainline/linux (тег v7.2.3-r0, конфиг на основе sm6125_defconfig). Добавлено MR !9491 (merged 2026-10-08) https://gitlab.postmarketos.org/postmarketOS/pmaports/-/merge_requests/9491, там же device-пакеты xiaomi-laurel (Mi A3), ginkgo, willow.
- `device/archived/linux-postmarketos-qcom-sm6115` 6.10 (github.com/sm6115-mainline/linux), архивировано 2026-06-22 как unmaintained.
- MR !8048 «config-postmarketos-qcom-sm6115: enable support for NT36523» (для Tab P11) закрыт без мержа.
- Firmware-пакета для J606F нет. Есть https://github.com/sm6115-mainline/firmware-qcom-sm6115 (не изучал).

### Mainline Linux DTS
- `arch/arm64/boot/dts/qcom/sm6115p-lenovo-j606f.dts`, Copyright 2022 Linaro. Есть в torvalds/master и в codeberg sm61x5 v7.2.3-r0, файлы **побайтно одинаковы** (sha256 8664cb3e…). Копии лежат в notes/dts/.
- Включено: simplefb (1200x2000 @0x5c000000), gpio-keys Vol+, PON pwrkey/resin(Vol−), ramoops @0xffc00000 (1 MiB), GPU (zap qcom/sm6115/LENOVO/J606F/a610_zap.mbn), MDSS+DSI0+панель "lenovo,j606f-boe-nt36523w" (reset gpio82, rotation 180), ADSP/CDSP/MPSS (fw qcom/sm6115/LENOVO/J606F/{adsp,cdsp,modem}.mbn), регуляторы pm6125, SD (sdhc_2, cd gpio88), UFS, USB **только peripheral, high-speed**, Wi-Fi (ath10k, variant Lenovo_P11).
- **Не описано**: тачскрин, подсветка (sgm37604a), tps65132, батарея/зарядка (mm8013, pmi632), fusb302/Type-C, аудио, Bluetooth, датчики, камеры, клавиатура.
- По LKML (патч Konrad Dybcio «sm6115p-j606f: Hook up display», v2, июнь 2023, https://lkml.iu.edu/hypermail/linux/kernel/2306.2/05576.html): есть **второй SKU с другой связкой панели и тача**, он не поддержан. Нужно определить ревизию нашего экземпляра.

### Вывод для Фазы 2 (предварительный, решение не принято)
Mainline покрывает загрузку, UFS, дисплей (для BOE-SKU), GPU, Wi-Fi, кнопки, SD, USB-gadget. Это сильная база, поэтому **предпочтительно mainline на базе linux-nura-qcom-sm61x5** (апстрим-пакет, свежий, есть мейнтейнер). Downstream 4.19 не рассматриваю, пока не появится блокер. Недостающее (тач, подсветка, батарея, BT, аудио) придётся дописывать в DTS. Окончательное решение после подтверждения SKU панели.

## 2026-10-29 — по итогам root-разведки и первого запуска mainline
- **SKU**: у пользователя HX83102P (BOE) + тач HX83102E. Mainline DTS описывает NT36523W. Решение: отдельный DTS `sm6115p-lenovo-j606f-hx83102p.dts`,
  который включает базовый и переопределяет панель, плюс поддержка панели в panel-himax-hx83102.c (init из стокового DT).
  Для апстрима потом обсудить: один DTS на два SKU не сделать без выбора панели загрузчиком; два DTS — нормальная практика.
- **Ядро**: linux-nura-qcom-sm61x5 7.2.3 (Codeberg sm61x5-mainline). Загрузка проверена (USB-гаджет, UFS, simpledrm, thermal).
  В его config выключены HX83102, NT36523, TPS65132, MM8013: J606F этим пакетом не поддерживается. Нужен свой kernel-конфиг/фрагмент или MR в pmaports.
- **dtbo**: пока не трогаем раздел dtbo, обходим «отстойником» в DTB (notes/boot.md). Для pmaports это надо оформить: либо скрипт/хук в
  device-пакете, который дописывает /abl-sink и __symbols__ при сборке boot.img, либо документировать «прошить пустой dtbo».
- **Сборка без Linux-хоста** (временно, пока нет SSH-ключа): сборочное окружение Alpine в tmpfs на самом планшете под mainline,
  пакеты через HTTP-прокси на Mac (scripts/mirror_proxy.py). Ничего не пишется во внутреннюю память.

## 2026-10-29 — где собирать и куда ставить
- **Решение: собирать прямо на планшете** (8 ядер aarch64, нативно, без qemu) под mainline-ядром из fastboot boot.
  Рабочее место: раздел **userdata** (/dev/sda15, ≈110 ГиБ), форматируется в ext4 (пользователь разрешил снести Android).
  pmbootstrap внутри Alpine-chroot на userdata под отдельным пользователем с sudo (это наша собственная среда). Пакеты через HTTP-прокси на Mac.
- **Установка pmOS: раздел super** (12 ГиБ, бывшие system/vendor/product Android) под pmOS_boot+pmOS_root, boot.img в **boot_b**, слот b активный. Слот a (boot_a/dtbo_a) остаётся как есть, на случай отката загрузчика.
- Переход в fastboot без Android: в mainline есть reboot-mode PON (pm6125.dtsi: mode-bootloader = <0x2>, CONFIG_REBOOT_MODE=y) → `reboot bootloader`.
- Первая сборка pmOS: UI = none (консоль + SSH), затем UI по выбору пользователя.

## 2026-10-29 (днём) — установка и сборка ядра на Ubuntu
- **Установка выполнена не по install_plan.md**, а так: rootfs pmOS в **super** (12 ГиБ, бывшие system/vendor/product), boot.img в **boot_b**, активный слот **b**.
  userdata (sda15) оставлен под рабочее место pmbootstrap на планшете. dtbo не трогали: «отстойник» в DTB работает, пустой dtbo не проверяли.
  и освободил место (~24–29 ГБ). На планшете сборка ядра заняла бы 3–4 ч, и планшет нужен для проверки.
  Mac 127.0.0.1:8080) в scripts/mirror_proxy.py на Mac (с Mac 56–82 КБ/с, *.apk кэшируются). Прокси принимает только link-local, 127.0.0.1 и адреса из MIRROR_ALLOW.
- device-lenovo-j606f r3: без готовых .ko/.dtb (всё из ядра pkgrel 101), cmdline `console=tty0 fbcon=rotate:2 clk_ignore_unused pd_ignore_unused`,
  `/usr/lib/modules-load.d/j606f.conf` с mm8013. Ядро: patches 0001–0003 + config-фрагмент (HX83102, TPS65132, MM8013, NT36523 = m).
- HACK 0002 пока остаётся (ABL подменяет корневой compatible). Убрать можно только после проверки пустого dtbo_b.

## 2026-10-29 (вечер) — dtbo_b стёрт
- Совет напарника пользователя: если раздел dtbo стёрт, ABL берёт DTB из boot.img без оверлея. Проверено: `fastboot erase dtbo_b` → корневой compatible
  остаётся `lenovo,j606f`, model из нашего DTS. Решение: для pmOS на слоте b dtbo_b держать стёртым. abl-sink и HACK 0002 пока оставлены в ядре r101
  (безвредны, нужны, если dtbo вернётся); в следующей сборке ядра HACK 0002 убрать.
- GPU-прошивка (a630_sqe, a610_zap) кладётся в initramfs через /usr/share/mkinitfs/files (device r4), потому что msm в modules-initfs.

## 2026-10-29 (ночь) — корень в userdata, датчики, документация
- **rootfs pmOS перенесён из super (12 ГиБ) в userdata (~100 ГиБ)** по просьбе владельца («вся система на userdata»): в super оставалось ~6 ГБ.
  Перенос поблочный с теми же UUID, локальные настройки сохранены. GPT подразделов в super удалена (initramfs перебирает разделы по
  `/proc/diskstats` и иначе выбирает super первым), дамп таблицы сохранён. device r6: `deviceinfo_flash_fastboot_partition_rootfs="userdata"`.
- **Датчики через SSC**: свой патч hexagonrpcd (отдаёт `sns_reg_version`) как `temp/hexagonrpcd` 0.4.0-r50, а не правка раскладки на стороне ADSP;
  drop-in'ы с `-R` для сервисов hexagonrpcd. Файлы SSC — со своего устройства, в репозиторий не входят.
- Звук: начинать с разъёма наушников (PM4125/WCD937x, драйверы есть); динамики AW88258 — только по GPL-исходникам Awinic (риск повредить динамики).

## 2026-10-29 — тач: порт драйвера Lenovo, а не серия hid-himax
- Взят стоковый GPL-драйвер Lenovo (`himax83102p`, HX83102E zero-flash) из github.com/adazem009/kernel_lenovo_tbj606 и перенесён на 7.2 скриптом
  (`src/himax83102p-port/port.py`), а не серия Allen Lin «hid-himax» (HX83102J, протокол может отличаться). Скрипт оставляет исходники Lenovo нетронутыми
  и делает воспроизводимый патч 0006; драйвер один модулем `himax_hx83102e.ko` (=m в пакете ядра r106).
- Ориентация — стандартными `touchscreen-inverted-x/y` в DT (как у других драйверов), а не udev-матрицей libinput: работает для всех потребителей input.
- Прошивка тача (`Himax_firmware.bin`, `Himax_mpfw.bin`) — в локальном firmware-пакете r1 (не публикуется).

## 2026-10-30 — USB-C, GPU, apk-репозиторий
- USB-C: FUSB302 + буст по gpio38 (как сток), а не Type-C/OTG PMI632 (PMI632 Type-C в режиме micro-USB, его OTG-буст до разъёма не доходит). PD выключен,
  пока драйвер зарядника только читает.
- GPU: голосование за DDR по стоковой таблице kgsl (патч 0009) в common.dtsi — правка «под устройство», а не в sm6115.dtsi (для апстрима — в sm6115.dtsi).
  firmware-lenovo-j606f не публикуется (блобы конкретного устройства), скрипт отсекает его и всё с license = proprietary.
  (Пересмотрено 31.10: публикуется ровно один набор — общий сток S320208, см. ниже.)
- deviceinfo_flash_kernel_on_update пока не включаем — решение владельца (риск: битое ядро/обрыв питания при записи boot_b).
  (Пересмотрено: включено с device r7 — boot-deploy сам пишет boot_b; страховка — проверка через fastboot boot и бэкап boot_b перед установкой.)

## 2026-10-31 — прошивки, имя ядра, репозиторий
- Общий набор прошивок стока S320208 (Android 11) публикуется в apk-репозитории как `firmware-lenovo-j606f-0.320208-r1` (версия ниже личной `1-rN`,
  чтобы личная сборка всегда побеждала); исходный tar — в `j606f/distfiles`, sha256 сверяется при публикации. Любые другие firmware — нет.
- DSP-прошивку своего стока device-пакет берёт с разделов самого планшета (firmware-extract) и кладёт в /lib/firmware/updates: ADSP другой версии
  ломает датчики.
- Ядро переименовано в `linux-lenovo-j606f` (r118): пакет из обычных репозиториев не может его заменить, метка `@j606f` не нужна.
  Адрес репозитория и ключ — в device-пакете (r18), переход старых установок — `repo-migrate`.
- Звук: сначала динамики (TDM на LPI, свой драйвер AW88258 по GPL-исходникам), ES7210 и USB-C-гарнитура — потом; громкость ограничена (нет защиты стока).

## 2026-11-01 — камеры
- CAMSS SM6115 — своими таблицами (3× CSIPHY/CSID/TFE как у QCM2290), libcamera — своя сборка pmOS-пакета с хелперами сенсоров (temp/libcamera).
- Фронт S5K4H7 — свой драйвер по регистрам стокового CamX-модуля (в mainline драйвера нет). Путь CSID1/TFE1 вешает SoC → используем только CSID0/TFE0
  (libcamera выбирает его сам); CSID1 вручную не включать.
- Ядро проверяется через `fastboot boot` (текущий boot.img + новые vmlinuz/DTB) и только потом ставится через apk.

## 2026-11-02 — документация на английском
- Английская версия — бранч `english` того же GitHub-репозитория (перевод всех .md), а не отдельный репозиторий; main остаётся русским,
  в README main ссылка на бранч. Изменения документации переносятся в english вручную.

## 2026-11-02 — сон и датчики
- Помощник сна входит в device-пакет (r21, nt36523w r11). hexagonrpcd-adsp-rootpd/sensorspd восстанавливаются после сна, если enabled
  (а не по is-active: штатный `Conflicts=suspend.target` гасит их одновременно с нашим `pre`); запуск — из отдельного `j606f-resume.service`
  (After=suspend.target), штатные юниты hexagonrpcd не меняем.

## 2026-11-03 — образ для прошивки без возни
- Установка для всех — архив «как у Pixel»: userdata.img + boot.img + flash-all.{sh,bat} + SHA256SUMS + README.txt; скрипт проверяет product=bengal,
  unlocked=yes, sha256, просит YES; пишет userdata, boot_b, стирает dtbo_b, слот b. Слот a и прочие разделы не трогает.
- В образе нет блобов Lenovo: с r22 firmware-extract берёт с планшета всё (DSP, BT, zap, Himax, acf, датчики), поэтому с r23 -nonfree-firmware
  не зависит от firmware-lenovo-j606f; архив можно выкладывать на GitHub Releases. Общий набор 0.320208 остаётся в apk-репозитории для затёртого vendor.
- Первая загрузка чистой установки перезагружается сама один раз (zap GPU берётся из initramfs, прошивка тача — при probe).
- Образ собирается в отдельном workdir (pmb-work-release) из worktree pmaports без firmware-lenovo-j606f, без ssh-ключей, sshd выключен,
  пароль по умолчанию user/147147 (в README и посте — сменить через passwd).
- Перед проверкой образа на нашем планшете — бэкап userdata (только занятые блоки, Android sparse), восстановление через fastboot.
- 03.11: архив проверен на нашем планшете после восстановления стокового super (владелец выбрал «у нас»): наш super всё равно не нужен pmOS в userdata,
  а стоковый даёт firmware-extract vendor_a. Наша система затем возвращена из бэкапа userdata + boot_b (dtbo_b и так стёрт).
- GitHub Release — от имени владельца (автор релиза — сам владелец): официальный gh в ~/bin, вход (`gh auth login`) делает владелец сам,
  токены за владельца не вводим; черновик → публикация через API, проверка анонимным скачиванием. Текст — release/github_release.md.
- В README архива и посте 4PDA — предупреждение про CrashDump после сна и совет отключить автоматический сон, пока причина не найдена.
- Бэкап только по USB, e2image через ro-loop: заморозка / дольше пары минут роняет journald (watchdog 3 мин) и сеть по Wi-Fi.
- 03.11: Wi-Fi на нашей системе после восстановления из бэкапа — стоковый wlanmdsp.mbn из modem_a (раздел смонтирован только для чтения) положен в
  /lib/firmware/updates вручную, без пересборки пакета: обратимо (удалить файл), не трогает modem-разделы. Пересборка личного firmware 1-r4 — позже.
- 03.11: кнопки громкости проверены evtest (KEY_VOLUMEDOWN — pm8941_resin, KEY_VOLUMEUP — gpio-keys): ядро и DT в порядке.
- 04.11: новое направление — UEFI (Project Aloha mu_aloha_platforms) и Windows on ARM. Ведётся отдельно: подпапка `../uefi-winarm/`, свой чат,
  свои STATE/LOG; общие правила (без записи в modem/persist/abl/xbl, спрашивать перед fastboot flash, пароли/токены не вводить) — те же.
  pmOS остаётся основной системой: UEFI сначала только через `fastboot boot`.

## 07.11
- PR #1 (kruzeman, пого-док) принят как патч ядра 0025 → linux-lenovo-j606f r122 (узлы перенесены в существующие блоки, лишний interrupt-parent убран),
  PR слит merge-коммитом (авторство сохранено). Утверждение PR про dtc не берём (upstream dtc round-trip честный), совет «cmp после round-trip» — берём.
- Ядро на планшете больше не ставим через boot-deploy: при `androidboot.slot_suffix=_a` он писал бы в boot_a (UEFI), а mkbootimg (Python) падает.
  boot.img собираем на Mac (scripts/mkbootimg_v2.py), пишем в boot_b вручную с cmp и контролем sha256 boot_a.
- `fastboot boot` для проверки ядра — только при активном слоте b (dtbo_a стоковый); после проверки слот возвращаем, как его оставила сессия uefi-winarm.
