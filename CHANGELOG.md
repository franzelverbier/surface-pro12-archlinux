# Changelog / milestones

All dates 2026. Kernel reference build is **`7.1.0-next-20260626`** unless noted.

## Kernel reference

- **`7.1.0-next-20260626`** — linux-next, compiled 2026-06-26 18:28 (CEST), gcc 13.3.0, GNU ld 2.42. This is *the* reference build carrying `x1p42100` support.
- The stock Arch `linux-aarch64` package (7.1.x) is held in `IgnorePkg`: GRUB boots the custom `/boot/Image`, not the stock kernel/initramfs. A tool reporting "a newer kernel available" is looking at the stock package, not the running kernel.

## Milestones

- **2026-06-26** — First successful boot to root shell on the custom linux-next kernel; console + Bluetooth working.
- **2026-06-28** — KDE desktop shown on the internal panel; Wi-Fi associated, SSH reachable. (Early USB-boot media proved unreliable — a marginal USB flash controller caused ext4 I/O corruption under repeated reboots.)
- **2026-06-30** — Storage-strategy iterations (USB key → Ventoy vdisk → USB SSD); GPT-repair workflow for raw-writing a small image onto a large disk; WPA3-SAE Wi-Fi fix.
- **~2026-07 (early)** — Moved to an **internal ext4 install**, dual-boot with Windows, for full reliability. Internal display + KDE + GPU accel working.
- **2026-07-03** — HW video codec fixed (supplied `qcvss8380_pa.mbn`); `/dev/video0` + `/dev/video1` live. Audio confirmed working (topology now in linux-firmware). Battery telemetry identified as the main remaining issue.

## Upcoming

- **Linux 7.2** integrates the SP12 DTS in mainline → the custom DTB and home-compiled kernel are expected to become unnecessary.
