# 🚀 Quick Start: Create & Flash boot.img via Fastboot

## What is boot.img?

A **boot.img** is a single partition image containing your kernel + ramdisk that can be flashed directly via `fastboot`. It's the **fastest and most direct way** to test a new kernel without TWRP.

---

## ✅ Prerequisites

1. **Built kernel** → Run: `./build_fogos.sh`
2. **Stock boot.img** → Extract from:
   - Motorola firmware ROM package, OR
   - Your phone's TWRP backup (`/recovery_backup/boot.img`)
3. **fastboot installed** → `sudo apt install fastboot` (Linux/Mac) or [download from Google](https://developer.android.com/tools/releases/platform-tools)
4. **Bootloader unlocked** → Check: `adb reboot bootloader` → you should see "UNLOCKED"

---

## 🔧 Step 1: Create boot.img

### Option A: Automatic (Recommended)

```bash
# From repo root
chmod +x scripts/create_bootimg.sh
./scripts/create_bootimg.sh stock_boot.img FogOS-boot.img
```

**What it does:**
- ✅ Extracts parameters from your stock boot.img
- ✅ Packs in your compiled kernel (`out/arch/arm64/boot/Image*`)
- ✅ Creates `FogOS-boot.img`

---

### Option B: Manual (using mkbootimg)

If the script doesn't work, do it manually:

```bash
# Get stock boot params
unpackbootimg -i stock_boot.img
# Outputs: bootimg.cfg (contains offsets, base address, etc.)

# Create new boot with your kernel
mkbootimg \
  --kernel out/arch/arm64/boot/Image \
  --ramdisk ramdisk.img.gz \
  --base 0x80000000 \
  --kernel_offset 0x8000 \
  --ramdisk_offset 0x1000000 \
  --tags_offset 0x100 \
  --pagesize 4096 \
  --output FogOS-boot.img
```

---

## ⚡ Step 2: Flash via Fastboot

### Setup PC & Phone

```bash
# Enable Developer Options on phone:
Settings → About Phone → tap Build Number 7x → Developer Options enabled

# Enable USB Debugging:
Settings → Developer Options → USB Debugging → ON

# Boot to bootloader on phone:
adb reboot bootloader

# Verify phone connected:
fastboot devices
# Should show your device
```

### Flash the Kernel

```bash
# Flash boot partition
fastboot flash boot FogOS-boot.img

# Reboot to system
fastboot reboot

# Watch boot logs
adb logcat -s "FogOS"
```

---

## ⏱️ Timing

| Step | Time |
|------|------|
| Kernel build | ~2-3 min |
| Create boot.img | ~10 sec |
| Flash via fastboot | ~5 sec |
| First boot | ~1 min |
| **Total** | **~5 min** |

---

## ✅ Verify It Worked

After boot completes:

```bash
# Check kernel version
adb shell uname -r
# Output: 5.4.302-FogOS-Extreme-Gaming-v2.0

# Check boot params applied
adb shell cat /sys/devices/system/cpu/cpu6/cpufreq/scaling_governor
# Output: performance

# Check GPU
adb shell cat /sys/class/kgsl/kgsl-3d0/devfreq/governor
# Output: performance
```

---

## 🆘 Troubleshooting

### ❌ "No kernel image found"

Run the build first:
```bash
./build_fogos.sh
```

### ❌ "fastboot: device not found"

```bash
# Check USB debugging enabled
adb devices   # should list your phone

# Try manual bootloader entry
adb shell reboot bootloader

# On newer Motorola, you may need:
fastboot reboot fastboot  # to enter fastbootd (slot A/B devices)
```

### ❌ "Device is corrupt" after flash

This is an **AVB (Android Verified Boot)** error. The boot.img might be for wrong Android version.

**Quick fix:**
```bash
adb reboot bootloader
fastboot --disable-verity --disable-verification flash vbmeta vbmeta.img
fastboot flash boot FogOS-boot.img
fastboot reboot
```

### ❌ "Bootloop" (phone keeps restarting)

Your ramdisk might be incompatible.

**Workaround:**
```bash
# Reflash stock boot to recover
fastboot flash boot stock_boot.img
fastboot reboot

# Then try boot.img again, or use TWRP instead
```

---

## 🎯 Comparison: Fastboot vs TWRP

| Method | Speed | Recovery | Boot |
|--------|-------|----------|------|
| **Fastboot** | ⚡ 5-10 sec | Requires PC | Same |
| **TWRP** | ~30 sec | Works offline | Same |

**Fastboot is better for:** rapid testing during development  
**TWRP is better for:** reliable flashing without PC

---

## 📚 Reference

- [Android Boot Image Format](https://source.android.com/devices/bootloader/boot-image-header)
- [Fastboot Commands](https://developer.android.com/tools/releases/platform-tools)
- [Motorola G45 Firmware](https://firmware.motorola.com/)

---

<div align="center">

**⚡ Fast testing, fast development! — VirgoYT707 ⚡**

</div>
