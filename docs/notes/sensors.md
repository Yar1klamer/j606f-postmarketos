# Датчики

Все за SSC (Qualcomm Snapdragon Sensor Core на ADSP), а не на I2C Linux:
- акселерометр + гироскоп TDK icm4x6xx
- освещённость Lite-On ltr578
- ToF/proximity ams tmf8801
- SAR Semtech sx932x (virtualsar на I2C1 0x33 для «vitural-sar» input)

В Linux нужно: ADSP remoteproc + fastrpc + hexagonrpcd + libssc + iio-sensor-proxy (SSC-путь, работает на других qcom-устройствах в pmOS). Нужны /vendor/dsp/* и sns-регистрация (/mnt/vendor/persist/sensors, есть в BACKUP/firmware/mnt_vendor_persist.tar). Сложно, P1.

## Статус (2026-10-29, ночь): **работают** свет, приближение, акселерометр (подробно ниже и в NOTES п. 41–42)

## Попытки SSC в mainline (2026-10-29), 1–3 не получились (история, LOG.md)
- ADSP стартует со стоковым adsp.mbn; fastrpc.ko даёт /dev/fastrpc-adsp; hexagonrpcd 1.x и libssc (ssccli) из Alpine community.
- Конфиги взяты read-only из стоковых vendor_a (в super, смещение 0xebf00000) и dsp_a; реестр — копия из persist.
- hexagonrpcd: ADSP пытается писать в registry (sns_reg_version, temp.json), а hexagonrpcd пишет «Tried to open … for writing»; затем «Could not read from directory: Bad file descriptor» и «Broken pipe».
- Ищем рабочую раскладку файлов, как в firmware-пакетах pmOS для других qcom-устройств с hexagonrpcd (папка /usr/share/qcom/<soc>/<vendor>/<device>/, а реестр, возможно, в /var/lib/hexagonrpcd).

## ★ Попытка 4 — работает (2026-10-29, ночь)
- Корень `-R /usr/share/qcom/sm6115/LENOVO/J606F`, раскладка по виртуальным путям hexagonrpcd (`rpcd_builder.c`), **плоско**:
  `dsp/adsp/` (из dsp_a), `sensors/config/` и `sensors/sns_reg.conf` (из vendor `/etc/sensors`), `sensors/registry/` + `sensors/sns_reg_version` (из persist), `socinfo/`.
- ADSP SM6115 без `sns_reg_version` рядом с реестром пытается его пересобрать (`temp.json`) → запись запрещена → «'registry' sensor unavailable».
  hexagonrpcd 0.4.0 файл не отдаёт → патч `pmaports/temp/hexagonrpcd` (0.4.0-r50, `0001-rpcd-serve-sns_reg_version-next-to-the-registry.patch`).
- `apk add hexagonrpcd` включает сервисы rootpd/sensorspd **без `-R`** → ADSP падает каждые ~4 с. Нужны drop-in'ы
  `/etc/systemd/system/hexagonrpcd-adsp-{rootpd,sensorspd}.service.d/j606f.conf` (`ExecStart=` + `ExecStart=/usr/bin/hexagonrpcd -f /dev/fastrpc-adsp -d adsp [-s] -R …/J606F`).
- Результат: `ssccli` — Light ≈231 лк, Proximity FAR, Accelerometer (8.30, 0.12, 5.28) м/с² (|g| ≈ 9.84); `monitor-sensor` (iio-sensor-proxy) видит все три. Падений ADSP нет.
- Не сделано: `ACCEL_MOUNT_MATRIX` (udev-правило, как `81-libssc-*.rules`) для автоповорота — подобрать с владельцем; гироскоп/SAR не выводились;
  упаковка: drop-in'ы и зависимость hexagonrpcd r50 → device-пакет, файлы SSC (со своего устройства) → приватный firmware-пакет.
