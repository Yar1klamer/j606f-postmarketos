# Boot: boot.img format, ABL, debugging

## Stock boot.img (S120184_210520_ROW), from scripts/bootimg_info.py
- header_version 2, page_size 4096
- base 0x00000000, kernel_offset 0x8000, ramdisk_offset 0x01000000, second_offset 0x00f00000, tags_offset 0x100, dtb_offset 0x01f00000
- kernel: gzip (Image.gz), 31.8 MB uncompressed
- dtb in a separate section (header v2), several concatenated DTBs (1.5 MB), ABL picks one by msm-id/board-id: `androidboot.dtb_idx=1`
- dtbo partition: `androidboot.dtbo_idx=9`, ABL applies an overlay (question for mainline: will it get in the way)
- cmdline in the image: console=ttyMSM0,115200n8 earlycon=msm_geni_serial,0x4a90000 ... buildvariant=user
- os_version 10.0, patch 2021-05
- SoC: soc_id 445 (SM6115P), revision 1.0, hw_platform IDP. Mainline DTS: qcom,msm-id = <445 0x10000>, <420 0x10000>; qcom,board-id = <34 3>. Checked against the stock DT (live.dtb): msm-id <0x1BD 0x10000 0x1A4 0x10000>, board-id <0x22 0x3>. They match.

## For deviceinfo (draft)
deviceinfo_flash_offset_base="0x00000000"
deviceinfo_flash_offset_kernel="0x00008000"
deviceinfo_flash_offset_ramdisk="0x01000000"
deviceinfo_flash_offset_second="0x00f00000"
deviceinfo_flash_offset_tags="0x00000100"
deviceinfo_flash_offset_dtb="0x01f00000"
deviceinfo_flash_pagesize="4096"
deviceinfo_header_version="2"
deviceinfo_bootimg_qcdt="false"
deviceinfo_append_dtb="false"

## Debugging without UART
- ramoops in the mainline DTS @0xffc00000 (1 MiB, console 256 KiB). Check whether the area survives a warm reboot and whether stock Android sees it (/sys/fs/pstore).
- USB networking from the pmOS initramfs (pmos.debug-shell / telnet).

## ★ ABL + dtbo: why mainline did not boot and how to work around it (2026-10-29, confirmed)
- `fastboot boot` in this tablet's ABL works **once per bootloader session**. A second call in the same session gives
  `FAILED (remote: 'Failed to load/authenticate boot image: Load Error')` even for the stock image. Before every attempt: `fastboot reboot bootloader`.
- ABL **always** applies the overlay from the dtbo partition (entry [9] "Lenovo P11 WIFI PVT", msm-id 445/420, board-id <34 3>, 45 fragments, 138 labels in __fixups__).
  The mainline DTB has no `__symbols__` → the overlay fails → ABL answers `Booting OKAY` but does not start the kernel and returns to fastboot after ~9 s.
  (Header v2 with a dtb section and header v0 with an appended DTB behave the same.)
- **Workaround without writing to the device**: scripts/dtb_add_abl_sink.py adds `/abl-sink` to the DTB (status=disabled, no compatible) with a phandle node
  for every label of the stock overlays, plus `/__symbols__` where each label points to `/abl-sink/<label>`. ABL applies the overlay, all the junk lands
  in /abl-sink, the kernel ignores it (of_platform_populate does not descend into root nodes without a compatible).
  Side effect: ABL sets /model = "Lenovo P11 WIFI PVT" (the overlay root). Harmless.
- Result: kernel linux-nura-qcom-sm61x5 7.2.3 (binary package) + this DTB booted through `fastboot boot`, the USB gadget came up ~9 s after "Booting OKAY".
- Alternative for a permanent install: flash an empty or "neutral" dtbo to dtbo_a. That is a WRITE, only with the owner's consent.
- ★ **Tested on 29.10: `fastboot erase dtbo_b`** → ABL loads the DTB from boot.img without an overlay (model and compatible from our DTS, `androidboot.dtb_idx` = garbage).
  This is how it is installed now (slot b). A tip from the owner's partner.
  Advantage of the "sink" approach: stock Android on slot a keeps working unchanged.
- ABL edits the cmdline: "rdinit=/init" becomes "rd_nit=/init" (ABL searches for and mangles the "init=" substring?). rdinit defaults to /init anyway, no effect.
- dmesg: "[Firmware Bug]: Kernel image misaligned at boot" (ABL places the kernel at 0x8000, not at 2 MiB). Only a warning.
- `psci: failed to set PC mode: -3`. A warning.

## Debug environment (scripts/make_debug_bootimg.py + scripts/debug-initramfs/)
- ECM + ACM gadget (18d1:d001). macOS shows en2 (ECM) and /dev/cu.usbmodemj606f_debug3 (ACM shell).
- Alpine busybox-static has NO udhcpd/httpd/telnetd (they are in busybox-extras), so DHCP does not work. The Mac takes a link-local 169.254.x.x by itself.
  On the device: `ip addr add 169.254.42.1/16 dev usb0` (over ACM: scripts/acm_run.py), then `nc -lk -p 9100 -e /bin/sh` and scripts/tcp_run.sh.
- Safety net: if the CGI (/tmp/keepalive) is not touched within 300 s, `reboot -f`. Without httpd there is no CGI, so keepalive has to be created by hand over ACM.

## ★ Editing a built DTB (decompile/recompile): do a byte-exact round-trip first (kruzeman, PR #1)
If you edit a DTB by decompiling a built one rather than from `kernel/dts/`, first make sure a rebuild without changes gives the same file:
```sh
dtc -I dtb -O dts -o base.dts orig.dtb
dtc -I dts -O dtb -o rt.dtb  base.dts
cmp orig.dtb rt.dtb            # must be silent
```
For the PR author, such a rebuild turned `regulator-max-microvolt` of regulator l15 below its min → black screen after the logo.
Upstream dtc prints such values (`00 31 51 00`) as numbers and the round-trip is exact, so another tool was probably at fault;
but the `cmp` check is cheap and catches any such corruption. Spot-check properties with `scripts/fdtread.py <node-path> <property> a.dtb b.dtb`.

## ⚠ `fastboot boot` with slot a active (07.11)
Since 04.11 slot a is active (UEFI in boot_a, the UEFI/Windows work), and **dtbo_a is stock**. `fastboot boot` uses the dtbo of the current slot → ABL applies
the stock overlay on top of our DTB: model "Lenovo P11 WIFI PVT", Wi-Fi does not come up (no qmi from wlan), sometimes a reboot. This cost us a false alarm
"r122 breaks Wi-Fi". Before testing a kernel: `fastboot set_active b` → `fastboot boot …` → after the test `fastboot set_active a`.
Check: `cat /proc/device-tree/model` must say "Lenovo Tab P11 (HX83102P)".
"qcom_q6v5_pas a400000.remoteproc: Handover signaled, but it already happened" ~57 times in the first ~2 min is normal when booting from slot b (both r121 and r122).
