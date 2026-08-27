# FogOS — Motorola G45/G34 Performance Guide

## Scope

This guide applies to the Motorola G45/G34 (`fogos`) on the Evolution X Android 17 baseline. FogOS is a **stock-compatible performance profile**, not an overclock. The release must preserve the exact Evolution X `vendor_dlkm` ABI used by the camera, audio/Dolby, charging, Wi‑Fi, fingerprint, touch, sensors, and radio drivers.

## What FogOS safely tunes

The audited FogOS runtime helper applies only bounded process-level tuning when a supported game is detected:

- Affinity to the SM6375/Holi performance cluster (`f0`, CPUs 4–7 on the supported fogos layout).
- A modest `nice -10` priority rather than FIFO or real-time priority.
- Placement in the existing top-app task group when that node is available.
- Runtime profile selection through the restricted `/dev/fogos_profile` interface.

The helper does **not** write CPU frequency tables, GPU frequency tables, voltage nodes, charging limits, thermal zones, or AVB settings. Stock thermal protection remains enabled.

## What is intentionally not supported

FogOS does not add unvalidated OPP entries, voltage changes, thermal-trip overrides, or forced maximum frequency on all cores. Do not modify the Qualcomm EPSS LUT or bypass firmware frequency limits. Do not disable thermal zones or set passive trips to 125°C. Those changes can cause overheating, battery wear, charging faults, instability, or loss of stock hardware behavior.

The old `fogos_gaming_extreme.config` and unsafe duplicate gaming defconfig were removed because they could change module modes and other ABI-sensitive options. Do not recreate them under another filename.

## Runtime profiles

`balanced` is the default. `performance` and `extreme_gaming` are accepted profile names, but they must remain bounded by the trusted userspace profile implementation and the stock thermal/frequency limits. A profile name alone is not evidence of a higher sustained clock or frame rate.

## Verification

Before a device test, confirm the generated configuration preserves:

```text
CONFIG_CAMERA_CCI_INTF=m
CONFIG_SND_SOC_FS1815=m
CONFIG_MODVERSIONS=y
CONFIG_LTO=y
CONFIG_THINLTO=y
CONFIG_CFI_CLANG=y
CONFIG_CFI_CLANG_SHADOW=y
CONFIG_FOGOS_PROFILE=y
KernelSU disabled
```

For the Motorola G45/G34 test, remain on the working slot B. Temporarily boot the matching Android 17 boot image first, then test camera, audio/Dolby Atmos, charging, Wi‑Fi, Bluetooth, fingerprint, sensors, touch, reboot, and sustained gaming thermals. A 120-FPS label is only a target/demo description unless a repeatable device benchmark verifies sustained behavior.
