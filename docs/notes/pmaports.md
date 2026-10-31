# Сборка образа pmOS (Nura) через pmbootstrap

> **С 31.10:** пакет ядра переименован в `linux-lenovo-j606f` (r118; те же файлы и uname-суффикс, `replaces` старого), см. README «Обновления через apk-репозиторий». Ниже — история под старым именем.

> **Статус 29.10 (ночь):** ядро linux-nura-qcom-sm61x5 **7.2.3-r105** (патчи 0001, 0003, 0004, 0005; без HACK 0002), device-lenovo-j606f **r6**
> (на планшете r5), firmware-lenovo-j606f r0, temp/hexagonrpcd 0.4.0-r50. Собираются на хосте, ставятся обновлением через apk (STATE.md §4).
> Локальные коммиты в src/pmaports-main: ядро c523e3a (r101), 06429e1 (r102), d97938f (r103), b2ad809 (r104), 7a93404 (r105);
> device 4a3d060 (r4), 7b52c2d (r5), 9d0a730 (r6, rootfs → userdata); hexagonrpcd 7adbd16. История (до r101): 9f25afd, 02cd3cd, f0ab532.


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
- rootfs: userdata (110 ГиБ, данные не важны, но форматировать только с явного «да»). Сначала было иначе (rootfs в super, userdata под сборку), **с 29.10 (ночь) rootfs в userdata** (заметки автора, device r6: `deviceinfo_flash_fastboot_partition_rootfs="userdata"`);
- `fastboot set_active b`; откат: `fastboot set_active a`. pmOS должен помечать слот успешным (qbootctl), иначе ABL через ~7 попыток вернётся на a.
Вариант B: слот a (заменить Android). Откат: BACKUP/.

## 5. Что ещё нужно в DTS/драйверах (по notes/*)
- тач HX83102E SPI (zero-flash) — нет драйвера;
- зарядка pmi632: свой драйвер только на чтение (патч 0004), запись лимитов не сделана; smb1355 — нет драйвера;
- MAC Wi-Fi/BT: ABL не передаёт; сейчас стабильные адреса из serialno даёт bootmac (device r5), заводские из persist не берём;
- ~~медленные page flip в msm~~ — оказалось артефактом теста (modetest без stdin), реально 60 Гц (notes/display.md);
- аудио (aw88258, es7210, wcd937x/pm4125) — не начато (notes/audio.md); датчики (SSC) — **работают** (notes/sensors.md), не упакованы.

## 6. Апстрим (P3)
Перед любым MR прочитать AI policy: https://docs.postmarketos.org/policies-and-processes/development/ai-policy.html
