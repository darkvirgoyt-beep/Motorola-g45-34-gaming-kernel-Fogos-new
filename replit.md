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

> **Build on Ubuntu 20.04 or 22.04** — Kernel compilation requires a Linux host with a cross-compiler. Use GitHub Actions for automated cloud builds (see Releases tab).

### 1. Install dependencies
```bash
sudo apt-get install -y bc bison build-essential ccache curl flex \
  g++-multilib gcc-multilib git gnupg gperf imagemagick \
  lib32ncurses5-dev lib32readline-dev lib32z1-dev liblz4-tool \
  libncurses5 libncurses5-dev libssl-dev libxml2-utils lzop \
  pngcrush rsync zip zlib1g-dev python3 python-is-python3
```

### 2. Download Clang toolchain
```bash
mkdir -p ~/toolchains
# ZyCromerZ Clang (recommended for Android 5.4)
git clone --depth=1 https://github.com/ZyCromerZ/Clang \
  -b 20 ~/toolchains/clang
```

### 3. Edit toolchain paths in build_fogos.sh
```bash
CLANG_DIR="${HOME}/toolchains/clang"
```

### 4. Build
```bash
chmod +x build_fogos.sh
./build_fogos.sh
```

### 5. Output
- `release/FogOS-Extreme-Gaming-v1.0-Holi-YYYYMMDD.zip` — flash with TWRP

### Clean build
```bash
./build_fogos.sh --clean
```

### menuconfig
```bash
./build_fogos.sh --menuconfig
```

---

## How to Flash

1. Boot into **TWRP** custom recovery
2. Go to **Install** → select the ZIP
3. Swipe to confirm flash
4. Reboot — the gaming init script runs automatically at boot

---

## Deliverables

| File | Description |
|------|-------------|
| `Image.gz-dtb` | Kernel image with embedded DTB |
| `dtbo.img` | Device tree overlay image |
| `FogOS-Extreme-Gaming-v1.0-Holi-YYYYMMDD.zip` | AnyKernel3 flashable ZIP |
| `anykernel3/fogos_gaming_init.sh` | Runtime boot tuning script |

---

## User Preferences

- Device: Motorola G45 (SM6375 / Holi platform)
- Android: 16
- Kernel base: Linux 5.4.302
- Gaming target: BGMI (maximum FPS, lowest latency)
- Style: Keep SELinux enforcing, banking app compatible, daily-driver stable
