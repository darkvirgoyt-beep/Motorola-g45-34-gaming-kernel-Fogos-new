# VirgoYT Gaming Kernel — FogOS Extreme Gaming Edition

**Device:** Motorola G45 / G34 (SM6375 — Holi Platform)  
**Developer:** Prince · VirgoYT707  
**Base:** Linux 5.4.302 · Android 16  
**Version:** v2.0 Ultra

---

## Overview

This is a hand-tuned Android kernel source for Motorola G45/G34 (codename: holi/fogos), built for maximum gaming performance in BGMI, PUBG Mobile, and Free Fire. Key features: performance governor by default, TCP BBR networking, BFQ I/O, ZRAM+ZSTD, WALT+CASS scheduler, and RT priorities for SurfaceFlinger.

---

## How to Build (on Replit)

### Quick build
```bash
./build_fogos.sh
```

### Clean build
```bash
./build_fogos.sh --clean
```

### Build + boot.img (requires stock_boot.img from your device)
```bash
# Place your device's stock boot image in the kernel root first, then:
./build_fogos.sh --bootimg stock_boot.img
```

### Interactive config editor
```bash
./build_fogos.sh --menuconfig
```

The **workflow** in Replit runs `./build_fogos.sh` automatically.

---

## Toolchain (Auto-Detected)

| Tool | Version |
|------|---------|
| Clang | 19.1.7 (via Nix) |
| LLVM tools | llvm-ar, llvm-nm, llvm-objcopy, llvm-strip |
| aarch64-unknown-linux-gnu-gcc | 13.3.0 (binutils/linking) |
| LLD | ld.lld (LLVM linker) |

Cross-compilation flags used:
- `ARCH=arm64`
- `CROSS_COMPILE=aarch64-unknown-linux-gnu-`
- `LLVM=1 LLVM_IAS=1`
- `CC=clang`

---

## Defconfigs

| File | Purpose |
|------|---------|
| `arch/arm64/configs/vendor/fogos_defconfig` | Full gaming defconfig (6817 options) |
| `arch/arm64/configs/vendor/fogos_gaming.config` | Gaming optimization fragment |
| `arch/arm64/configs/vendor/fogos_gaming_extreme.config` | Ultra extreme gaming additions (new) |

---

## Output Files

After a successful build, check the `release/` folder:

- `FogOS-Extreme-Gaming-v2.0-Ultra-Holi-<date>.zip` — AnyKernel3 flashable zip (TWRP)
- `FogOS-Extreme-Gaming-v2.0-Ultra-Holi-<date>-boot.img` — Direct flash via fastboot (if built)

Build logs: `out/build.log`

---

## Flash Instructions

### Via TWRP (easiest)
1. Boot into TWRP recovery
2. Install → select ZIP from `release/`
3. Swipe to flash → reboot

### Via fastboot (boot.img)
```bash
adb reboot bootloader
fastboot flash boot release/FogOS-Extreme-Gaming-v2.0-Ultra-Holi-<date>-boot.img
fastboot reboot
```

---

## Key Gaming Tunings

| Area | Tuning |
|------|--------|
| CPU | Performance governor · all 8 cores unlocked |
| GPU | Adreno 619L · power collapse disabled |
| Scheduler | WALT + SCHED_CASS · PREEMPT=y · HZ=300 |
| Network | TCP BBR + FQ · WLAN power-save OFF |
| Memory | ZRAM+ZSTD · swappiness=20 · 48MB LMK headroom |
| I/O | BFQ · low_latency=1 · slice_idle=0 |
| Security | SELinux enforcing (banking apps safe) |

---

## User Preferences

- Keep kernel source structure intact (do not migrate or restructure)
- Use clang/LLVM toolchain (LLVM=1) for all kernel builds
- fogos_defconfig is the primary config; apply gaming fragments on top
- Target: SM6375 / Holi / fogos device tree
