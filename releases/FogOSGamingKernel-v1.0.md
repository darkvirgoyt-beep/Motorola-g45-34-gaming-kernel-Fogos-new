# FogOS Gaming Kernel v1.0 — Motorola G45/34 (Fogos)

## Build status

This release contains a **successfully compiled Linux 5.4.302 Fogos kernel** from the user-provided `android_kernel_motorola_fogos-sixteen-qpr2` source. The build completed with a valid gzip-tested `Image.gz`, the Fogos base DTB, and both Fogos overlay DTBO files. The kernel was built from the complete device-specific `vendor/fogos_defconfig`, rather than a generic Qualcomm configuration.

| Item | Value |
|---|---|
| Device | Motorola G45 / G34 (`fogos`) |
| Source baseline | Android 16 QPR2 Fogos source |
| Kernel | Linux 5.4.302 |
| Build profile | `vendor/fogos_gaming_defconfig` |
| Kernel image SHA-256 | `7e1c887ff2532e607113d04d7125ed223147d137eaa97b57d9b04d29da6ca419` |
| Embedded root | Disabled (`CONFIG_KSU` is not set) |

## Included performance changes

The profile exposes supported performance options without altering voltage tables, clock limits, thermal trip points, or device-tree hardware values.

| Change | Result |
|---|---|
| `CONFIG_CPU_FREQ_GOV_PERFORMANCE=y` | The standard CPU **performance** governor is available for a kernel manager. |
| `CONFIG_DEVFREQ_GOV_PERFORMANCE=y` | The standard devfreq **performance** governor is available where the device exposes a compatible devfreq node. |
| BBR plus FQ | `CONFIG_TCP_CONG_BBR=y`, `CONFIG_DEFAULT_BBR=y`, and `CONFIG_NET_SCH_FQ=y` are enabled. |
| Fogos base configuration | Camera, display, audio, touch, modem, DTB, DTBO, and vendor options from the Fogos configuration are preserved. |
| KernelSU | Disabled because the supplied KernelSU tree is incompatible with this Linux 5.4 source during compilation. |

> This is a conservative gaming-oriented configuration. It does **not** bypass thermal protection, overclock the CPU/GPU, or force the performance governor at every boot. Those changes would create avoidable heat, stability, and battery risks.

## Important: this is **not** a direct `boot.img`

`Image.gz` is a kernel payload, not an Android boot image. **Do not run** `fastboot flash boot Image.gz`, and do not rename it to `boot.img`. That is not a valid Android boot image and can cause the bootloader error you saw: `Preflash validation failed`.

An Android `boot.img` must be built or repacked from the **exact Evolution X boot image for the ROM build currently installed on the phone**. It needs the matching Android boot header, ramdisk, AVB-related metadata, vendor modules, and device-specific boot parameters. The supplied source does not include that ROM-specific boot image or a verified Android 17 build environment, so publishing a universal direct-flash `boot.img` would be unsafe.

| Android version | Release status |
|---|---|
| Android 16 using the matching Fogos source/boot interface | Kernel payload compiled and validated; repack against the exact installed ROM boot image is still required. |
| Android 17 | **Not verified. Do not flash this payload** until the Android 17 ROM maintainer confirms that its kernel ABI, modules, DTB/DTBO, and boot-image interface are identical. |

## Safe integration requirements

Before anyone makes a flashable boot image from this release, they must have all of the following.

1. The exact unmodified `boot.img` from the currently installed Evolution X build, for the same security patch and slot.
2. The matching vendor boot, vendor modules, and DTBO interface required by that ROM.
3. A known-good Android boot-image repacking workflow for Fogos that preserves the original boot header and ramdisk.
4. A bootloader-unlocked test device, full backups of both boot slots, and a tested restore path.
5. Confirmation that the image passes `fastboot` validation **before** trying to make it persistent.

## Files

| File | Purpose |
|---|---|
| `Image.gz` | Compiled arm64 kernel payload; **not directly flashable**. |
| `blair-moto-fogos-base.dtb` | Compiled Fogos base device tree. |
| `blair-fogos-evt-overlay.dtbo` | EVT board overlay. |
| `blair-fogos-dvt1-overlay.dtbo` | DVT1 board overlay. |
| `fogos_gaming_defconfig` | Exact reproducible configuration. |
| `SHA256SUMS` | Checksums for every release file. |

## Reproducible build

```bash
make O=out ARCH=arm64 vendor/fogos_gaming_defconfig
make -j"$(nproc)" O=out ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- KCFLAGS='-Wno-error' Image.gz dtbs
```

The supplied Android 16 kernel tree emits warnings with a newer GCC toolchain. `KCFLAGS='-Wno-error'` only prevents newer compiler diagnostics from being promoted to errors; it does not suppress compilation errors. The completed build contains no fatal-error, undefined-reference, or linker-error entries.
