# FogOS Gaming Kernel Ecosystem Analysis

## Current architecture

This tree is a Qualcomm Android 5.4 QGKI kernel for ARM64 with Motorola/Holi vendor configuration. The build helper prefers `arch/arm64/configs/vendor/fogos_defconfig`, falls back to `holi-qgki_defconfig`, and overlays FogOS gaming fragments. Existing AnyKernel scripts already tune CPU, KGSL GPU, WALT/uclamp, VM, I/O, touch IRQ affinity, and foreground game processes.

## Safe improvement plan

* Keep QGKI and Android userspace ABI compatibility: prefer runtime sysfs/sysctl tuning over invasive scheduler, OPP, KGSL, or thermal driver rewrites.
* Use hardware-reported CPU/GPU frequency limits only; never write invented overclock bins.
* Detect available controls dynamically and ignore missing paths for ROM portability.
* Preserve thermal zones and emergency protection. FogOS may raise writable trip points to a configurable 90°C cap, but must not disable thermal protection or cooling devices permanently.
* Profiles are stored in `/data/local/fogos_profile`: `balanced`, `performance`, or `extreme_gaming`.

## Risky modifications avoided

* Disabling thermal drivers or cooling devices completely.
* Forcing CPU/GPU frequencies beyond OPP/LUT limits.
* Hard-coding one KGSL sysfs layout as mandatory.
* Kernel ABI changes that can break Android 17 vendor modules.
* Aggressive LMK/ZRAM changes that can kill background services or cause swap stalls.

## Android 17 audio/Dolby compatibility

Evolution X Android 17 should keep Motorola's Holi `techpack/audio` route definitions as the single active audio stack. FogOS therefore avoids forcing duplicate generic in-tree Qualcomm ASoC machine drivers from the gaming fragment and relies on `techpack/audio/config/holiauto.conf` for QTI post-processing, Bolero, WCD937x, and hardware-dependent routing. Runtime scripts also avoid changing `audio.*`/`ro.audio.*` properties after boot, because that can desynchronise Dolby effects from AudioFlinger policy and crash Dolby/audioserver.

## Boot image size/build compatibility

The Moto G45/G34 boot partition is treated as a strict 96 MiB target. FogOS keeps the raw uncompressed ARM64 `Image` required by the bootloader, but the extreme fragment now preserves `CC_OPTIMIZE_FOR_SIZE` and disables debug-info/kallsyms bloat so GitHub Actions can create a boot image that fits instead of failing at the final flashable-image step.

## Camera CCI link fix

Moto Holi ext configs use `CONFIG_CAMERA_CCI_INTF=m`; FogOS now matches that so `cci_intf` is built as a DLKM-side camera helper instead of being linked into `vmlinux`. This fixes clang LTO/CFI link failures around `cci_intf_ioctl` when the rest of Spectra camera is kept outside the boot Image, and it avoids unnecessary boot partition growth.
