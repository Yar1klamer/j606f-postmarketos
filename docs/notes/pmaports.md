# Сборка образа pmOS (Nura) через pmbootstrap

> **Статус 29.10:** схема проверена. Первая установка собрана pmbootstrap на самом планшете (бинарное ядро 7.2.3-r0 + модули/DTB в device-пакете),
> установлена и грузится (STATE.md). Сейчас ядро с патчами (pkgrel 101) собирается на Ubuntu-хосте; device-пакет r3 уже без готовых модулей.
> Локальные коммиты в src/pmaports-main: 9f25afd, 02cd3cd, f0ab532, c523e3a.


## 1. Ядро: локальная доработка linux-nura-qcom-sm61x5 (7.2.3)
В локальной копии pmaports: device/testing/linux-nura-qcom-sm61x5/
- добавить в source= и в prepare() (default_prepare применит *.patch):
  - src/patches/0001-drm-panel-himax-hx83102-add-Lenovo-J606F-BOE-HX83102P.patch (панель: init из стока, тайминги, DCS-подсветка)
  - src/patches/0003-arm64-dts-qcom-sm6115p-lenovo-j606f-add-HX83102P-SKU.patch (DTS + abl-sink.dtsi + Makefile)
  - src/patches/0002-HACK-soc-qcom-match-qcom-bengalp-root-compatible.patch — ТОЛЬКО если оставляем стоковый dtbo (см. п. 4)
- в config-nura-qcom-sm61x5.aarch64: src/patches/config-j606f.fragment (HX83102, TPS65132, MM8013, NT36523 = m)
- `pmbootstrap checksum linux-nura-qcom-sm61x5`
Все три патча проверены: `git apply --check` на теге v7.2.3-r0 (коммит 5a88d98) проходит; 0001+0002 и собранные модули проверены на устройстве; DTS собран и загружен (тесты 5–7).

## 2. Device- и firmware-пакеты
- src/pmaports/device/testing/device-lenovo-j606f/{APKBUILD,deviceinfo,modules-initfs} → в pmaports/device/testing/
- src/pmaports/device/testing/firmware-lenovo-j606f/APKBUILD + тарбол firmware-lenovo-j606f-1.tar:
  qcom/sm6115/LENOVO/J606F/{a610_zap,adsp,cdsp,modem,wlanmdsp}.mbn (out/fw), qca/{crbtfw21.tlv,crnv21.bin} (out/serve/fwbt/qca).
  Блобы с ЭТОГО устройства, не публиковать.
- Пакеты из зависимостей существуют: msm-firmware-loader, linux-firmware-qcom, linux-firmware-ath10k (pmOS/Alpine), rmtfs, tqftpserv, qbootctl, hexagonrpcd, iio-sensor-proxy (Alpine community). Проверено по APKINDEX 2026-10-29.

## 3. Сборка
```bash
pmbootstrap init            # device: lenovo-j606f, UI: по выбору пользователя
pmbootstrap install         # rootfs
pmbootstrap export          # boot.img и rootfs-образ в /tmp/postmarketOS-export
```
Первый тест: только `fastboot boot boot.img` (ядро+initramfs pmOS), rootfs с SD-карты или по USB (pmOS initramfs debug-shell).

## 4. Установка во внутреннюю память — РЕШЕНИЕ ПОЛЬЗОВАТЕЛЯ
Вариант A (рекомендую): **слот b** под pmOS, Android на слоте a не трогаем.
- `fastboot flash boot_b boot.img`; dtbo_b: пустой dtbo (mkdtboimg без записей) → ABL не наложит оверлей, тогда HACK 0002 и abl-sink не нужны (проверить!);
- rootfs: userdata (110 ГиБ, данные не важны, но форматировать только с явного «да»). **Сделано иначе: rootfs в super, userdata под сборку;**
- `fastboot set_active b`; откат: `fastboot set_active a`. pmOS должен помечать слот успешным (qbootctl), иначе ABL через ~7 попыток вернётся на a.
Вариант B: слот a (заменить Android). Откат: BACKUP/.

## 5. Что ещё нужно в DTS/драйверах (по notes/*)
- тач HX83102E SPI (zero-flash) — нет драйвера;
- зарядка pmi632/smb1355 — нет драйвера;
- MAC Wi-Fi/BT: ABL не передаёт, нужно из persist/userspace (сейчас Wi-Fi со случайным MAC, BT с адресом, заданным вручную);
- ~~медленные page flip в msm~~ — оказалось артефактом теста (modetest без stdin), реально 60 Гц (notes/display.md);
- аудио (aw88xxx, es7210, wcd937x/pm4125) и датчики (SSC) — не начаты.

## 6. Апстрим (P3)
Перед любым MR прочитать AI policy: https://docs.postmarketos.org/policies-and-processes/development/ai-policy.html
