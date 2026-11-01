# Suspend (s2idle) — not working (2026-10-30)

- mem_sleep: only [s2idle]; RTC pm8xxx (wakealarm exists, time is 1970 — the offset is not stored; the alarm can be set).
- PowerDevil tries to suspend on its own about every 10 min of idle.
- Blockers: (1) dwc3-qcom-legacy "port-1 HS-PHY not in L2" — with an OTG device attached the suspend is aborted; on the first attempt "xHC error in resume -110" and "hard LOCKUP on cpu 1".
  (2) After suspend or a host→device role switch "dwc3: failed to enable ep0out" (CoreSoftReset in __dwc3_set_mode, HS-only + select-utmi-as-pipe-clk) — the USB gadget does not
  work until reboot, the next suspend gives "dwc3 suspend -11". (3) ADSP "fatal error … crash detected in adsp" while suspending → wakes up after ~2 s (suspect: SSC/hexagonrpcd).
  (4) Wi-Fi gets deauthenticated (no WoWLAN).
- Plan: test suspend with hexagonrpcd/iio-sensor-proxy stopped; dwc3 — move USB to qcom,snps-dwc3 (flat binding) or a quirk for re-initialisation;
  for now — disable automatic suspend in PowerDevil.
