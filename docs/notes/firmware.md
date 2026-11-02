# Прошивки (источники)

Всё снято с устройства 2026-10-28 под root, лежит в BACKUP/firmware/*.tar (это сток S120184_210520_ROW).

## Как устроено сейчас (с 31.10, device r16+)
- Пакет `firmware-lenovo-j606f`: либо личный (pkgver 1, тарбол со своего устройства, не публикуется; у нас 1-r3 с venus.mbn и awinic acf),
  либо общий набор стока S320208 (Android 11) `0.320208-r1` — только в apk-репозитории, сверяется по sha256 при публикации.
- `/usr/lib/j606f/firmware-extract` (device-пакет) при установке, обновлении и каждой загрузке берёт прошивки с разделов самого планшета (только чтение):
  modem_a/b → adsp/cdsp/modem/venus (.mdt+.bNN → .mbn), wlanmdsp; bluetooth_a/b → crbtfw21.tlv/crnv21.bin; vendor в super → a610_zap, Himax_*.bin,
  awinic/aw882xx_acf.bin. При общем наборе DSP-файлы своего стока кладутся в /lib/firmware/updates (иначе датчики с чужим ADSP падают).
- Таблица ниже — исходная карта «что откуда» (28.10); отметки ✓ — как это решилось.

| Нужно mainline | Откуда в стоке | Примечание |
|---|---|---|
| qcom/sm6115/LENOVO/J606F/a610_zap.mbn | /vendor/firmware/a610_zap.mdt + .b00-.b02 | собрать mdt → mbn (pil-squasher) |
| qcom/sm6115/LENOVO/J606F/adsp.mbn | /vendor/firmware_mnt/image/adsp.* (раздел modem_a) | 36 файлов split |
| qcom/sm6115/LENOVO/J606F/cdsp.mbn | /vendor/firmware_mnt/image/cdsp.* | |
| qcom/sm6115/LENOVO/J606F/modem.mbn | /vendor/firmware_mnt/image/modem.* | на Wi-Fi-версии нужен для Wi-Fi (WLAN-стек живёт в MPSS) |
| ath10k/WCN3990/hw1.0/wlanmdsp.mbn | /vendor/firmware_mnt/image/wlanmdsp.mbn | ✓ грузится MPSS через tqftpserv |
| ath10k board data (variant Lenovo_P11) | /vendor/firmware_mnt/image/bdwlan.* | ✓ board data из linux-firmware-ath10k подошла |
| qca BT (WCN39xx) | /vendor/bt_firmware/image/{apbtfw10,apbtfw11,crbtfw11,crbtfw20,crbtfw21}.tlv, {apnv10,apnv11,crnv11,crnv20,crnv21}.bin | ✓ WCN3990, нужны crbtfw21.tlv + crnv21.bin |
| venus (видео) | /vendor/firmware_mnt/image/venus.* | ✓ стоковый venus.mbn (mainline venus-6.0 не грузится), ядро r115+ |
| ipa | /vendor/firmware/{ipa_fws,scuba_ipa_fws}.* | на Wi-Fi-модели, вероятно, не нужно |
| Тач | /vendor/firmware/Himax_firmware.bin (+Himax_mpfw.bin, hx_criteria.csv) | zero-flash HX83102E |
| Усилители | /vendor/firmware/awinic/aw882xx_acf.bin, aw882xx_monitor.bin | ✓ acf старого формата разбирает наш драйвер aw88258 (0013); без файла усилители ждут |
| ADSP-библиотеки (fastrpc, SSC-датчики) | /vendor/dsp/* (раздел dsp_a), /vendor/firmware_mnt/image/*.jsn | ✓ для hexagonrpcd / датчиков (/usr/share/qcom/sm6115/LENOVO/J606F) |
| GPU sqe | a630_sqe.fw (для a610 в Mesa/linux-firmware уже есть qcom/a630_sqe.fw) | брать из linux-firmware |

Также есть /vendor/firmware/novatek_ts_fw.bin (второй SKU), dbmd8_va_fw.bin (DSPG DBMD8, голосовой wake), okg_amodel.bin.

verinfo: BACKUP/firmware/vendor_firmware_mnt.tar → verinfo/ver_info.txt (версии образов MPSS/ADSP).
