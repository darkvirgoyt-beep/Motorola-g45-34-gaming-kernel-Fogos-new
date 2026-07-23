<div align="center">

# 📋 FogOS — Complete Flashing & Recovery Guide
### VirgoYT Gaming Kernel · by Prince (VirgoYT707)

</div>

---

## ✅ Pre-Flash Checklist

Before you flash, confirm every item:

- [ ] Bootloader is **unlocked**
- [ ] **TWRP** custom recovery installed
- [ ] **Nandroid backup** taken (TWRP → Backup → select all → Swipe)
- [ ] Battery is **above 50%**
- [ ] ZIP file downloaded from **Releases** tab (not copied from chat)
- [ ] You know your **exact device variant** (G45 or G34, which region)
- [ ] You have a **PC nearby** in case recovery is needed

---

## 🔓 Step 0 — Unlock Bootloader (if not done)

> ⚠️ Unlocking WIPES all data. Back up first.

```bash
# On phone: Settings → About Phone → tap Build Number 7x → enable Developer Options
# Developer Options → OEM Unlock → confirm

# On PC (with ADB installed):
adb reboot bootloader
fastboot oem unlock          # or: fastboot flashing unlock
# Confirm on phone screen
fastboot reboot
```

---

## 📱 Step 1 — Install TWRP Recovery

```bash
# Boot to fastboot
adb reboot bootloader

# Flash TWRP (download TWRP for holi/SM6375 from twrp.me)
fastboot flash recovery twrp-holi.img

# Boot directly into TWRP (without rebooting to system first)
fastboot boot twrp-holi.img
```

---

## 📥 Step 2 — Download the Kernel ZIP

Go to: **[GitHub → Releases → Latest](../../releases/latest)**

Download: `FogOS-Extreme-Gaming-v2.0-Holi-YYYYMMDD.zip`

Copy to your phone:
```bash
adb push FogOS-Extreme-Gaming-v2.0-Holi-YYYYMMDD.zip /sdcard/
```
Or copy via USB file transfer to `/sdcard/Download/`.

---

## ⚡ Step 3 — Flash the Kernel

```
1. Boot to TWRP:
   Power off → hold Volume Down + Power → select Recovery in fastboot

2. In TWRP:
   → Install
   → navigate to /sdcard/Download/
   → select  FogOS-Extreme-Gaming-v2.0-Holi-YYYYMMDD.zip
   → Swipe right to confirm flash

3. Wait for "Flashing Complete" — takes ~30 seconds

4. TWRP → Wipe → Advanced Wipe:
   ✅ Dalvik / ART Cache
   ✅ Cache
   (DO NOT wipe Data, System, or Internal Storage)
   → Swipe

5. TWRP → Reboot → System
```

**First boot: 2–4 minutes is normal.** The system is optimizing apps (dex compilation).

---

## 🔍 Step 4 — Verify It Worked

After boot, open a terminal app or ADB shell:

```bash
# Check kernel version (should show FogOS)
uname -r
# Expected output: 5.4.302-FogOS-Extreme-Gaming-v2.0

# Check governor (should say performance)
cat /sys/devices/system/cpu/cpu6/cpufreq/scaling_governor
# Expected: performance

# Check GPU governor
cat /sys/class/kgsl/kgsl-3d0/devfreq/governor
# Expected: performance

# Check boot log
cat /data/local/fogos_boot.log
# Should show all ✓ lines
```

---

## 🛡️ Complete Error Recovery Guide

---

### 🔁 BOOTLOOP — Phone keeps restarting

**Symptoms:** Phone reboots every 30–60 seconds, never reaches home screen.

**Fix A — Wipe cache (fastest fix, try this first):**
```
Boot TWRP → Wipe → Advanced Wipe → check Dalvik + Cache → Swipe → Reboot
```

**Fix B — Reflash the ZIP:**
```
Boot TWRP → Install → select ZIP → flash again → wipe cache → reboot
```

**Fix C — Kernel version mismatch (flash stock boot, then retry):**
```bash
# Download stock firmware for your G45/G34 variant from Motorola
# Extract boot.img from the firmware package

adb reboot bootloader
fastboot flash boot stock_boot.img
fastboot reboot

# Phone boots to stock kernel → now re-flash FogOS via TWRP
```

**Fix D — SELinux policy mismatch:**
```
In TWRP terminal:
  setprop ro.boot.selinux permissive
  Reflash ZIP → reboot
```

---

### 🧱 SOFT BRICK — Stuck logo, won't boot or enter recovery

**Symptoms:** Stuck on Motorola logo, black screen after logo, or TWRP won't load.

**Fix A — Force TWRP:**
```
Hold Volume Down + Power for 10 seconds (force reboot)
Immediately hold Volume Down again → fastboot appears
→ select Recovery
```

**Fix B — Fastboot flash (PC required):**
```bash
# Boot to fastboot: hold Volume Down + Power → release when fastboot shows
# Connect USB to PC

# Option 1: flash stock boot only
fastboot flash boot stock_boot.img
fastboot reboot

# Option 2: flash stock recovery + boot
fastboot flash recovery stock_recovery.img
fastboot flash boot stock_boot.img
fastboot reboot recovery
```

**Fix C — Full stock ROM via Rescue & Smart Assistant (RSA/MRST):**
```
1. Download "Rescue and Smart Assistant" (MRST) from Motorola support site
2. Install on Windows PC
3. Power OFF phone completely
4. Hold Volume Down while plugging USB cable to PC
5. RSA detects phone in rescue mode automatically
6. Click "Rescue" → downloads and flashes complete stock ROM
7. Phone reboots to factory stock — all data erased but phone works
```

---

### 💀 HARD BRICK — No display, no bootloader, PC doesn't detect phone

**Symptoms:** Phone is completely dead. No logo. No vibration. PC shows nothing. Holding buttons does nothing.

**Fix — Qualcomm EDL (Emergency Download Mode):**

This is the last resort that works even on dead phones. SM6375 has a hardware EDL mode.

```
STEP 1 — Enter EDL mode:
  Method A (button combo): 
    Power off → hold Volume Up + Volume Down + plug USB simultaneously
    PC should show "Qualcomm HS-USB QDLoader 9008" in Device Manager

  Method B (test point — for advanced users):
    Short the EDL test point on the motherboard while plugging USB
    (look up "SM6375 EDL test point" on XDA for your exact board revision)

STEP 2 — Install Qualcomm drivers on PC:
  Download: Qualcomm USB drivers (qdloader_hs_usb.inf)
  Or use Zadig to install WinUSB driver for the 9008 device

STEP 3 — Flash with QFIL:
  Download: QFIL (Qualcomm Flash Image Loader) tool
  Open QFIL → Select Flat Build
  Browse to your SM6375 firehose programmer (.elf file)
  Load rawprogram_unsparse.xml
  Click Download
  Wait ~5 minutes for all partitions to flash
  Phone reboots — fully restored

Where to get SM6375 firehose + firmware:
  → Official Motorola firmware packages (extracted from OTAS)
  → XDA Developers → Moto G45 thread → EDL firmware links
  → Telegram: search "Moto G45 EDL" or "SM6375 firehose"
```

---

### ❌ "Your device is corrupt" / AVB Error

```bash
# Disable Android Verified Boot verification:
adb reboot bootloader
fastboot flash vbmeta --disable-verity --disable-verification vbmeta.img
fastboot reboot bootloader
fastboot flash boot FogOS_boot.img   # if you have it separately
fastboot reboot
```

---

### ❌ Stuck on Boot Animation (5+ minutes)

```
Fix 1: Wait 8 minutes — first boot after flash takes long (normal)

Fix 2: TWRP → Wipe → Dalvik/ART Cache → Reboot System

Fix 3: TWRP → Advanced → Fix Permissions → Reboot
```

---

### ❌ No Calls / No Signal / SIM Issues

```
The kernel does NOT touch the modem/radio partition.
Fix: 
  Settings → SIM → toggle Airplane mode ON then OFF
  Reboot once more
  If persists: fastboot flash modem stock_modem.img
```

---

### ❌ Touch Screen Not Responding

```
Fix A: TWRP → Advanced → Fix Permissions → Reboot

Fix B: Reflash the ZIP — touch firmware may need re-init

Fix C: Check if driver loaded:
  adb shell dmesg | grep -i "touch\|synaptics\|nt36"
```

---

### ❌ Charging Slow / 33W Not Working

```
Fix: The 33W tuning runs during boot init.
Check log: adb shell cat /data/local/fogos_boot.log | grep -i charg

If "33W turbo charge configured ✓" is present → working
If missing → your PMIC path differs. Report to @VirgoYT707 with:
  adb shell ls /sys/class/power_supply/
```

---

### ❌ Banking Apps / Google Pay Failing

```
This kernel ships with SELinux=Enforcing.
If Play Integrity fails anyway:

Option A — Magisk + Integrity fix:
  Flash Magisk (latest) via TWRP
  Install module: "PlayIntegrityFix" from Magisk repo
  Reboot → banking apps should pass

Option B — zygisk-assistant (Magisk module):
  Hides root from specific apps
  Magisk → Modules → search "zygisk assistant"
```

---

### ❌ GPS Not Locking

```
This kernel doesn't change GPS. Fix is Android-side:
  Settings → Location → Mode → High Accuracy
  Clear cache of "GPS Test" or any GPS app
  Reboot outdoors with clear sky view
```

---

## 📞 Get Help

If none of the above fixes work:

1. Collect logs: `adb logcat -d > logcat.txt` + `adb shell dmesg > dmesg.txt`
2. Check the boot log: `adb shell cat /data/local/fogos_boot.log`
3. Contact: **Prince · VirgoYT707** with your device variant + error description

---

<div align="center">

**👑 VirgoYT Gaming Kernel — Built Different · Prince VirgoYT707 👑**

</div>
