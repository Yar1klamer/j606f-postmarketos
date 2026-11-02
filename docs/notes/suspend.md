# Suspend (s2idle)

## Status (2026-11-02)
- Works with caveats: kernel r110 (patch 0010 — the dwc3 UTMI clock after resume) removed «failed to enable ep0out», r111 — a successful s2idle.
- The `j606f-sleep.service` helper (`/usr/lib/j606f/sleep pre|post`, installed by hand on our tablet, not in the device package yet): before suspend it stops
  iio-sensor-proxy and hexagonrpcd-adsp-sensorspd (otherwise sensor_process crashes the ADSP) and turns BT off with rfkill (the BT UART wakes the system), afterwards it restores them.
- 02.11, r121: 4.5 min of suspend → resume without ep0out and ADSP crashes, sound (3 cards), BT and Wi-Fi are back.
  **Bug:** the sensors do not come back — the stock hexagonrpcd-adsp-sensorspd.service has `Conflicts=suspend.target`, and `systemctl start --no-block`
  from the ExecStop of our unit does not work (iio-sensor-proxy comes up, sensorspd does not; a manual `systemctl start` helps).
  Fix it with a separate unit After=suspend.target, and only then package it.
- Not tested: suspend with an OTG device attached after r110, long suspend (hours), Wi-Fi without WoWLAN (reconnects after resume).

## The original analysis (2026-10-30)

- mem_sleep: only [s2idle]; RTC pm8xxx (wakealarm exists, time is 1970 — the offset is not stored; the alarm can be set).
- PowerDevil tries to suspend on its own about every 10 min of idle.
- Blockers: (1) dwc3-qcom-legacy "port-1 HS-PHY not in L2" — with an OTG device attached the suspend is aborted; on the first attempt "xHC error in resume -110" and "hard LOCKUP on cpu 1".
  (2) After suspend or a host→device role switch "dwc3: failed to enable ep0out" (CoreSoftReset in __dwc3_set_mode, HS-only + select-utmi-as-pipe-clk) — the USB gadget does not
  work until reboot, the next suspend gives "dwc3 suspend -11". (3) ADSP "fatal error … crash detected in adsp" while suspending → wakes up after ~2 s (suspect: SSC/hexagonrpcd).
  (4) Wi-Fi gets deauthenticated (no WoWLAN).
- Plan: test suspend with hexagonrpcd/iio-sensor-proxy stopped; dwc3 — move USB to qcom,snps-dwc3 (flat binding) or a quirk for re-initialisation;
  for now — disable automatic suspend in PowerDevil.
