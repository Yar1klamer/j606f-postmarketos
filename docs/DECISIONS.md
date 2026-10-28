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
