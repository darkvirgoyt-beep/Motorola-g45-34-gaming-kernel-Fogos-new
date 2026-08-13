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
