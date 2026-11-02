# Sensors

All behind the SSC (Qualcomm Snapdragon Sensor Core on the ADSP), not on Linux I2C:
- accelerometer + gyroscope TDK icm4x6xx
- ambient light Lite-On ltr578
- ToF/proximity ams tmf8801
- SAR Semtech sx932x (virtualsar on I2C1 0x33 for the "vitural-sar" input)

Linux needs: ADSP remoteproc + fastrpc + hexagonrpcd + libssc + iio-sensor-proxy (the SSC path that works on other qcom devices in pmOS). It needs /vendor/dsp/* and the sns registry (/mnt/vendor/persist/sensors, available in BACKUP/firmware/mnt_vendor_persist.tar).

## Status: light, proximity and accelerometer **work** (since 29.10, details below)
- 02.11: after suspend the sensors do not come back (sensorspd is stopped because of `Conflicts=suspend.target`), see suspend.md.

## SSC attempts in mainline (2026-10-29), 1–3 failed (history, LOG.md)
- The ADSP starts with the stock adsp.mbn; fastrpc.ko provides /dev/fastrpc-adsp; hexagonrpcd 1.x and libssc (ssccli) from Alpine community.
- Configs were taken read-only from the stock vendor_a (in super, offset 0xebf00000) and dsp_a; the registry is a copy from persist.
- hexagonrpcd: the ADSP tries to write to the registry (sns_reg_version, temp.json), and hexagonrpcd reports "Tried to open … for writing"; then "Could not read from directory: Bad file descriptor" and "Broken pipe".
- Looking for a working file layout, as in the pmOS firmware packages of other qcom devices with hexagonrpcd (folder /usr/share/qcom/<soc>/<vendor>/<device>/, with the registry possibly in /var/lib/hexagonrpcd).

## ★ Attempt 4 — works (2026-10-29, night)
- Root `-R /usr/share/qcom/sm6115/LENOVO/J606F`, laid out by hexagonrpcd's virtual paths (`rpcd_builder.c`), **flat**:
  `dsp/adsp/` (from dsp_a), `sensors/config/` and `sensors/sns_reg.conf` (from vendor `/etc/sensors`), `sensors/registry/` + `sensors/sns_reg_version` (from persist), `socinfo/`.
- Without `sns_reg_version` next to the registry the SM6115 ADSP tries to rebuild it (`temp.json`) → writing is denied → "'registry' sensor unavailable".
  hexagonrpcd 0.4.0 does not serve the file → patch `pmaports/temp/hexagonrpcd` (0.4.0-r50, `0001-rpcd-serve-sns_reg_version-next-to-the-registry.patch`).
- `apk add hexagonrpcd` enables the rootpd/sensorspd services **without `-R`** → the ADSP crashes every ~4 s. Drop-ins are needed:
  `/etc/systemd/system/hexagonrpcd-adsp-{rootpd,sensorspd}.service.d/j606f.conf` (`ExecStart=` + `ExecStart=/usr/bin/hexagonrpcd -f /dev/fastrpc-adsp -d adsp [-s] -R …/J606F`).
- Result: `ssccli` — Light ≈231 lx, Proximity FAR, Accelerometer (8.30, 0.12, 5.28) m/s² (|g| ≈ 9.84); `monitor-sensor` (iio-sensor-proxy) sees all three. No ADSP crashes.
- Not done: `ACCEL_MOUNT_MATRIX` (a udev rule like `81-libssc-*.rules`) for auto-rotation — to be found together with the owner; gyroscope/SAR not exposed;
  packaging: drop-ins and the hexagonrpcd r50 dependency → device package, SSC files (from one's own device) → private firmware package.
