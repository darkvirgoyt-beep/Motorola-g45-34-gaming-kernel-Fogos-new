# FogOS Extreme Gaming Kernel — Build & Boot Guide

## Quick Build Instructions

### Prerequisites
- Ubuntu 20.04+ or similar Linux distribution
- Clang 19+ or GCC cross-compiler
- Android build tools (mkbootimg, avbtool)

### Installation
```bash
# Install build dependencies
sudo apt-get update
sudo apt-get install -y bc bison flex libssl-dev make \
  gcc-aarch64-linux-gnu clang unzip mkbootimg \
  gcc g++ python3 python3-pip openssl lld

# Install AVB tool for signing
pip3 install avbtool
```

### Building the Kernel
```bash
# Clone the repository
git clone https://github.com/darkvirgoyt-beep/Motorola-g45-34-gaming-kernel-Fogos-new.git
cd Motorola-g45-34-gaming-kernel-Fogos-new

# Clean build
bash build_fogos.sh --clean

# Build kernel
bash build_fogos.sh --ci
```

### Creating boot.img
```bash
# If you have a stock boot.img
bash scripts/create_bootimg_fixed.sh stock_boot.img out/arch/arm64/boot/Image release/FogOS-boot.img

# Or use the build script which includes packaging
bash build_fogos.sh
```

## GitHub Actions Build

The repository includes automated GitHub Actions workflows:

1. **Build Workflow** (`.github/workflows/build.yml`)
   - Automatically builds kernel on push
   - Creates boot.img with AVB signing
   - Generates AnyKernel3 ZIP
   - Uploads artifacts

2. **Release Workflow** (`.github/workflows/release.yml`)
   - Publishes releases from build artifacts
   - Includes both ZIP and boot.img files

### Using GitHub Actions
1. Push your changes to GitHub
2. Go to Actions tab in your repository
3. Run the "FogOS Extreme Gaming - Build & Release" workflow
4. Download the artifacts from the completed run
5. Optionally create a release using the "Publish Kernel Release" workflow

## Fixing Boot Issues

### Common Boot Problems

#### 1. AVB Verification Errors
**Error**: "Your device is corrupt" or "Verification failed"

**Solution**:
```bash
# Disable AVB verification temporarily
adb reboot bootloader
fastboot --disable-verity --disable-verification flash vbmeta vbmeta.img
fastboot flash boot release/FogOS-Extreme-Gaming-boot.img
fastboot reboot
```

#### 2. dm-verity Errors
**Error**: "dm-verity failed" or filesystem verification errors

**Solution**:
```bash
adb reboot bootloader
fastboot flash vbmeta --disable-verity vbmeta.img
fastboot flash boot release/FogOS-Extreme-Gaming-boot.img
fastboot reboot
```

#### 3. "No OS Installed" Error
**Error**: Bootloader shows "No OS installed"

**Solution**:
```bash
adb reboot bootloader
fastboot flash vbmeta --disable-verity --disable-verification vbmeta.img
fastboot flash boot release/FogOS-Extreme-Gaming-boot.img
fastboot reboot
```

### Using the Fix Script
```bash
# Generate fix commands
bash scripts/fix_avb_issues.sh --help

# Get commands for disabling verification
bash scripts/fix_avb_issues.sh --disable-verification
```

## Kernel Configuration

### Available Defconfigs
- `vendor/fogos_defconfig` - Primary gaming configuration
- `vendor/holi-qgki_defconfig` - Alternative Holi platform config
- `defconfig` - Default configuration

### Gaming Features
The kernel includes these optimizations:
- CPU: Performance governor, all cores at peak
- GPU: Max clock locked, no idle throttle
- Thermal: Bypassed throttle limits
- Network: TCP BBR, game priority marking
- Memory: ZRAM ZSTD, optimized swappiness
- I/O: BFQ scheduler with low latency

## Troubleshooting

### Build Issues

#### Toolchain Errors
**Problem**: "clang: command not found"
```bash
# Install clang
sudo apt-get install clang
# Or use specific version
sudo apt-get install clang-19
```

#### Cross-compiler Errors
**Problem**: "aarch64-linux-gnu-gcc: command not found"
```bash
sudo apt-get install gcc-aarch64-linux-gnu
```

#### VDSO32 Compilation Errors
The build script automatically applies Clang 19+ compatibility fixes for ARM32 VDSO.

### Boot Issues

#### Bootloop
1. Boot to TWRP recovery
2. Wipe Cache + Dalvik Cache
3. Reflash the kernel ZIP
4. If still failing, flash stock kernel first

#### Touch Not Working
1. Boot to TWRP
2. Advanced → Fix Permissions
3. Reboot

#### No Signal/SIM
1. Settings → SIM & Network
2. Toggle Airplane mode ON/OFF
3. Reboot

## Advanced: Manual boot.img Creation

If you need to create a boot.img manually with specific parameters:

```bash
# Extract stock boot.img parameters
unpack_bootimg -i stock_boot.img -o extracted/

# Note the parameters from the output
# Create new boot.img with those parameters
mkbootimg \
  --kernel out/arch/arm64/boot/Image \
  --ramdisk extracted/ramdisk \
  --base 0x00000000 \
  --kernel_offset 0x00008000 \
  --ramdisk_offset 0x01000000 \
  --tags_offset 0x00000100 \
  --pagesize 4096 \
  --header_version 3 \
  -o custom_boot.img

# Add AVB signature
avbtool add_hash_footer \
  --image custom_boot.img \
  --partition_name boot \
  --partition_size 67108864 \
  --key your_key.pem \
  --algorithm SHA256_RSA2048
```

## Verification

### Verify Kernel Build
```bash
# Check kernel image
file out/arch/arm64/boot/Image
ls -lh out/arch/arm64/boot/Image*

# Check boot.img
file release/FogOS-Extreme-Gaming-boot.img
ls -lh release/FogOS-Extreme-Gaming-boot.img
```

### Verify AVB Signature
```bash
avbtool verify_image --image release/FogOS-Extreme-Gaming-boot.img
```

## Support

For issues specific to:
- **Build problems**: Check this guide and GitHub Actions logs
- **Boot problems**: Use the fix_avb_issues.sh script
- **Device-specific problems**: Check FLASHING_GUIDE.md
- **Gaming optimizations**: See README.md

## Credits

- **Developer**: Prince (VirgoYT707)
- **Base**: Linux 5.4.302 · Android 16
- **Device**: Motorola G45 / G34 (SM6375 — Holi Platform)

---
*"I don't chase. I attract. I WIN."* — VirgoYT707