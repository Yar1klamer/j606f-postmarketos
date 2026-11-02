# Touchscreen and stylus

## Facts from the device
- SPI0 (QUP 4a88000.spi), CS0: `himax,hxcommon`, stock driver himax_tp, spi-max-frequency 10 MHz, spi-cpha.
  - irq: tlmm gpio 86 (0x56), flags 0x2008; reset: tlmm gpio 54 (0x36)
  - panel/display coords 1200x2000
  - node: stock_dt/spi_4a88000_touch.dtsi
- The same SPI, CS1, describes `novatek,NVT-ts-spi` (for the second SKU with NT36523W), no driver is bound to it.
- input: "himax-touchscreen" (event2) and "himax-pen" (event3) → **there is a stylus (Lenovo Precision Pen)**.
- dmesg: chip **HX83102E**, **zero flash** mode: the host loads the `Himax_firmware.bin` firmware after every resume (`It will update fw after resume in zero flash mode!`, `himax_mcu_firmware_update_0f`). The files /vendor/firmware/Himax_firmware.bin and Himax_mpfw.bin are in BACKUP/firmware/vendor_firmware.tar.
- There is a "direction" (orientation, cmd 2) and USB detect (the chip switches mode when USB is connected).

## Mainline
- v7.2.3 has no HX83102 SPI driver: only himax_hx83112b.c and himax_hx852x.c (I2C), and no generic spi-hid.
- LKML series:
  - Tylor Yang, "HID: touchscreen: Add initial support for Himax HID-over-SPI", v2/v3, 2023-09/10
  - Allen Lin, "HID: Add support for Himax HX83102j touchscreen", v1–v4, 2024-03/04, including firmware loading from a file and panel follower

  Not confirmed as merged. Our chip is HX83102E, not J; protocol compatibility is unknown.
- Options: (1) port Allen Lin's hid-himax series and test with HX83102E; (2) port the downstream himax_tp (Lenovo kernel source, if it has hx83102e) as an out-of-tree module. This is the most laborious P0 item.

## Status
**Works (29.10)**: touches in Plasma land exactly (confirmed by the owner). Stylus: the device exists, not tested with a pen. Details in the "Port" section below.

## Stock driver (from the stock 4.19 kernel, 2026-10-29)
- In the stock Image (raw/stock_kernel/Image, unpacked from boot) the Himax driver is built in (not a module): the strings "Himax Touch Driver Version:", "HX83102A/B/D/E", "Himax_firmware.bin", "Himax_mpfw.bin", "g_core_fp", "himax,hxcommon", "himax,irq-gpio", "himax,rst-gpio", "himax,3v3-gpio", "himax-pen".
  The list of himax_*/hx83102*_ symbols: notes/stock_dt/stock_kernel_himax_symbols.txt.
- This is the standard Himax GPL driver "hxchipset" (himax_common.c, himax_ic_core.c, himax_ic_HX83102.c, himax_platform_SPI.c) with zero-flash support (`himax_mcu_firmware_update_0f`). Lenovo did not publish the sources. Similar code exists in many Android kernels (Xiaomi/Moto/…), but I did not find the specific repository: web search gave nothing, and GitHub code search requires a login.
- The stock DT has "himax,3v3-gpio": possibly a separate touch supply (our stock node does not have it, only irq 86 / rst 54).

## Touch port plan
1. Find GPL hxchipset sources with HX83102E (search for "hx83102e_sense_off" / "himax_mcu_firmware_update_0f" in Android kernels; the owner with a GitHub account may help).
2. Build it as an external module for 7.2.3 (like panel/tps65132 via /build/ext), remove the Android specifics (fb notifier → drm panel follower, wakelocks, etc.).
3. DT: &spi2 (QUP SE2, 4a88000) okay, node himax_ts@0 (spi-cpha, 10 MHz, irq tlmm 86, reset tlmm 54) + the QUP SE2 pins from stock.
4. Firmware: /lib/firmware/Himax_firmware.bin (from BACKUP/firmware/vendor_firmware.tar).
Alternative: Allen Lin's series "HID: Add support for Himax HX83102j" (LKML 2024, hid-himax, loads the firmware from a file), but our chip is E, the protocol may differ.

## ★ GPL sources found (2026-10-29): github.com/adazem009/kernel_lenovo_tbj606
Lenovo 4.19 kernel for TB-J606F/L/X (branches lineage-17.1/18.1/19.1, halium-10/11; Droidian/Ubuntu Touch runs on it on the other revision).
Partial clone (lineage-18.1, f6bb9c6): `src/kernel_lenovo_tbj606/` (not published, kept locally only).
- `drivers/input/touchscreen/himax83102p/` — **exactly the stock driver** (GPL-2.0, Himax 2019): HX83102E, `HX_ZERO_FLASH`, `Himax_firmware.bin` + `Himax_mpfw.bin`,
  `spi_driver` with `compatible = "himax,hxcommon"`; it has `hx83102e_sense_off`, `himax_mcu_firmware_update_0f` (the symbols we were looking for in the stock Image).
  Imported by commit a56fd12c01 (2024-08-09), wakeup_source fix 1a2dfc0533. Stock config: `TOUCHSCREEN_HIMAX_CHIPSET/COMMON/INCELL/IC_HX83102=y`, DEBUG and INSPECT.
- Driver DT properties: `himax,irq-gpio`, `himax,rst-gpio`, `himax,3v3-gpio`, `himax,pon-gpio`, `himax,lcm-rst`, `himax,panel-coords`, `himax,display-coords`,
  `report_type`, regulators `vdd`/`avdd`.
- What to change for mainline 7.2: remove the downstream APIs (`drm_panel_notifier`/`fb_notifier` → `drm_panel_follower`, like i2c-hid), `<linux/hqsysfs.h>`, `asm/segment.h`,
  `kallsyms`, `buffer_head`; disable DEBUG/INSPECT (proc interfaces); the charger notifier (USB mode) can stay via power_supply.
  HX83102P is a TDDI (display and touch in one chip), the reset is shared with the panel (`himax,lcm-rst`) → the power-on order must follow the panel (panel follower).
- Plan: build as an external module for 7.2.3 → DT node in `&spi2` (QUP SE2, irq tlmm 86, reset tlmm 54, `panel = <&panel>`) → firmware from BACKUP/firmware/vendor_firmware.tar.

## ★ Port to 7.2 — works (2026-10-29)
- Source: `src/himax83102p-port/orig/` (Lenovo), script `port.py` → `out/`; into the kernel as patch `0006-Input-add-Himax-HX83102E-touchscreen-for-Lenovo-J606F.patch`
  (directory drivers/input/touchscreen/himax_hx83102e/, `CONFIG_TOUCHSCREEN_HIMAX_HX83102E=m`), patch generator `make_patch.sh`.
- What was changed: see LOG 29.10 and the port.py docstring. Mainly: a single module, no kallsyms/debug/inspection, gpiod, proc_ops, timespec64, strscpy, hrtimer_setup,
  drm_panel_follower (prepared → resume with a firmware reload, unpreparing → suspend), spi_device_id "hxcommon", a parent for the input devices,
  `touchscreen-inverted-x/y` and the pen axis resolution (8 units/mm).
- Orientation: the panel is mounted at 180° (`rotation = <180>`, DRM "panel orientation: Upside Down", KWin takes it into account), while touch reports chassis coordinates →
  without inversion touches are mirrored through the centre. Test on the 4 corners (screen in landscape, as the owner holds it): TL (1109,114), TR (1050,1855), BR (218,1859), BL (192,133).
  First checked with the udev matrix `LIBINPUT_CALIBRATION_MATRIX="-1 0 1 0 -1 1"` → "exact", then moved into the driver (DT properties).
- Probe log: "detect IC HX83102E successfully" → after 2 s "Forced upgrade" → "Update FW success", FW_VER D403, CID 1741, BOE/P11; IRQ tlmm 86 edge falling.
- Firmware: `Himax_firmware.bin`, `Himax_mpfw.bin` — from the personal firmware package, the shared set 0.320208 or the tablet's own vendor (firmware-extract, device r16+).
- Pitfalls: `pkill -f` over ssh kills its own shell (again); `udevadm info` right after insmod shows the properties before the rules are applied — wait for `udevadm settle`;
  this image has no /etc/udev/rules.d (create it).
