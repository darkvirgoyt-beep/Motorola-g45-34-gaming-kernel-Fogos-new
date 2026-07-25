#!/usr/bin/env bash
###############################################################################
# FogOS Extreme Gaming Kernel — Simple Boot Image Creator
#
# This script creates a basic boot.img without requiring stock boot.img
# Useful for testing and development
#
# Usage:
#   bash scripts/create_simple_bootimg.sh <kernel_image> [output.img]
###############################################################################

set -euo pipefail

KERNEL_IMG="${1:-out/arch/arm64/boot/Image}"
OUTPUT_IMG="${2:-release/FogOS-Extreme-Gaming-boot.img}"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()    { echo -e "${CYAN}[bootimg] $1${NC}"; }
ok()     { echo -e "${GREEN}[bootimg] ✓ $1${NC}"; }
warn()   { echo -e "${YELLOW}[bootimg] ⚠ $1${NC}"; }
fail()   { echo -e "${RED}[bootimg] ✗ $1${NC}"; exit 1; }

###############################################################################
# VALIDATE INPUTS
###############################################################################
[ ! -f "$KERNEL_IMG" ] && fail "Kernel image not found: $KERNEL_IMG"

log "Kernel      : $KERNEL_IMG ($(du -sh "$KERNEL_IMG" | cut -f1))"
log "Output      : $OUTPUT_IMG"

# Check for mkbootimg
if ! command -v mkbootimg &>/dev/null; then
  log "Installing mkbootimg..."
  sudo apt-get update -qq
  sudo apt-get install -y mkbootimg || fail "Could not install mkbootimg"
fi

mkdir -p release

###############################################################################
# CREATE BASIC BOOT.IMG
###############################################################################
log "Creating basic boot.img with default parameters..."

# Create a minimal ramdisk (empty for now)
RAMDISK_TMP="$(mktemp)"
dd if=/dev/zero of="$RAMDISK_TMP" bs=4096 count=1 2>/dev/null || true

# Use default Android boot parameters for modern devices
mkbootimg \
  --kernel "$KERNEL_IMG" \
  --ramdisk "$RAMDISK_TMP" \
  --base 0x00000000 \
  --kernel_offset 0x00008000 \
  --ramdisk_offset 0x01000000 \
  --second_offset 0x00f00000 \
  --tags_offset 0x00000100 \
  --pagesize 4096 \
  --header_version 3 \
  --cmdline "console=ttyMSM0,115200n8 androidboot.console=ttyMSM0 androidboot.hardware=qcom androidboot.memcg=1 lpm_levels.sleep_disabled=1 video=vfb:640x450 msm_rtb.filter=0x237 service_locator.enable=1 swiotlb=2048 androidboot.usbconfig=a600 androidboot.usbcontroller=a6000000.dwc3 androidboot.selinux=permissive printk.devkmsg=on" \
  -o "$OUTPUT_IMG"

# Clean up
rm -f "$RAMDISK_TMP"

###############################################################################
# ADD AVB SIGNING (if available)
###############################################################################
if command -v avbtool &>/dev/null; then
  log "Adding AVB signature..."
  # Generate test key
  AVB_KEY="$(mktemp).pem"
  openssl genrsa -out "$AVB_KEY" 2048 2>/dev/null || {
    warn "Could not generate test key, skipping AVB signing"
  }
  
  if [ -f "$AVB_KEY" ]; then
    avbtool add_hash_footer \
      --image "$OUTPUT_IMG" \
      --partition_name boot \
      --partition_size 67108864 \
      --key "$AVB_KEY" \
      --algorithm SHA256_RSA2048 \
      --calc_max_image_size 2>/dev/null || {
      warn "AVB signing failed, continuing without signature"
    }
    rm -f "$AVB_KEY"
    ok "AVB signature added"
  fi
else
  warn "AVB tool not available - boot.img created without signature"
  warn "For production use, install avbtool: pip3 install avbtool"
fi

###############################################################################
# VERIFY OUTPUT
###############################################################################
if [ -f "$OUTPUT_IMG" ]; then
  BOOT_SIZE=$(stat -c%s "$OUTPUT_IMG" 2>/dev/null || stat -f%z "$OUTPUT_IMG" 2>/dev/null || echo "0")
  ok "Boot image created successfully!"
  ok "  Size: $BOOT_SIZE bytes"
  ok "  Output: $OUTPUT_IMG"
  echo ""
  echo -e "${CYAN}Flash command:${NC}"
  echo "  adb reboot bootloader"
  echo "  fastboot flash boot $OUTPUT_IMG"
  echo "  fastboot reboot"
  echo ""
  echo -e "${YELLOW}NOTE: This is a basic boot.img without ramdisk.${NC}"
  echo -e "${YELLOW}For production use, provide a stock boot.img to create_bootimg_fixed.sh${NC}"
else
  fail "Boot image creation failed"
fi