# Firmware (sources)

Everything was taken from the device on 2026-10-28 as root and stored in BACKUP/firmware/*.tar (this is stock S120184_210520_ROW).

## How it works now (since 03.11, device r23+)
- The firmware package is no longer required: `-nonfree-firmware` does not pull firmware-lenovo-j606f, firmware-extract takes everything, so the flashable
  image ships no Lenovo blobs. First boot of a clean install: the DSPs start right after the extraction, and when the GPU zap / touch firmware is added —
  mkinitfs and a single reboot (r23). The zap is marked `!optional` in `30-gpu-firmware.files` (r24), otherwise mkinitfs fails before the extraction.
- r22: firmware-extract also builds the tree for the sensors (dsp, vendor /etc/sensors, persist registry, socinfo), see sensors.md.
- If vendor is wiped (as on ours before 03.11: super overwritten), the zap/Himax/acf/sensor configs have no source — then `apk add firmware-lenovo-j606f`
  (the shared set from the apk repository; it has no sensor configs).

Checked on a real device 03.11 (release image, stock super): the first boot added adsp/cdsp/modem/venus/wlanmdsp from modem_a,
crbtfw21/crnv21 from bluetooth_a, the adsp tree from dsp_a, registry + sns_reg_version from persist, socinfo, and a610_zap, Himax_firmware/mpfw,
aw882xx_acf, sensors/config, sns_reg.conf from vendor_a → "initramfs rebuilt", "rebooting once" (at second 89). Later boots add nothing.
Afterwards /dev/mapper is empty (mappings removed), nothing is mounted. GPU (FD610), touch, speakers and sensors work.

## wlanmdsp.mbn has to match modem_a (03.11)
- Symptom: after our system was restored from the backup (the release image had run on the tablet before) there is no wlan0, Wi-Fi shows "type unknown".
  dmesg: `qcom_q6v5_pas 6080000.remoteproc: fatal error received: dog_virtual_root.c:92:User-PD grace timer expired for wlan_process (ASID: 1)`
  every ~41 s, then "crash detected in modem" and a restart; tqftpserv serves `/readonly/vendor/firmware_mnt/image/wlanmdsp.mbn` again and again.
- Cause: wlanmdsp.mbn in the personal package 1-r3 differs from `image/wlanmdsp.mbn` of the modem_a partition (modem/adsp/cdsp/venus match).
  Before the release image ran (it takes wlanmdsp from modem_a) the same 1-r3 worked — the modem seems to remember the WLAN image version in EFS (modemst via rmtfs).
- Fix: the stock file in `/lib/firmware/updates/qcom/sm6115/LENOVO/J606F/wlanmdsp.mbn` (tqftpserv and the kernel search updates first), restart
  the modem through `/sys/class/remoteproc/<modem>/state` (stop, start) → `ath10k_snoc … fw_build_id … WLAN.HL.3.2.4-00564`, wlan0 appears, NM connects.
  Commands — COMMANDS.md "Wi-Fi: wlanmdsp from modem_a".
- Takeaway: put only the same tablet's wlanmdsp from modem_a into a firmware package (firmware-extract does exactly that); rebuild the personal package (TODO).

## How it was (since 31.10, device r16–r22)
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
