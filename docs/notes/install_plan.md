# Plan for installing to internal storage

> **Done on 29.10 with a different scheme** (with the owner's permission: "any slot", "you can wipe Android"):
> rootfs → **super** (`fastboot flash super lenovo-j606f.img`, sparse image), boot.img → **boot_b**, `fastboot --set-active=b`.
> userdata was given to the pmbootstrap workspace, dtbo_b was left alone (the "sink" in the DTB works). Details: LOG.md 29.10, STATE.md.
> **dtbo_b erased on 29.10** (`fastboot erase dtbo_b`, a tip from the owner's partner): with an erased dtbo ABL does not apply an overlay, compatible = lenovo,j606f.
> An empty DTBO table (step A0) was not tested — erasing already solves the problem.
> **29.10 (night): rootfs moved from super to userdata** (block by block, same UUIDs; the GPT of the subpartitions in super was removed, a dump is kept) — author's notes, device r6.
> The result matches option A below (rootfs in userdata, dtbo_b erased), except that dtbo_b was erased rather than replaced with an empty table.
> The original plan (option A with an empty dtbo_b and rootfs in userdata) is kept below for history.

Every step below writes to internal storage. Before each one make sure the backup is in place (BACKUP/README.md, sha256).

## Option A (recommended): pmOS on slot b, Android stays on slot a
Slot b has never booted (`slot-successful:b:no`) and holds the factory copies. Android on a is not touched.

### Step A0. Check whether ABL accepts an empty dtbo (without the "sink" and without HACK 0002)
Writes only dtbo_b (24 MiB partition; file out/dtbo_empty.img: a valid DTBO table with 0 entries, sha256 51c15f49…).
```bash
~/platform-tools/fastboot flash dtbo_b out/dtbo_empty.img
~/platform-tools/fastboot --set-active=b
~/platform-tools/fastboot reboot bootloader
~/platform-tools/fastboot boot out/<image with a DTB WITHOUT the sink>.img
```
Expected: ABL applies no overlay → the root compatible stays "lenovo,j606f", ubwc_config/pd_mapper work without the HACK.
If ABL does not boot: `fastboot --set-active=a` (Android is intact), and pmOS keeps the sink variant (tested).
Rollback: `fastboot flash dtbo_b BACKUP/partitions/dtbo_b.img; fastboot --set-active=a`.

### Step A1. pmOS kernel → boot_b
```bash
~/platform-tools/fastboot flash boot_b boot.img        # from pmbootstrap export
```
Rollback: `fastboot flash boot_b BACKUP/partitions/boot_b.img`.

### Step A2. rootfs
userdata (≈110 GiB) → pmOS rootfs. **Wipes the Android data** (the owner said it does not matter; still ask again right before the step).
```bash
~/platform-tools/fastboot flash userdata <rootfs>.img   # pmbootstrap export, sparse
```
Android on slot a will then have no data (factory reset). It boots if userdata is formatted again (LMSA/recovery).
Alternative without losing Android data: rootfs on an SD card (a card is needed).

### Step A3. Active slot
```bash
~/platform-tools/fastboot --set-active=b && ~/platform-tools/fastboot reboot
```
pmOS must mark the boot as successful (qbootctl -m), otherwise ABL falls back to a after a few attempts.

## Option B: replace Android on slot a
The same, but with boot_a/dtbo_a. Rollback: BACKUP/partitions/{boot_a,dtbo_a}.img or BACKUP/stock/boot_a_stock_from_magisk.img.

## Full emergency rollback
EDL + qdl + the full Lenovo firmware (see the wiki, Back to stock) or BACKUP/partitions/*.img (all partitions except userdata).

## Enable with care
- rmtfs in pmOS writes to modemst1/modemst2/fsg (EFS) — these are modem partitions. A backup exists, but enable it only with the owner's consent.
