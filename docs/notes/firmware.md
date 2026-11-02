# Firmware (sources)

Everything was taken from the device on 2026-10-28 as root and stored in BACKUP/firmware/*.tar (this is stock S120184_210520_ROW).

## How it works now (since 31.10, device r16+)
- The `firmware-lenovo-j606f` package: either a personal one (pkgver 1, a tarball from one's own device, not published; ours is 1-r3 with venus.mbn and the awinic acf),
  or the shared set of the S320208 stock (Android 11) `0.320208-r1` — only in the apk repository, verified by sha256 at publication.
- `/usr/lib/j606f/firmware-extract` (device package) takes the firmware from the tablet's own partitions (read only) on install, update and every boot:
  modem_a/b → adsp/cdsp/modem/venus (.mdt+.bNN → .mbn), wlanmdsp; bluetooth_a/b → crbtfw21.tlv/crnv21.bin; vendor in super → a610_zap, Himax_*.bin,
  awinic/aw882xx_acf.bin. With the shared set the DSP files of one's own stock go to /lib/firmware/updates (otherwise the sensors crash with a foreign ADSP).
- The table below is the original "what comes from where" map (28.10); ✓ marks show how it was resolved.

| Needed by mainline | Where in stock | Note |
|---|---|---|
| qcom/sm6115/LENOVO/J606F/a610_zap.mbn | /vendor/firmware/a610_zap.mdt + .b00-.b02 | assemble mdt → mbn (pil-squasher) |
| qcom/sm6115/LENOVO/J606F/adsp.mbn | /vendor/firmware_mnt/image/adsp.* (modem_a partition) | 36 split files |
| qcom/sm6115/LENOVO/J606F/cdsp.mbn | /vendor/firmware_mnt/image/cdsp.* | |
| qcom/sm6115/LENOVO/J606F/modem.mbn | /vendor/firmware_mnt/image/modem.* | on the Wi-Fi model it is needed for Wi-Fi (the WLAN stack lives in the MPSS) |
| ath10k/WCN3990/hw1.0/wlanmdsp.mbn | /vendor/firmware_mnt/image/wlanmdsp.mbn | ✓ loaded by MPSS through tqftpserv |
| ath10k board data (variant Lenovo_P11) | /vendor/firmware_mnt/image/bdwlan.* | ✓ the board data from linux-firmware-ath10k fits |
| qca BT (WCN39xx) | /vendor/bt_firmware/image/{apbtfw10,apbtfw11,crbtfw11,crbtfw20,crbtfw21}.tlv, {apnv10,apnv11,crnv11,crnv20,crnv21}.bin | ✓ WCN3990, needs crbtfw21.tlv + crnv21.bin |
| venus (video) | /vendor/firmware_mnt/image/venus.* | ✓ the stock venus.mbn (mainline venus-6.0 does not load), kernel r115+ |
| ipa | /vendor/firmware/{ipa_fws,scuba_ipa_fws}.* | probably not needed on the Wi-Fi model |
| Touch | /vendor/firmware/Himax_firmware.bin (+Himax_mpfw.bin, hx_criteria.csv) | zero-flash HX83102E |
| Amplifiers | /vendor/firmware/awinic/aw882xx_acf.bin, aw882xx_monitor.bin | ✓ the old-format acf is parsed by our aw88258 driver (0013); without the file the amplifiers wait |
| ADSP libraries (fastrpc, SSC sensors) | /vendor/dsp/* (dsp_a partition), /vendor/firmware_mnt/image/*.jsn | ✓ for hexagonrpcd / sensors (/usr/share/qcom/sm6115/LENOVO/J606F) |
| GPU sqe | a630_sqe.fw (Mesa/linux-firmware already ship qcom/a630_sqe.fw for a610) | take from linux-firmware |

There is also /vendor/firmware/novatek_ts_fw.bin (the second SKU), dbmd8_va_fw.bin (DSPG DBMD8, voice wake), okg_amodel.bin.

verinfo: BACKUP/firmware/vendor_firmware_mnt.tar → verinfo/ver_info.txt (MPSS/ADSP image versions).
