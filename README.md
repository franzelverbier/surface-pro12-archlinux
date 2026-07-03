# Surface Pro 12" (Snapdragon X Plus) — Linux

Running **Arch Linux ARM** on the **Microsoft Surface Pro 12" (1st Ed, Snapdragon)** — SoC **Snapdragon X Plus 8-core, `x1p42100`, ARM64** — a device with no upstream kernel support at the time this work began.

This builds directly on **[Harrison Vanderbyl's `surface-pro-12-inch-linux`](https://github.com/harrisonvanderbyl/surface-pro-12-inch-linux)** (device tree + firmware groundwork). None of this exists without that work — thank you.

> Status snapshot: **2026-07-03**. The device runs as an **internal dual-boot** (Windows + Arch Linux ARM) with working internal display, **KDE Plasma**, GPU acceleration, hardware video codec, audio, and Wi-Fi.

## Status

| Component | State | Notes |
|---|---|---|
| Boot | ✅ | Custom linux-next kernel, GRUB (arm64-efi), internal dual-boot |
| Internal display (eDP) | ✅ | KDE Plasma / Wayland. Non-fatal `panel-edp` probe warning remains |
| GPU 3D accel | ✅ | Adreno X1-45 — OpenGL 4.6 (freedreno) + Vulkan 1.4 (turnip), Mesa 26.1 |
| HW video codec | ✅ | Decode + encode via V4L2 after supplying one firmware blob (see Fixes) |
| Audio | ✅ | Card + ADSP up, headset jack detected; topology now in linux-firmware |
| Wi-Fi | ✅ | ath12k / WCN7850 (FastConnect 7800), wpa_supplicant |
| Battery | ⚠️ | Charger/USB-C detection works, but capacity/percentage telemetry is not exposed (driver limitation) |
| Suspend / resume | ❌ | Snapdragon does not resume — sleep targets masked (see Stability) |
| Surface HID (cover / sensors) | ⚠️ | `unexpected descriptor length` warnings |

## Hardware IDs

- **SoC:** Snapdragon X Plus 8-core, `x1p42100`, ARM64
- **GPU:** Adreno X1-45 (freedreno / turnip)
- **Wi-Fi/BT:** Qualcomm FastConnect 7800 / WCN7850 (PCI subsystem `00ab:1414`)
- **Audio:** `X1P42100-Microsoft-Surface-Pro-12in` (AudioReach / q6apm)
- **Internal storage:** KIOXIA UFS ~477 GB (shared with Windows)

## Kernel

- **linux-next**, reference build `7.1.0-next-20260626`, compiled with `x1p42100` support absent from stable kernels: `CLK_X1P42100_GPUCC/CAMCC/VIDEOCC`, `CLK_X1E80100_GCC/DISPCC`, `PINCTRL_X1E80100` built in; `DRM_MSM`, `ATH12K` as modules.
- **DTB** from Harrison Vanderbyl's repo (SP12 board not yet upstream), loaded by GRUB (`devicetree`).
- **Heads-up:** mainline **Linux 7.2** integrates the SP12 DTS — once it lands, the custom DTB and home-compiled kernel should become unnecessary.

## Install approach

Linux root lives on an **internal ext4 partition** alongside Windows. GRUB (`arm64-efi`, standalone `BOOTAA64.EFI` on the ESP) loads `/boot/Image` + initramfs + DTB. Earlier iterations booted from USB (SanDisk key, then Ventoy vdisk, then USB SSD) before moving to the internal disk for reliability — see `CHANGELOG.md`.

## Fixes / how-tos

### Hardware video codec firmware (`qcom-iris`)

The iris video codec requires `qcvss8380_pa.mbn`, which is **not** shipped in linux-firmware. Without it, `dmesg` spams `Direct firmware load ... failed with error -2` and the codec never initializes.

Extract it from the Windows driver store (dual-boot users have it locally):

```
Windows/System32/DriverStore/FileRepository/qcdx8380.inf_arm64_*/qcvss8380_pa.mbn
```

Copy it to:

```
/lib/firmware/qcom/x1p42100/Microsoft/Surface12/qcvss8380_pa.mbn
```

If several driver versions are present, pick the one whose `qcdxkmbase8380.bin` matches (md5) the graphics firmware already installed on the Linux side, to keep the DX firmware set consistent.

- **Do NOT blacklist `qcom_iris`** — blacklisting freezes boot via `sync_state`. Supplying the firmware is the correct fix.
- After reboot you get `/dev/video0` (decoder) + `/dev/video1` (encoder). Use them via **V4L2 mem2mem**: `mpv --hwdec=v4l2m2m`, `ffmpeg -hwaccel v4l2m2m`.
- **Note:** VA-API is *not* the Adreno path. The `vaInitialize failed` warning in Electron/Chromium apps is harmless — video accel goes through V4L2.

### Audio

The AudioReach topology `X1P42100-Microsoft-Surface-Pro-12in-tplg.bin` now ships in **linux-firmware** under `qcom/x1e80100/`. The ADSP firmware `qcadsp8380.mbn` lives under `qcom/x1p42100/Microsoft/Surface12/`. With both present, the card comes up (`q6apm`), the headset jack is detected, and PipeWire routes normally.

## Known issues / TODO

- **Battery telemetry incomplete** (`qcom-battmgr` on `x1p42100`): only voltage + temperature are exposed; `charge_now` / `charge_full` / capacity return `ENODATA`, so there is no charge percentage. Charger/USB-C presence *is* detected. Under investigation.
- **`panel-edp` probe warning** (`drivers/gpu/drm/panel/panel-edp.c`) — non-fatal; display works.
- **Surface HID descriptor warnings** — cover / sensors.
- **No suspend/resume** — masked (see below).

## Stability notes

- **No resume from suspend** on Snapdragon → mask `sleep`/`suspend`/`hibernate`/`hybrid-sleep` targets and set logind `IdleAction=ignore`, `HandleLidSwitch=ignore`.
- **Fragile USB controller under heavy load:** avoid sustained I/O between two USB SSDs simultaneously (locks the bus); `usbcore.autosuspend=-1` keeps USB storage from dropping (`-EIO` / ext4 corruption).

## Credits

- **Harrison Vanderbyl** — [`surface-pro-12-inch-linux`](https://github.com/harrisonvanderbyl/surface-pro-12-inch-linux): the device tree + firmware groundwork this is built on.
- Arch Linux ARM · linux-next · Mesa (freedreno / turnip) · the aarch64-laptops community.
