# Firmware (sources)

Everything was taken from the device on 2026-10-28 as root and stored in BACKUP/firmware/*.tar (this is stock S120184_210520_ROW).

| Needed by mainline | Where in stock | Note |
|---|---|---|
| qcom/sm6115/LENOVO/J606F/a610_zap.mbn | /vendor/firmware/a610_zap.mdt + .b00-.b02 | assemble mdt → mbn (pil-squasher) |
| qcom/sm6115/LENOVO/J606F/adsp.mbn | /vendor/firmware_mnt/image/adsp.* (modem_a partition) | 36 split files |
| qcom/sm6115/LENOVO/J606F/cdsp.mbn | /vendor/firmware_mnt/image/cdsp.* | |
| qcom/sm6115/LENOVO/J606F/modem.mbn | /vendor/firmware_mnt/image/modem.* | on the Wi-Fi model it is needed for Wi-Fi (the WLAN stack lives in the MPSS) |
| ath10k/WCN3990/hw1.0/wlanmdsp.mbn | /vendor/firmware_mnt/image/wlanmdsp.mbn | (mainline path: check against qcom,ath10k / qmi) |
| ath10k board data (variant Lenovo_P11) | /vendor/firmware_mnt/image/bdwlan.* | check whether linux-firmware board-2.bin has Lenovo_P11; if not, build board-2.bin from bdwlan.bin |
| qca BT (WCN39xx) | /vendor/bt_firmware/image/{apbtfw10,apbtfw11,crbtfw11,crbtfw20,crbtfw21}.tlv, {apnv10,apnv11,crnv11,crnv20,crnv21}.bin | bluetooth_a partition; the chip version is in the stock dmesg |
| venus (video) | /vendor/firmware_mnt/image/venus.* | P2 |
| ipa | /vendor/firmware/{ipa_fws,scuba_ipa_fws}.* | probably not needed on the Wi-Fi model |
| Touch | /vendor/firmware/Himax_firmware.bin (+Himax_mpfw.bin, hx_criteria.csv) | zero-flash HX83102E |
| Amplifiers | /vendor/firmware/awinic/aw882xx_acf.bin, aw882xx_monitor.bin | mainline aw88xxx has an "acf" format, compatibility to be checked |
| ADSP libraries (fastrpc, SSC sensors) | /vendor/dsp/* (dsp_a partition), /vendor/firmware_mnt/image/*.jsn | for hexagonrpcd / sensors |
| GPU sqe | a630_sqe.fw (Mesa/linux-firmware already ship qcom/a630_sqe.fw for a610) | take from linux-firmware |

There is also /vendor/firmware/novatek_ts_fw.bin (the second SKU), dbmd8_va_fw.bin (DSPG DBMD8, voice wake), okg_amodel.bin.

verinfo: BACKUP/firmware/vendor_firmware_mnt.tar → verinfo/ver_info.txt (MPSS/ADSP image versions).
