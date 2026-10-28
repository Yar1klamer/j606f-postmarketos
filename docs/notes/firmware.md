# Прошивки (источники)

Всё снято с устройства 2026-10-28 под root, лежит в BACKUP/firmware/*.tar (это сток S120184_210520_ROW).

| Нужно mainline | Откуда в стоке | Примечание |
|---|---|---|
| qcom/sm6115/LENOVO/J606F/a610_zap.mbn | /vendor/firmware/a610_zap.mdt + .b00-.b02 | собрать mdt → mbn (pil-squasher) |
| qcom/sm6115/LENOVO/J606F/adsp.mbn | /vendor/firmware_mnt/image/adsp.* (раздел modem_a) | 36 файлов split |
| qcom/sm6115/LENOVO/J606F/cdsp.mbn | /vendor/firmware_mnt/image/cdsp.* | |
| qcom/sm6115/LENOVO/J606F/modem.mbn | /vendor/firmware_mnt/image/modem.* | на Wi-Fi-версии нужен для Wi-Fi (WLAN-стек живёт в MPSS) |
| ath10k/WCN3990/hw1.0/wlanmdsp.mbn | /vendor/firmware_mnt/image/wlanmdsp.mbn | (путь в mainline: проверить по qcom,ath10k / qmi) |
| ath10k board data (variant Lenovo_P11) | /vendor/firmware_mnt/image/bdwlan.* | проверить, есть ли Lenovo_P11 в linux-firmware board-2.bin; если нет, сделать board-2.bin из bdwlan.bin |
| qca BT (WCN39xx) | /vendor/bt_firmware/image/{apbtfw10,apbtfw11,crbtfw11,crbtfw20,crbtfw21}.tlv, {apnv10,apnv11,crnv11,crnv20,crnv21}.bin | раздел bluetooth_a; какая версия чипа, узнать из dmesg стока |
| venus (видео) | /vendor/firmware_mnt/image/venus.* | P2 |
| ipa | /vendor/firmware/{ipa_fws,scuba_ipa_fws}.* | на Wi-Fi-модели, вероятно, не нужно |
| Тач | /vendor/firmware/Himax_firmware.bin (+Himax_mpfw.bin, hx_criteria.csv) | zero-flash HX83102E |
| Усилители | /vendor/firmware/awinic/aw882xx_acf.bin, aw882xx_monitor.bin | формат mainline aw88xxx «acf» есть, совместимость проверить |
| ADSP-библиотеки (fastrpc, SSC-датчики) | /vendor/dsp/* (раздел dsp_a), /vendor/firmware_mnt/image/*.jsn | для hexagonrpcd / датчиков |
| GPU sqe | a630_sqe.fw (для a610 в Mesa/linux-firmware уже есть qcom/a630_sqe.fw) | брать из linux-firmware |

Также есть /vendor/firmware/novatek_ts_fw.bin (второй SKU), dbmd8_va_fw.bin (DSPG DBMD8, голосовой wake), okg_amodel.bin.

verinfo: BACKUP/firmware/vendor_firmware_mnt.tar → verinfo/ver_info.txt (версии образов MPSS/ADSP).
