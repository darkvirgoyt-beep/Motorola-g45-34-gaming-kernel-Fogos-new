#!/usr/bin/env bash
###############################################################################
# FogOS Extreme Gaming Kernel — Boot Image Creator
#
# Usage:
#   bash scripts/create_bootimg.sh <stock_boot.img> [kernel_image] [output.img]
#
# Example:
#   bash scripts/create_bootimg.sh boot_stock.img \
#       out/arch/arm64/boot/Image \
#       FogOS-Extreme-Gaming-boot.img
#
# This script:
#   1. Unpacks your stock boot.img (preserving all headers + ramdisk)
#   2. Replaces ONLY the kernel
#   3. Repacks a new boot.img identical in structure to your stock image
#
# Requirements:
#   pip3 install mkbootimg    (or: sudo apt install android-sdk-libsparse-utils)
#   OR download from: https://github.com/osm0sis/mkbootimg
###############################################################################

set -euo pipefail

STOCK_IMG="${1:-stock_boot.img}"
KERNEL_IMG="${2:-out/arch/arm64/boot/Image}"
OUTPUT_IMG="${3:-release/FogOS-Extreme-Gaming-boot.img}"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
log()    { echo -e "${CYAN}[bootimg] $1${NC}"; }
ok()     { echo -e "${GREEN}[bootimg] ✓ $1${NC}"; }
fail()   { echo -e "${RED}[bootimg] ✗ $1${NC}"; exit 1; }

###############################################################################
# CHECK TOOLS
###############################################################################
check_tools() {
  UNPACK_CMD=""
  MKBOOT_CMD=""

  # unpackbootimg / unpack_bootimg
  for cmd in unpackbootimg unpack_bootimg; do
    command -v "$cmd" &>/dev/null && { UNPACK_CMD="$cmd"; break; }
  done

  # mkbootimg
  for cmd in mkbootimg mkbootimg.py; do
    command -v "$cmd" &>/dev/null && { MKBOOT_CMD="$cmd"; break; }
  done

  if [ -z "$UNPACK_CMD" ] || [ -z "$MKBOOT_CMD" ]; then
    log "Installing mkbootimg tools..."
    pip3 install mkbootimg 2>/dev/null || true
    for cmd in unpackbootimg unpack_bootimg; do
      command -v "$cmd" &>/dev/null && { UNPACK_CMD="$cmd"; break; }
    done
    command -v mkbootimg &>/dev/null && MKBOOT_CMD="mkbootimg"
  fi

  [ -z "$UNPACK_CMD" ] && fail "unpackbootimg not found. Run: pip3 install mkbootimg"
  [ -z "$MKBOOT_CMD" ] && fail "mkbootimg not found. Run: pip3 install mkbootimg"

  ok "Tools: $UNPACK_CMD + $MKBOOT_CMD"
}

###############################################################################
# VALIDATE INPUTS
###############################################################################
[ ! -f "$STOCK_IMG" ]  && fail "Stock boot.img not found: $STOCK_IMG"
[ ! -f "$KERNEL_IMG" ] && fail "Kernel image not found: $KERNEL_IMG"

log "Stock image : $STOCK_IMG  ($(du -sh "$STOCK_IMG" | cut -f1))"
log "Kernel      : $KERNEL_IMG ($(du -sh "$KERNEL_IMG" | cut -f1))"
log "Output      : $OUTPUT_IMG"

check_tools
mkdir -p release

###############################################################################
# UNPACK STOCK BOOT.IMG
###############################################################################
WORK_DIR="$(mktemp -d /tmp/fogos-bootimg.XXXXX)"
trap "rm -rf $WORK_DIR" EXIT

log "Unpacking stock boot.img..."
cd "$WORK_DIR"

"$UNPACK_CMD" --input "$OLDPWD/$STOCK_IMG" --output . 2>&1 | tee /tmp/unpack.log || \
"$UNPACK_CMD" -i "$OLDPWD/$STOCK_IMG" -o . 2>&1 | tee /tmp/unpack.log

cd "$OLDPWD"

# Show what was extracted
log "Extracted files:"
ls -lh "$WORK_DIR/"

###############################################################################
# PARSE BOOT HEADER PARAMETERS
###############################################################################
log "Reading boot image parameters..."

# Try to parse from unpack output or info file
INFO_FILE="$(ls $WORK_DIR/*-header 2>/dev/null | head -1 || \
             ls $WORK_DIR/boot_params.txt 2>/dev/null | head -1 || echo "")"

# Parse page_size, kernel_offset, ramdisk_offset, etc.
get_param() {
  local key="$1"
  grep -i "$key" /tmp/unpack.log 2>/dev/null | grep -oP '(?<=: )[0-9xa-fA-F]+' | head -1 || \
  grep -i "$key" "${INFO_FILE:-/dev/null}" 2>/dev/null | grep -oP '(?<==)[0-9xa-fA-F]+' | head -1 || \
  echo ""
}

CMDLINE="$(grep -i "command line" /tmp/unpack.log 2>/dev/null | sed 's/.*command line: //' | head -1 || echo "")"
PAGESIZE="$(get_param 'page size')"
KERNEL_OFFSET="$(get_param 'kernel.*offset')"
RAMDISK_OFFSET="$(get_param 'ramdisk.*offset')"
SECOND_OFFSET="$(get_param 'second.*offset')"
TAGS_OFFSET="$(get_param 'tags.*offset')"
HEADER_VERSION="$(get_param 'header version')"
OS_VERSION="$(get_param 'os version')"
OS_PATCH_LEVEL="$(get_param 'os patch level')"

# Find ramdisk
RAMDISK_FILE="$(ls $WORK_DIR/*ramdisk* 2>/dev/null | head -1 || echo "")"
DTB_FILE="$(ls $WORK_DIR/*dtb* 2>/dev/null | head -1 || echo "")"

log "  Page size      : ${PAGESIZE:-auto}"
log "  Kernel offset  : ${KERNEL_OFFSET:-auto}"
log "  Ramdisk offset : ${RAMDISK_OFFSET:-auto}"
log "  Header version : ${HEADER_VERSION:-auto}"
log "  Cmdline        : ${CMDLINE:-preserved}"
log "  Ramdisk file   : ${RAMDISK_FILE:-none}"
log "  DTB file       : ${DTB_FILE:-none}"

###############################################################################
# REPACK WITH NEW KERNEL
###############################################################################
log "Repacking boot.img with FogOS kernel..."

# Build mkbootimg arguments
MKBOOT_ARGS=(
  --kernel "$KERNEL_IMG"
  --output "$OUTPUT_IMG"
)

[ -n "$RAMDISK_FILE" ] && MKBOOT_ARGS+=(--ramdisk "$RAMDISK_FILE")
[ -n "$DTB_FILE" ]     && MKBOOT_ARGS+=(--dtb "$DTB_FILE")
[ -n "$CMDLINE" ]      && MKBOOT_ARGS+=(--cmdline "$CMDLINE")
[ -n "$PAGESIZE" ]     && MKBOOT_ARGS+=(--pagesize "$PAGESIZE")
[ -n "$KERNEL_OFFSET" ]  && MKBOOT_ARGS+=(--kernel_offset "$KERNEL_OFFSET")
[ -n "$RAMDISK_OFFSET" ] && MKBOOT_ARGS+=(--ramdisk_offset "$RAMDISK_OFFSET")
[ -n "$SECOND_OFFSET" ]  && MKBOOT_ARGS+=(--second_offset "$SECOND_OFFSET")
[ -n "$TAGS_OFFSET" ]    && MKBOOT_ARGS+=(--tags_offset "$TAGS_OFFSET")
[ -n "$HEADER_VERSION" ] && MKBOOT_ARGS+=(--header_version "$HEADER_VERSION")
[ -n "$OS_VERSION" ]     && MKBOOT_ARGS+=(--os_version "$OS_VERSION")
[ -n "$OS_PATCH_LEVEL" ] && MKBOOT_ARGS+=(--os_patch_level "$OS_PATCH_LEVEL")

"$MKBOOT_CMD" "${MKBOOT_ARGS[@]}"

###############################################################################
# RESULT
###############################################################################
if [ -f "$OUTPUT_IMG" ]; then
  SIZE_ORIG="$(du -sh "$STOCK_IMG" | cut -f1)"
  SIZE_NEW="$(du -sh "$OUTPUT_IMG" | cut -f1)"
  ok "Boot image created successfully!"
  ok "  Stock size : $SIZE_ORIG"
  ok "  New size   : $SIZE_NEW"
  ok "  Output     : $OUTPUT_IMG"
  echo ""
  echo -e "${CYAN}Flash command:${NC}"
  echo "  adb reboot bootloader"
  echo "  fastboot flash boot $OUTPUT_IMG"
  echo "  fastboot reboot"
else
  fail "Boot image creation failed — output not found."
fi
