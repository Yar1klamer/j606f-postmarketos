# Датчики

Все за SSC (Qualcomm Snapdragon Sensor Core на ADSP), а не на I2C Linux:
- акселерометр + гироскоп TDK icm4x6xx
- освещённость Lite-On ltr578
- ToF/proximity ams tmf8801
- SAR Semtech sx932x (virtualsar на I2C1 0x33 для «vitural-sar» input)

В Linux нужно: ADSP remoteproc + fastrpc + hexagonrpcd + libssc + iio-sensor-proxy (SSC-путь, работает на других qcom-устройствах в pmOS). Нужны /vendor/dsp/* и sns-регистрация (/mnt/vendor/persist/sensors, есть в BACKUP/firmware/mnt_vendor_persist.tar). Сложно, P1.

## Попытка SSC в mainline (2026-10-29) — не получилось, 3 попытки (LOG.md)
- ADSP стартует со стоковым adsp.mbn; fastrpc.ko даёт /dev/fastrpc-adsp; hexagonrpcd 1.x и libssc (ssccli) из Alpine community.
- Конфиги взяты read-only из стоковых vendor_a (в super, смещение 0xebf00000) и dsp_a; реестр — копия из persist.
- hexagonrpcd: ADSP пытается писать в registry (sns_reg_version, temp.json), а hexagonrpcd пишет «Tried to open … for writing»; затем «Could not read from directory: Bad file descriptor» и «Broken pipe».
- Ищем рабочую раскладку файлов, как в firmware-пакетах pmOS для других qcom-устройств с hexagonrpcd (папка /usr/share/qcom/<soc>/<vendor>/<device>/, а реестр, возможно, в /var/lib/hexagonrpcd).
