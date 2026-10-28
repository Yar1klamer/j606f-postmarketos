# DEVICE_INFO — всё только из вывода команд на устройстве

Источники: raw/adb_20261028_232150/ (adb shell без root, uid=shell), raw/fastboot_20261028_232246/.
Root нет (`su: inaccessible or not found`), поэтому /proc/cmdline, dmesg, /proc/partitions,
/proc/bus/input/devices, /proc/asound, /proc/device-tree выдают Permission denied. Это ещё предстоит получить.

## Идентификация (getprop)
| Параметр | Значение |
|---|---|
| ro.product.model | Lenovo TB-J606F |
| ro.product.name | LenovoTB-J606F_RU |
| ro.odm.lenovo.sku / tablet | m11_row_wifi / wifi → **Wi-Fi-версия, без LTE (подтверждено)** |
| ro.boot.baseband | apq |
| serial | <SERIAL> |
| Android | 10 (SDK 29), build QKQ1.200730.002 |
| Прошивка | TB-J606F_S120184_210520_ROW (incremental TB-J606F_USR_S120184_2105202124_Q00287_ROW) |
| Патч безопасности | 2021-05-05 |
| fingerprint | Lenovo/LenovoTB-J606F_RU/J606F:10/QKQ1.200730.002/S120184_210520_ROW:user/release-keys |
| ro.board.platform | bengal (= SM6115 семейство) |
| /proc/cpuinfo Hardware | Qualcomm Technologies, Inc BENGALP |
| CPU | 8 ядер: 4× part 0x801 (Kryo 260 Silver) + 4× part 0x800 (Kryo 260 Gold), implementer 0x51 → согласуется с SM6115(P)/SD662 |
| RAM | MemTotal 5799328 kB → **6 ГБ, а не 4 ГБ, как предполагалось** |
| Хранилище | UFS, 4804000.ufshc; userdata 0x199CCD3000 (~110 GiB) → модель на 128 ГБ |
| Ядро стока | Linux 4.19.95-perf+, clang 8.0.16, собрано 2021-05-20 |
| bootreason | shutdown,userrequested |
| ro.boot.dtb_idx / dtbo_idx | 1 / 9 |

## Загрузчик / AVB / слоты (fastboot getvar)
- product: bengal, variant: SMP UFS, hw-revision: 10000, secure: yes, **unlocked: yes**
- **current-slot: a**; slot-count 2
- slot a: successful=yes, unbootable=no, retry=6
- slot b: successful=**no**, retry=0 → слот b никогда не загружался, не трогать
- is-userspace: no (это bootloader-fastboot, не fastbootd), kernel: uefi, max-download-size 805306368 (768 MiB)
- version-bootloader и version-baseband пустые
- off-mode-charge 1, charger-screen-enabled 1
- ro.boot.verifiedbootstate=orange, vbmeta.device_state=unlocked, veritymode=enforcing, avb 1.1 (vbmeta avb 1.0)
- ro.boot.vbmeta.digest = 5c7f5b1f1fa6d982a97119e4e3e19c2198dc73d488b26be6edbd72d0f748fd82 (sha256, size 5952) → по нему можно проверить, что скачанный сток совпадает с установленным
- dynamic_partitions=true (super 0x300000000 = 12 GiB), отдельные recovery_a/b (A/B + отдельный recovery, как при запуске на Android 10)

## Разметка (by-name, UFS LUN)
- sda (LUN0): ssd=1 persist=2 misc=3 keystore=4 frp=5 fpinfo=6 lenovocust=7 lenovoraw=8 recovery_a=9 recovery_b=10 vbmeta_system_a=11 vbmeta_system_b=12 metadata=13 super=14 userdata=15
- sdb/sdc (LUN1/2): xbl_a/xbl_config_a (sdb1,2), xbl_b/xbl_config_b (sdc1,2)
- sdd (LUN3): ALIGN_TO_128K_1=1 cdt=2 ddr=3
- sde (LUN4): rpm_a=1 tz_a=2 hyp_a=3 modem_a=4 bluetooth_a=5 mdtpsecapp_a=6 mdtp_a=7 abl_a=8 dsp_a=9 keymaster_a=10 boot_a=11 cmnlib_a=12 cmnlib64_a=13 devcfg_a=14 qupfw_a=15 vbmeta_a=16 dtbo_a=17 imagefv_a=18 uefisecapp_a=19 featenabler_a=20; *_b = 21..40; devinfo=41 dip=42 apdp=43 spunvm=44 splash=45 limits=46 toolsfv=47 logfs=48 cateloader=49 rawdump=50 logdump=51 storsec=52 multiimgoem=53 multiimgqti=54 uefivarstore=55 secdata=56 catefv=57 catecontentfv=58
- sdf (LUN5): ALIGN_TO_128K_2=1 modemst1=2 modemst2=3 fsg=4 fsc=5
- Размеры: boot 96 MiB, recovery 96 MiB, dtbo 24 MiB, vbmeta 64 KiB, dsp 32 MiB, modem 180 MiB, persist 32 MiB, modemst1/2 и fsg по 2 MiB, devinfo 4 KiB, cdt 128 KiB
- Полный список: raw/adb_20261028_232150/by_name.txt, raw/fastboot_20261028_232246/getvar_all.txt

## Дисплей
- 1200x2000 (физически портрет), 60 Гц, density 240, 213×216 dpi; в Android по умолчанию ландшафт (rotation 1)
- Подсветка: I2C 1-0036 → драйвер **sgm37604a**; питание панели: I2C 1-003e → **tps65132** (±5V bias)
- Модель панели НЕ подтверждена: в mainline описана BOE NT36523W, а у J606F есть вторая ревизия с другой связкой панели и тача (см. DECISIONS). Нужен cmdline или DT стока.

## Ввод
- I2C 0-0060 и 1-0061: hid-over-i2c (i2c_hid). Скорее всего, это тач и/или клавиатура/тачпад (power_supply «touchpad» есть). Не подтверждено.
- SPI: spi0.0, spi0.1 (4a88000.spi), spi1.0 (4a94000.spi), драйверы не прочитаны (устройство ушло с USB)
- Кнопки (по mainline DTS, на устройстве не проверено): Vol+ = pm6125 gpio5, Vol− = PON resin, Power = PON pwrkey

## Питание / зарядка
- PMIC: pm6125 (spmi 0), pmi632 (spmi 2), pm2250 (spmi_dlkm, аудио rouleur)
- power_supply: battery, bms, customer, main, mm8013, parallel, pc_port, touchpad, usb
- Fuel gauge: **mm8013** (I2C 0-0055)
- Type-C: **fusb302** (I2C 0-0022); аудиосвитч USB-C **fsa4480** (I2C 1-0042)
- Батарея: Li-ion, при проверке 100%, 4337 мВ

## Аудио
- Усилители: **aw882xx** ×4 (I2C 0-0034..0037), модуль aw88258_4pa_dlkm
- АЦП микрофонов: **es7210** (I2C 1-0040)
- Кодек: wcd937x + rouleur (pm2250), bolero (rx/tx/va macro), ADSP/q6 (apr)

## Wi-Fi / BT
- wlan.ko (qcacld стока); MAC Wi-Fi <WIFI_MAC>, BT <BT_MAC> (ro.odm.lenovo.*)
- По mainline DTS: ath10k snoc (WCN39xx), calibration-variant "Lenovo_P11"
- Есть отдельный раздел bluetooth_a/b (BT-прошивка, sde5)

## Датчики (через Qualcomm SSC/SLPI на ADSP, не напрямую через I2C)
- Акселерометр + гироскоп: TDK icm4x6xx
- Освещённость: Lite-On ltr578
- Близость / ToF: ams tmf8801
- SAR: Semtech sx932x (I2C 1-0033 virtualsar)
- В Linux это потребует hexagonrpcd + libssc / iio-sensor-proxy с SSC. Сложно, P1.

## Прочее I2C
0-004e (без драйвера), 1-0009 (без драйвера), 1-000c (i2c_pmic)

## IIO
iio:device0 = pmi632 vadc, iio:device1 = pm6125 vadc

## USB-идентификатор (macOS, Android)
18d1:4ee7, bcdDevice 4.19, 480 Mb/s (USB 2.0)

## Дополнено 2026-10-29 (root + mainline)
- /proc/cmdline стока: `msm_drm.dsi_display0=qcom,mdss_dsi_himax83102p_boe_2k_video:` → **панель Himax HX83102P (BOE)**; тач **Himax HX83102E zero-flash** на SPI0 (QUP SE2, 4a88000), irq tlmm 86, reset tlmm 54; стилус (himax-pen).
- soc0: soc_id 445, family Snapdragon, machine BENGALP, revision 1.0, hw_platform IDP. ABL: UEFI 5.0.210904.BOOT.XF.4.1-00218-KAMORTALAZ-1, Loader Build Sep 4 2021. UFS: MICRON MT128GASAO4U21 0106.
- Батарея (mm8013 в mainline): design 7500 мАч, full 6596 мАч, 328 циклов. Стоковый QG: CHARGE_FULL_DESIGN 7518000.
- Wi-Fi: WCN3990 (ath10k qmi chip_id 0x150, chip_family 0x4002, board_id 0xff, soc_id 0x40670000), FW WLAN.HL.3.2.4-00564-QCAHLSWMTPLZ-1.
- BT: WCN3990 «cherokee», QCA SOC Version 0x40020150, ROM 0x201, прошивки crbtfw21.tlv / crnv21.bin.
- GPU: Adreno610v1 (стоковый kgsl), в mainline FD610 (Mesa 26.2.5), частоты стока 320–950 МГц.
- CPU (mainline cpufreq-hw): little до 1804800 кГц, big до 2016000 кГц.
- Усилители aw882xx: reg0 = 0x1852 ×4. АЦП es7210. LCD bias TPS65132 ±5.7 В. Подсветка SGM37604A (I2C1 0x36, en = pmi632 gpio6), управление DCS 12 бит.
- Разметка super: system_a 1415360512 @+0x100000, product_a 2540896256 @+0x54700000, vendor_a 708902912 @+0xebf00000 (ext4), *_b пустые.
- dtbo_a: 13 записей, ABL выбирает [9] «Lenovo P11 WIFI PVT» (msm-id 445/420, board-id 34/3).
