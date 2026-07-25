# VirgoYT Gaming Kernel — FogOS Extreme Gaming Edition

**Developer:** Prince · VirgoYT707  
**Device:** Motorola G45 / G34 (SM6375 / Holi)  
**Android Version:** 16  
**Kernel Base:** Linux 5.4.302  
**Version:** v2.0 Ultra  
**Motto:** *"I don't chase. I attract. I WIN."*

---

## Overview

A gaming-optimized Android kernel for the Motorola G45 (Qualcomm SM6375 / Holi platform), targeting maximum BGMI FPS with the lowest possible latency while remaining daily-driver stable and bootloop-safe.

---

## Repository Structure

```
.
├── arch/arm64/configs/vendor/
│   ├── fogos_defconfig          # Full auto-generated defconfig (base)
│   ├── fogos_gaming.config      # ← FogOS gaming optimization fragment
│   ├── holi-qgki_defconfig      # Base Holi QGKI defconfig
│   ├── holi_GKI.config          # Holi GKI config fragment
│   └── holi_QGKI.config         # Holi QGKI config fragment
├── anykernel3/
│   ├── anykernel.sh             # AnyKernel3 installer script
│   ├── fogos_gaming_init.sh     # Runtime gaming tuning (runs at boot)
│   └── META-INF/                # Android flashable ZIP metadata
├── build_fogos.sh               # ← Main build script
├── drivers/hid/hid-aksys.c      # Custom HID vibrator driver
└── CHANGES.md                   # Kernel change log
```

---

## FogOS Gaming Optimizations

### CPU
- Governor: `schedutil` (WALT-aware, fast ramp-up)
- Preemption: `PREEMPT=y` (full preemption, lowest latency)
- Schedulers: `SCHED_CASS` + `SCHED_WALT` (Qualcomm WALT)
- Input boost: Big core (CPU4-7) boosted to 1.7GHz on touch events
- `uclamp` task group clamping enabled (foreground task priority)

### GPU
- Governor: `msm-adreno-tz` (Qualcomm's performance-aware governor)
- Idle timer lowered for fast GPU ramp-up
- GPU throttling reduced for sustained gaming performance

### Memory
- ZRAM with **ZSTD** compression (fastest + best ratio)
- `LRU_GEN` / MGLRU for better memory reclaim
- `vm.swappiness=40` — keep game data in RAM
- `vm.vfs_cache_pressure=50` — preserve filesystem cache
- Dirty page ratios tuned to reduce write stalls

### I/O
- Scheduler: **BFQ** with `low_latency=1`, `slice_idle=0`
- 128KB read-ahead for gaming workloads
- UFS storage optimized

### Network
- TCP congestion: **BBR** (lowest ping for BGMI)
- Default qdisc: **FQ** (required for BBR)
- TCP Fast Open enabled
- Buffer sizes tuned for low latency (not max throughput)

### Scheduler
- `sched_min_granularity_ns=1ms` (responsive preemption)
- `sched_latency_ns=5ms` (faster task turns)
- `sched_autogroup_enabled=0` (preserve Android priorities)

### Thermal
- Trip points raised +3°C (delays throttling, max 95°C)

### Logging
- `kernel.printk` reduced (errors/warnings only)
- `DISABLE_TRACE_PRINTK=y`
- Debug configs disabled in defconfig

### Security
- SELinux: **Enforcing** (banking apps work)
- AVB/Bootloader compatible

---

## How to Build

Builds run automatically on GitHub Actions — no local Linux machine needed.

### ✅ Option 1 — GitHub Actions (Recommended)

1. Go to your repo → **Actions** → **FogOS Kernel — Build & Boot Image**
2. Click **Run workflow**
3. Set "Create GitHub Release" to `true` if you want a release
4. Download the artifacts when done:
   - `FogOS-boot-YYYYMMDD-HHMM.img` → flash via **fastboot** ← main output
   - `FogOS-Extreme-Gaming-v2.0-Holi-*.zip` → flash via **TWRP**

Auto-builds also trigger on every push to `main` or `sixteen-qpr2` when kernel source files change.

### ✅ Option 2 — Replit Shell (for editing / testing scripts)

```bash
# Syntax-check build scripts
bash -n build_fogos.sh

# Repack boot.img with a pre-built kernel (no compilation needed)
bash scripts/create_bootimg.sh stock/boot.img <kernel_Image> release/FogOS-boot.img
```

> Full kernel compilation (cross-compile ARM64) is only supported on the GitHub Actions runner, not in this Replit environment.

---

## How to Flash

### Method 1 — Fastboot (Recommended for Moto G45)

```bash
# Requires unlocked bootloader
adb reboot bootloader
fastboot flash boot FogOS-boot-YYYYMMDD.img
fastboot reboot
```

If you get `FAILED (remote: AVB footer not found)`:
```bash
fastboot --disable-verity --disable-verification flash boot FogOS-boot-YYYYMMDD.img
```

### Method 2 — TWRP

1. Boot into **TWRP** custom recovery
2. Go to **Install** → select the ZIP
3. Swipe to confirm flash
4. Reboot — the gaming init script runs automatically at boot

---

## Deliverables

| File | Description |
|------|-------------|
| `release/FogOS-boot-YYYYMMDD.img` | **Fastboot-flashable boot image** (primary) |
| `release/FogOS-Extreme-Gaming-v2.0-Holi-*.zip` | AnyKernel3 TWRP ZIP |
| `stock/boot.img` | Stock Moto G45 boot image (source for repack) |
| `scripts/create_bootimg.sh` | Boot image packer (unpack + repack) |
| `anykernel3/fogos_gaming_init.sh` | Runtime boot tuning script |

---

## User Preferences

- Device: Motorola G45 (SM6375 / Holi platform)
- Android: 16
- Kernel base: Linux 5.4.302
- Gaming target: BGMI (maximum FPS, lowest latency)
- Style: Keep SELinux enforcing, banking app compatible, daily-driver stable
