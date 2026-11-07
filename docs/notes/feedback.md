# User feedback and external contributions

## 07.11 — PR #1 (kruzeman): Lenovo Keyboard Pack pogo dock
**Outcome:** patch 0025 → kernel r122, tested on our tablet, published to the apk repository, PR merged 07.11.
github.com/Yar1klamer/j606f-postmarketos/pull/1, author's branch `feat/pogo-hid-i2c`, one commit 09db393 (06.11).
- What it does: two `hid-over-i2c` nodes in `kernel/dts/sm6115p-lenovo-j606f-common.dtsi`: I2C0 0x60 (Elan 04f3:3164, touchpad, irq gpio93)
  and I2C1 0x61 (Lenovo 17ef:6103, keyboard, irq gpio96), `hid-descr-addr = <0x1>`, `post-power-on-delay-ms = <100>`, `IRQ_TYPE_LEVEL_LOW`,
  pinctrl as in stock. The author tested it on hardware (r121, own DTB). Matches our plan in notes/input_keyboard.md (addresses and IRQs from the stock DT).
  No address clashes: I2C0 has fusb302 0x22, AW88258 0x34–0x37, mm8013 0x55; I2C1 has nothing in our DT (SMB1355 0x0c is not described and not touched).
- Our review:
  1. **On its own it gives users nothing**: `kernel/dts/` in the repository is a snapshot, the kernel is built from `kernel/patches/` (APKBUILD
     linux-lenovo-j606f). Needed: patch 0025 (author kruzeman), pkgrel 122, build, test on our tablet, publish to the apk repository.
     Also the private sources and notes — otherwise the next export would overwrite the PR's changes.
  2. STATE.md: the PR adds item "0d", but 0d is already taken (UEFI/Windows, 5e959a9) → renumbered (0e).
  3. docs/notes/boot.md: the claim "dtc loses a byte in properties starting with 0x00" is doubtful — upstream dtc's
     `util_is_printable_string()` rejects empty strings (`s == ss`), so `00 31 51 00` is printed as `<0x315100>` and the round-trip is exact.
     Most likely another tool of the author's was at fault. The advice "byte-exact round-trip + cmp first" is useful on its own — kept, without blaming dtc.
  4. Nits: `interrupt-parent` next to `interrupts-extended` is redundant (our fusb302 has none); the second `&tlmm` block at the end of the file is
     better merged into the existing one; `scripts/fdtread.py`: dead line 182 (an unpack immediately overwritten), no shebang despite mode 755.
  5. english branch — translated by us after the merge.

## 07.11 — review from a 4PDA tester (TB-J606F HX83102P, **4 GB RAM**)
Installed pmOS into slot **a** (Android + Magisk in slot b), went from Plasma to Phosh. What we take from it:
- **A 4 GB version exists** (ours has 6 GB): Plasma is heavy for it. → mention in the README; consider an image variant with Phosh.
- **Installing into slot a**: own variant of the script (`flash boot_a`, `erase dtbo_a`, `--set-active=a`). → flash-all.sh/.bat: slot choice
  (e.g. `SLOT=a ./flash-all.sh`), default b; warn that userdata is shared.
- **Phosh**: phoc.ini `[output:DSI-1] rotate = 180` (the panel is upside down in the DT) + udev `LIBINPUT_CALIBRATION_MATRIX="-1 0 1 0 -1 1 0 0 1"`
  for himax-touchscreen and himax-pen. → could go into the device package (for Phosh) after testing; in Plasma we use kscreen rotation.left.
- **Auto-rotation**: iio-sensor-proxy sent "garbage" orientations for the tester and crashed the session (Phosh); the tester reads the accelerometer via `ssccli`
  and rotates with `wlr-randr` from their own service. → this is our open TODO `ACCEL_MOUNT_MATRIX` (hwdb in the device package); ssccli confirms the SSC accelerometer is alive.
- **tuned powersave** — the UI feels sluggish, balanced helps. → check the default tuned profile in the image (tuned.service fails for us).
- **USB PD 9 V**: PD enabled by the tester (with their own PDOs) drove the ICL to zero; compromise — 5 V only. Our DT has `pd-disable` — same, no change needed.
- Suspend masked (CrashDump, known issue 0a); Power — own watcher on pm8941_pwrkey for blank/unblank.
- Phosh hit a CrashDump on first start (pstore empty) — unclear, collect details if it repeats.
- ALS "not in IIO" — for us light goes through libssc in iio-sensor-proxy; the tester masked the proxy, hence nothing.

## 07.11 — Telegram (kruzeman again): "the magnetic keyboard with touchbar does not work, dmesg shows nothing" → then sent PR #1 (above).
