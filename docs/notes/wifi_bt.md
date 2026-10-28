# Wi-Fi / Bluetooth

## Wi-Fi
- Сток: icnss (c800000.qcom,icnss), qcacld wlan.ko. `WLAN FW is ready: 0x587`, `Board id: 0, Board version: b 0 0 0 6`.
- Mainline: ath10k snoc (WCN3990-семейство), DTS уже содержит `&wifi` с calibration-variant "Lenovo_P11" и регуляторами pm6125 l8/l16/l17/l23.
- Прошивка: wlanmdsp.mbn (раздел modem, /vendor/firmware_mnt/image/), загружается MPSS (remoteproc_mpss, modem.mbn) → нужны modem.mbn и wlanmdsp.mbn.
- Board data: bdwlan.bin + bdwlan.<id> в /vendor/firmware_mnt/image/. Проверить, есть ли в linux-firmware ath10k/WCN3990/hw1.0/board-2.bin запись с variant=Lenovo_P11; если нет, собрать board-2.bin из bdwlan.bin (ath10k-bdencoder).
- MAC: <WIFI_MAC> (ro.odm.lenovo.wifiaddr); в Linux его надо задать (ath10k, скорее всего, даст случайный или из persist).

## Bluetooth
- Отдельный раздел bluetooth_a (sde5) монтируется в /vendor/bt_firmware. Файлы: apbtfw10/11.tlv, crbtfw11/20/21.tlv, apnv10/11.bin, crnv11/20/21.bin.
- Mainline: btqca. Тип чипа (WCN3950/3988/3990) пока не определён: ранний dmesg стока потерян (буфер начинается с 15 с). TODO: в Android `dmesg | grep -i bt` после выключения и включения BT, либо logcat vendor.qti.bluetooth.
- MAC BT: <BT_MAC>.
- В mainline DTS j606f BT не описан. UART для BT: по sm6115.dtsi (qup uart) выяснить по DT стока.

## BT SoC
getprop vendor.qcom.bluetooth.soc = **cherokee** (стек QTI называет так семейство WCN399x). В mainline: compatible qca,wcn3990 (stock DT: узел bt_wcn3990, compatible "qca,wcn3990"; uart = qup_uart@4a8c000 = mainline uart3).
Питание BT в стоке: vdd-io / core / pa / xtal из pm6125 (phandle 0x11..0x14), io 1.7–1.9 В, core 1.304 В, pa 3.0–3.3 В, xtal 1.7–1.9 В.

## ★ Результаты mainline 7.2.3 (2026-10-29)
### Wi-Fi — сканирование работает
- Нужно: remoteproc MPSS (modem.mbn) + rmtfs (EFS) + tqftpserv (отдаёт wlanmdsp.mbn) + in-kernel qrtr-ns и pd-mapper + ath10k_snoc.
- В отладке rmtfs работал на КОПИЯХ modemst1/2, fsg, fsc в RAM (`rmtfs -v -o /var/rmtfs`, файлы modem_fs1/modem_fs2/modem_fsg/modem_fsc). В pmOS rmtfs по умолчанию пишет в реальные разделы modemst*; так и задумано (EFS), но это запись в modem-разделы, поэтому включать только с ведома пользователя (бэкап есть).
- tqftpserv требует каталог /var/lib/tqftpserv.
- ath10k: chip_id 0x150, board_id 0xff, fw WLAN.HL.3.2.4-00564; board data из linux-firmware-ath10k подошла («cal file»). MAC случайный.
- iw scan: 4 BSS (2.4 + 5 ГГц), до −38 дБм. Подключение не проверено.
### Bluetooth — сканирование работает
- DTS: uart3 + pinctrl GPIO8–11 (qup3), alias serial1 = &uart3 (без него «qcom_geni_serial … Invalid line -19»), qcom,wcn3990-bt с L9/L16/L17/L23.
- Прошивки из стокового раздела bluetooth: qca/crbtfw21.tlv, qca/crnv21.bin. SOC Version 0x40020150, ROM 0x201.
- Контроллер стартует «Unconfigured» (нет публичного адреса) → `btmgmt public-addr <BT_MAC>` (ro.odm.lenovo.btaddr). Для pmOS: local-bd-address в DT (пишет ABL? нет) или сервис, задающий адрес при старте.
- btmgmt find -l: 21 уникальное LE-устройство. Сопряжение не проверено.
