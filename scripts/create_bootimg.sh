#!/usr/bin/env bash
###############################################################################
# FogOS Extreme Gaming Kernel — Boot Image Creator
# Developer : Prince · VirgoYT707
# Device    : Motorola G45 / G34 (SM6375 — Holi Platform)
#
# Usage:
#   bash scripts/create_bootimg.sh <stock_boot.img> <kernel_image> <output.img>
###############################################################################

set -euo pipefail

STOCK_IMG="${1:-stock/boot.img}"
KERNEL_IMG="${2:-out/arch/arm64/boot/Image}"
OUTPUT_IMG="${3:-release/FogOS-Extreme-Gaming-boot.img}"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${CYAN}[bootimg] $*${NC}"; }
ok()   { echo -e "${GREEN}[bootimg] ✓ $*${NC}"; }
fail() { echo -e "${RED}[bootimg] ✗ $*${NC}"; exit 1; }

[ -f "$STOCK_IMG" ]  || fail "Stock boot.img not found: $STOCK_IMG"
[ -f "$KERNEL_IMG" ] || fail "Kernel image not found: $KERNEL_IMG"

log "Stock  : $STOCK_IMG  ($(du -sh "$STOCK_IMG"  | cut -f1))"
log "Kernel : $KERNEL_IMG ($(du -sh "$KERNEL_IMG" | cut -f1))"
log "Output : $OUTPUT_IMG"

###############################################################################
# Install tools if missing
###############################################################################
if ! command -v unpack_bootimg &>/dev/null || ! command -v mkbootimg &>/dev/null; then
  log "Installing mkbootimg..."
  sudo apt-get install -y mkbootimg
fi

# Fix Ubuntu 24.04 broken gki import
GKI_DIR=$(python3 -c "import site; print(site.getsitepackages()[0])")/gki
if [ ! -f "$GKI_DIR/generate_gki_certificate.py" ]; then
  sudo mkdir -p "$GKI_DIR"
  echo "" | sudo tee "$GKI_DIR/__init__.py" > /dev/null
  printf 'def generate_gki_certificate(*a, **k): return None\n' \
    | sudo tee "$GKI_DIR/generate_gki_certificate.py" > /dev/null
fi

###############################################################################
# Read stock image header (GKI v3 offsets)
###############################################################################
STOCK_INFO=$(python3 - "$STOCK_IMG" << 'PYEOF'
import struct, sys
path = sys.argv[1]
with open(path, 'rb') as f:
    hdr = f.read(4096)
magic = hdr[0:8]
if magic != b'ANDROID!':
    print("ERROR: not a boot image"); sys.exit(1)
header_ver  = struct.unpack_from('<I', hdr, 40)[0]
os_ver_raw  = struct.unpack_from('<I', hdr, 16)[0]
maj  = (os_ver_raw >> 25) & 0x7f
minr = (os_ver_raw >> 18) & 0x7f
pat  = (os_ver_raw >> 11) & 0x7f
year = ((os_ver_raw >> 4) & 0x7f) + 2000
mon  = os_ver_raw & 0xf
print(f"{header_ver} {maj}.{minr}.{pat} {year}-{mon:02d}")
PYEOF
)

HEADER_VER=$(echo "$STOCK_INFO" | awk '{print $1}')
OS_VERSION=$(echo "$STOCK_INFO" | awk '{print $2}')
OS_PATCH=$(echo "$STOCK_INFO" | awk '{print $3}')

log "Header version : $HEADER_VER"
log "OS version     : $OS_VERSION"
log "OS patch       : $OS_PATCH"

###############################################################################
# Unpack stock boot.img — extract ramdisk (and dtb if present)
###############################################################################
WORK_DIR=$(mktemp -d /tmp/fogos-boot.XXXXX)
trap 'rm -rf "$WORK_DIR"' EXIT

log "Unpacking stock boot.img..."
unpack_bootimg --boot_img "$STOCK_IMG" --out "$WORK_DIR" 2>&1 || \
  fail "unpack_bootimg failed"

log "Extracted files:"
ls -lh "$WORK_DIR/"

# Ramdisk is required — fail loud if missing
[ -f "$WORK_DIR/ramdisk" ] || fail "ramdisk not found after unpack — stock image may be corrupt"
RAMDISK_SIZE=$(du -sh "$WORK_DIR/ramdisk" | cut -f1)
ok "Ramdisk : $RAMDISK_SIZE"

###############################################################################
# Repack with our kernel + stock ramdisk
###############################################################################
mkdir -p "$(dirname "$OUTPUT_IMG")"

log "Repacking boot.img (header v${HEADER_VER})..."

MKBOOT_ARGS=(
  --kernel  "$KERNEL_IMG"
  --ramdisk "$WORK_DIR/ramdisk"
  --output  "$OUTPUT_IMG"
)

# GKI v3/v4 args
if [ "$HEADER_VER" -ge 3 ]; then
  MKBOOT_ARGS+=(
    --header_version "$HEADER_VER"
    --os_version     "$OS_VERSION"
    --os_patch_level "$OS_PATCH"
  )
fi

# Add DTB if present (some v3 images include it)
if [ -f "$WORK_DIR/dtb" ]; then
  MKBOOT_ARGS+=(--dtb "$WORK_DIR/dtb")
  ok "DTB included"
fi

log "Running: mkbootimg ${MKBOOT_ARGS[*]}"
mkbootimg "${MKBOOT_ARGS[@]}"

###############################################################################
# Result
###############################################################################
[ -f "$OUTPUT_IMG" ] || fail "Output not created"

IN_SIZE=$(du -sh "$STOCK_IMG" | cut -f1)
OUT_SIZE=$(du -sh "$OUTPUT_IMG" | cut -f1)

echo ""
ok "Boot image created!"
ok "  Stock  : $IN_SIZE"
ok "  Output : $OUT_SIZE  →  $OUTPUT_IMG"
echo ""
echo -e "${CYAN}Flash via fastboot:${NC}"
echo "  adb reboot bootloader"
echo "  fastboot flash boot $OUTPUT_IMG"
echo "  fastboot reboot"
echo ""
echo -e "${CYAN}If AVB error:${NC}"
echo "  fastboot --disable-verity --disable-verification flash boot $OUTPUT_IMG"
echo ""
