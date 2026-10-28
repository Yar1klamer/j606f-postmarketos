# План установки во внутреннюю память (НЕ ВЫПОЛНЯЛОСЬ — нужно явное «да» пользователя)

Все шаги ниже пишут во внутреннюю память. Перед каждым убедиться, что бэкап на месте (BACKUP/README.md, sha256).

## Вариант A (рекомендую): pmOS на слоте b, Android на слоте a остаётся
Слот b ни разу не загружался (`slot-successful:b:no`), в нём заводские копии. Android на a не трогаем.

### Шаг A0. Проверка, примет ли ABL пустой dtbo (без «отстойника» и без HACK 0002)
Пишет только dtbo_b (24 МиБ раздел; файл out/dtbo_empty.img: валидная DTBO-таблица с 0 записей, sha256 51c15f49…).
```bash
~/platform-tools/fastboot flash dtbo_b out/dtbo_empty.img
~/platform-tools/fastboot --set-active=b
~/platform-tools/fastboot reboot bootloader
~/platform-tools/fastboot boot out/<образ с DTB БЕЗ отстойника>.img
```
Ожидание: ABL не накладывает оверлей → корневой compatible остаётся «lenovo,j606f», ubwc_config/pd_mapper работают без HACK.
Если ABL не грузит: `fastboot --set-active=a` (Android цел), а для pmOS остаётся вариант с отстойником (проверен).
Откат: `fastboot flash dtbo_b BACKUP/partitions/dtbo_b.img; fastboot --set-active=a`.

### Шаг A1. Ядро pmOS → boot_b
```bash
~/platform-tools/fastboot flash boot_b boot.img        # из pmbootstrap export
```
Откат: `fastboot flash boot_b BACKUP/partitions/boot_b.img`.

### Шаг A2. rootfs
userdata (≈110 ГиБ) → rootfs pmOS. **Стирает данные Android** (пользователь сказал, что не важны; всё равно спросить ещё раз прямо перед шагом).
```bash
~/platform-tools/fastboot flash userdata <rootfs>.img   # pmbootstrap export, sparse
```
Android на слоте a после этого будет без данных (factory reset). Он загрузится, если отформатировать userdata заново (LMSA/recovery).
Альтернатива без потери Android-данных: rootfs на SD-карте (нужна карта).

### Шаг A3. Активный слот
```bash
~/platform-tools/fastboot --set-active=b && ~/platform-tools/fastboot reboot
```
pmOS должен помечать загрузку успешной (qbootctl -m), иначе ABL через несколько попыток вернётся на a.

## Вариант B: заменить Android на слоте a
То же самое, но boot_a/dtbo_a. Откат: BACKUP/partitions/{boot_a,dtbo_a}.img или BACKUP/stock/boot_a_stock_from_magisk.img.

## Аварийный откат всего
EDL + qdl + полная прошивка Lenovo (см. вики, Back to stock) или BACKUP/partitions/*.img (все разделы, кроме userdata).

## Что включать осторожно
- rmtfs в pmOS пишет в modemst1/modemst2/fsg (EFS) — это модемные разделы. Бэкап есть, но включать с ведома пользователя.
