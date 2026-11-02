# Wi-Fi / Bluetooth

## Wi-Fi
- Stock: icnss (c800000.qcom,icnss), qcacld wlan.ko. `WLAN FW is ready: 0x587`, `Board id: 0, Board version: b 0 0 0 6`.
- Mainline: ath10k snoc (WCN3990 family); the DTS already contains `&wifi` with calibration-variant "Lenovo_P11" and the pm6125 l8/l16/l17/l23 regulators.
- Firmware: wlanmdsp.mbn (modem partition, /vendor/firmware_mnt/image/), loaded by the MPSS (remoteproc_mpss, modem.mbn) → modem.mbn and wlanmdsp.mbn are needed.
- Board data: bdwlan.bin + bdwlan.<id> in /vendor/firmware_mnt/image/. Check whether linux-firmware ath10k/WCN3990/hw1.0/board-2.bin has an entry with variant=Lenovo_P11; if not, build board-2.bin from bdwlan.bin (ath10k-bdencoder).
- MAC: <WIFI_MAC> (ro.odm.lenovo.wifiaddr). In pmOS a stable address derived from serialno is set by bootmac (device r5); the factory one from persist is not used.

## Bluetooth
- A separate bluetooth_a partition (sde5) is mounted at /vendor/bt_firmware. Files: apbtfw10/11.tlv, crbtfw11/20/21.tlv, apnv10/11.bin, crnv11/20/21.bin.
- Mainline: btqca. The chip is WCN3990 (see «BT SoC» and the results below).
- BT MAC: <BT_MAC>.
- BT is not described in the mainline j606f DTS. BT UART: find it from the stock DT via sm6115.dtsi (qup uart).

## BT SoC
getprop vendor.qcom.bluetooth.soc = **cherokee** (the QTI stack's name for the WCN399x family). In mainline: compatible qca,wcn3990 (stock DT: node bt_wcn3990, compatible "qca,wcn3990"; uart = qup_uart@4a8c000 = mainline uart3).
Stock BT power: vdd-io / core / pa / xtal from pm6125 (phandle 0x11..0x14), io 1.7–1.9 V, core 1.304 V, pa 3.0–3.3 V, xtal 1.7–1.9 V.

## ★ Mainline 7.2.3 results (2026-10-29)
### Wi-Fi — scanning works
- Needed: MPSS remoteproc (modem.mbn) + rmtfs (EFS) + tqftpserv (serves wlanmdsp.mbn) + in-kernel qrtr-ns and pd-mapper + ath10k_snoc.
- While debugging, rmtfs ran on COPIES of modemst1/2, fsg, fsc in RAM (`rmtfs -v -o /var/rmtfs`, files modem_fs1/modem_fs2/modem_fsg/modem_fsc). In pmOS rmtfs writes to the real modemst* partitions by default; that is intended (EFS), but it is a write to modem partitions, so enable it only with the owner's consent (a backup exists).
- tqftpserv needs the /var/lib/tqftpserv directory.
- ath10k: chip_id 0x150, board_id 0xff, fw WLAN.HL.3.2.4-00564; the board data from linux-firmware-ath10k fits ("cal file"). The MAC was random while debugging, in pmOS — bootmac.
- iw scan: 4 BSS (2.4 + 5 GHz), up to −38 dBm. ~~Connection not tested.~~ **In pmOS: WPA2 connection (NetworkManager), DHCP, DNS and internet work** (29.10).
### Bluetooth — scanning works
- DTS: uart3 + pinctrl GPIO8–11 (qup3), alias serial1 = &uart3 (without it "qcom_geni_serial … Invalid line -19"), qcom,wcn3990-bt with L9/L16/L17/L23.
- Firmware from the stock bluetooth partition: qca/crbtfw21.tlv, qca/crnv21.bin. SOC Version 0x40020150, ROM 0x201.
- The controller starts "Unconfigured" (no public address) → `btmgmt public-addr <BT_MAC>` (ro.odm.lenovo.btaddr). For pmOS: local-bd-address in the DT (written by ABL? no) or a service that sets the address at startup.
- btmgmt find -l: 21 unique LE devices. ~~Pairing not tested.~~ **In pmOS: pairing and HID (Mi Mouse3C mouse) work**; the address is set by bootmac (device r5). Auto-reconnect after reboot not tested.
