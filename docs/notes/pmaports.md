# Сборка образа pmOS (Nura) через pmbootstrap

> **Статус 02.11:** пакеты порта в `pmaports/` этого репозитория: ядро **linux-lenovo-j606f 7.2.3-r121** (linux-nura-qcom-sm61x5 + патчи 0001, 0003–0024;
> с 31.10/r118 своё имя, `replaces` старого пакета), device-lenovo-j606f **r20**, device-lenovo-j606f-nt36523w **r10**, firmware-lenovo-j606f
> (личный APKBUILD + `APKBUILD.shared` для общего набора 0.320208), temp/hexagonrpcd **0.4.0-r50**, temp/libcamera **99990.7.2-r6** (0007 OV13B10, 0008 S5K4H7).
> Сборка на хосте, установка и обновление — через apk (STATE.md §4), раздача — apk-репозиторий (README).
> Разделы ниже — исходные шаги 28–29.10 (под старым именем ядра) с пометками, что изменилось.


## 1. Ядро: локальная доработка linux-nura-qcom-sm61x5 (7.2.3)
> Сейчас это отдельный пакет `device/testing/linux-lenovo-j606f` (патчи 0001, 0003–0024 и config-j606f.fragment уже в нём); ниже — как начиналось.

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

## 5. Что ещё нужно в DTS/драйверах (по notes/*, на 02.11)
- ✓ тач HX83102E SPI (zero-flash) — порт драйвера Lenovo, патч 0006;
- зарядка pmi632: свой драйвер только на чтение (патч 0004), запись лимитов не сделана; smb1355 — нет драйвера;
- MAC Wi-Fi/BT: ABL не передаёт; сейчас стабильные адреса из serialno даёт bootmac (device r5), заводские из persist не берём;
- ~~медленные page flip в msm~~ — оказалось артефактом теста (modetest без stdin), реально 60 Гц (notes/display.md);
- аудио: ✓ динамики AW88258 (0012–0016); нет ES7210 (микрофоны) и гарнитуры через USB-C/FSA4480 (notes/audio.md);
- датчики (SSC) — **работают** (notes/sensors.md); drop-in'ы hexagonrpcd и файлы SSC не упакованы;
- камеры: ✓ OV13B10 + DW9763, S5K4H7 (0017–0024); нет автофокуса, вспышки PMI632, тюнинга libcamera (notes/camera.md);
- сон: помощник j606f-sleep не упакован (notes/suspend.md); Hall, pogo-клавиатура, вибромотор, светодиод — не описаны.

## 6. Апстрим (P3)
Перед любым MR прочитать AI policy: https://docs.postmarketos.org/policies-and-processes/development/ai-policy.html
