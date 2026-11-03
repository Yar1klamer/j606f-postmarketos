# Suspend (s2idle)

## Status (2026-11-03)
- Works with caveats: kernel r110 (patch 0010 — the dwc3 UTMI clock after resume) removed «failed to enable ep0out», r111 — a successful s2idle.
- The suspend helper is in the device package since **r21** (nt36523w — r11), files `j606f-sleep.sh`, `j606f-sleep.service`, `j606f-resume.service`:
  - `j606f-sleep.service` (WantedBy/Before=sleep.target, StopWhenUnneeded): `pre` — remembers the enabled hexagonrpcd-adsp-rootpd/sensorspd and an active
    iio-sensor-proxy in /run/j606f-sleep.units, stops them (otherwise sensor_process crashes the ADSP), BT — `rfkill block` (the BT UART wakes the system);
    `post` (when sleep.target stops) — `rfkill unblock`.
  - `j606f-resume.service` (WantedBy/After=suspend.target, oneshot): `resume` — `systemctl start --no-block` rootpd, sensorspd, iio-sensor-proxy.
  - Two state files (/run/j606f-sleep for BT, /run/j606f-sleep.units for the units): `post` and `resume` run at the same time.
- The bug before r21 (02.11): the sensors did not come back. The cause — the stock hexagonrpcd-adsp-*.service have `Conflicts=suspend.target`: systemd stops them
  itself in the same transaction as our `pre` (journal: pre 1934.258, sensorspd deactivated 1934.273), `is-active` saw them already stopped → they were not recorded
  → not started again. For the same reason rootpd had been down since the first suspend on 30.10. Fixed: the hexagonrpcd units are restored by `is-enabled`.
- 02.11, r121: 4.5 min of suspend → resume without ep0out and ADSP crashes, sound (3 cards), BT and Wi-Fi are back. With r21 — three cycles (rtcwake + `systemctl suspend`):
  rootpd/sensorspd/iio-sensor-proxy active, `monitor-sensor` reports light/proximity/accelerometer, ADSP running, BT UP.
- Observation: when suspended from ssh the tablet wakes after ~2 s, `/sys/power/pm_wakeup_irq` = 114 (msmgpio 11, `4a8c000.serial:wakeup` — the BT UART),
  although BT is rfkill-blocked; a suspend by the button on 02.11 lasted 4 min. Not investigated.
- ⚠ 03.11, r121: **CrashDump ~2 min after a resume** (release image on our tablet; the tester gets CrashDumps too, on volume keys / browser / reboot).
  Before the crash: BT reloads crbtfw21/crnv21, Himax "update fw after resume in zero flash mode", "[HXTP] point data_checksum not match"; no panic in the journal.
  On the resume at 03.11 01:02 (our system) — dozens of "watchdog: CPUn: Watchdog detected hard LOCKUP on cpu m" with NMI traces in cpuidle_enter_s2idle.
  Ramoops: read /var/lib/systemd/pstore on the first boot after the crash (console-ramoops-0 is overwritten by the next one). For now — turn automatic sleep off.
- After suspend the USB gadget can die again: udc "not attached", usb0 DOWN, "HS-PHY not in L2"; soft_connect does not help — only a reboot.
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
