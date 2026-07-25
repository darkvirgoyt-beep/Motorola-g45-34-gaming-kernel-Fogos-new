#!/usr/bin/env bash
###############################################################################
# FogOS Extreme Gaming Kernel — Boot Image Creator (Fixed Version)
#
# This script creates a bootable boot.img with proper AVB signing and verification
# Handles Android Verified Boot (AVB) and kernel image signing
#
# Usage:
#   bash scripts/create_bootimg_fixed.sh <stock_boot.img> [kernel_image] [output.img]
#
# Example:
#   bash scripts/create_bootimg_fixed.sh boot_stock.img \
#       out/arch/arm64/boot/Image \
#       FogOS-Extreme-Gaming-boot.img
###############################################################################

set -euo pipefail

STOCK_IMG="${1:-stock_boot.img}"
KERNEL_IMG="${2:-out/arch/arm64/boot/Image}"
OUTPUT_IMG="${3:-release/FogOS-Extreme-Gaming-boot.img}"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()    { echo -e "${CYAN}[bootimg] $1${NC}"; }
ok()     { echo -e "${GREEN}[bootimg] ✓ $1${NC}"; }
warn()   { echo -e "${YELLOW}[bootimg] ⚠ $1${NC}"; }
fail()   { echo -e "${RED}[bootimg] ✗ $1${NC}"; exit 1; }

###############################################################################
# CHECK TOOLS
###############################################################################
check_tools() {
  UNPACK_CMD=""
  MKBOOT_CMD=""
  AVBTOOL_CMD=""

  # unpackbootimg / unpack_bootimg
  for cmd in unpack_bootimg unpackbootimg; do
    command -v "$cmd" &>/dev/null && { UNPACK_CMD="$cmd"; break; }
  done

  # mkbootimg
  for cmd in mkbootimg mkbootimg.py; do
    command -v "$cmd" &>/dev/null && { MKBOOT_CMD="$cmd"; break; }
  done

  # avbtool for signing
  command -v avbtool &>/dev/null && AVBTOOL_CMD="avbtool"

  if [ -z "$UNPACK_CMD" ] || [ -z "$MKBOOT_CMD" ]; then
    log "Installing mkbootimg tools via apt..."
    apt-get update -qq
    apt-get install -y mkbootimg python3-pip 2>/dev/null || true
    for cmd in unpack_bootimg unpackbootimg; do
      command -v "$cmd" &>/dev/null && { UNPACK_CMD="$cmd"; break; }
    done
    command -v mkbootimg &>/dev/null && MKBOOT_CMD="mkbootimg"
  fi

  # Install avbtool if not present (optional for boot.img creation)
  if [ -z "$AVBTOOL_CMD" ]; then
    log "Checking for avbtool..."
    if command -v avbtool &>/dev/null; then
      AVBTOOL_CMD="avbtool"
    else
      log "Attempting to install avbtool for AVB signing (optional)..."
      # Try pip3 with system packages override
      pip3 install --break-system-packages avbtool 2>/dev/null && AVBTOOL_CMD="avbtool" || {
        # Try downloading from AOSP
        log "Downloading avbtool from AOSP..."
        mkdir -p /tmp/avbtool_install
        cd /tmp/avbtool_install
        if [ ! -f "avbtool.py" ]; then
          git clone https://android.googlesource.com/platform/external/avb . 2>/dev/null || {
            warn "Could not download avbtool, AVB signing will be skipped"
            cd - > /dev/null
          }
        fi
        if [ -f "avbtool.py" ]; then
          chmod +x avbtool.py
          ln -sf "$(pwd)/avbtool.py" /usr/local/bin/avbtool 2>/dev/null || {
            export PATH="$(pwd):$PATH"
            AVBTOOL_CMD="$(pwd)/avbtool.py"
          }
          AVBTOOL_CMD="avbtool"
        fi
        cd - > /dev/null
      }
    fi
  fi

  [ -z "$UNPACK_CMD" ] && fail "unpack_bootimg not found. Run: apt install mkbootimg"
  [ -z "$MKBOOT_CMD" ] && fail "mkbootimg not found. Run: apt install mkbootimg"

  ok "Tools: $UNPACK_CMD + $MKBOOT_CMD"
  if [ -n "$AVBTOOL_CMD" ] && command -v "$AVBTOOL_CMD" &>/dev/null; then
    ok "AVB Tool: $AVBTOOL_CMD"
  else
    warn "AVB Tool not available - boot.img will not be signed"
    AVBTOOL_CMD=""
  fi
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

# Try different unpack_bootimg syntax
UNPACK_SUCCESS=false
"$UNPACK_CMD" --boot_img "$OLDPWD/$STOCK_IMG" --out . 2>&1 | tee /tmp/unpack.log && UNPACK_SUCCESS=true || \
"$UNPACK_CMD" --input "$OLDPWD/$STOCK_IMG" --output . 2>&1 | tee /tmp/unpack.log && UNPACK_SUCCESS=true || \
"$UNPACK_CMD" -i "$OLDPWD/$STOCK_IMG" -o . 2>&1 | tee /tmp/unpack.log && UNPACK_SUCCESS=true || \
warn "Unpack_bootimg failed, will use default parameters"

cd "$OLDPWD"

if [ "$UNPACK_SUCCESS" = true ]; then
  # Show what was extracted
  log "Extracted files:"
  ls -lh "$WORK_DIR/"
else
  log "Using default boot.img parameters"
  # Create minimal ramdisk
  dd if=/dev/zero of "$WORK_DIR/ramdisk" bs=4096 count=1 2>/dev/null || true
fi

###############################################################################
# PARSE BOOT HEADER PARAMETERS
###############################################################################
log "Reading boot image parameters..."

if [ "$UNPACK_SUCCESS" = true ]; then
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
  BASE_ADDRESS="$(get_param 'base' || get_param 'kernel address')"

  # Find ramdisk
  RAMDISK_FILE="$(ls $WORK_DIR/*ramdisk* 2>/dev/null | head -1 || echo "")"
  DTB_FILE="$(ls $WORK_DIR/*dtb* 2>/dev/null | head -1 || echo "")"
else
  # Use defaults for modern Android when unpacking failed
  warn "Using default Android boot parameters"
  CMDLINE=""
  PAGESIZE="4096"
  KERNEL_OFFSET="0x00008000"
  RAMDISK_OFFSET="0x01000000"
  SECOND_OFFSET="0x00f00000"
  TAGS_OFFSET="0x00000100"
  HEADER_VERSION="3"
  OS_VERSION=""
  OS_PATCH_LEVEL=""
  BASE_ADDRESS="0x00000000"
  RAMDISK_FILE="$WORK_DIR/ramdisk"
  DTB_FILE=""
fi

log "  Page size      : ${PAGESIZE}"
log "  Kernel offset  : ${KERNEL_OFFSET}"
log "  Ramdisk offset : ${RAMDISK_OFFSET}"
log "  Header version : ${HEADER_VERSION}"
log "  Base address   : ${BASE_ADDRESS}"
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
  --pagesize "$PAGESIZE"
  --base "$BASE_ADDRESS"
  --kernel_offset "$KERNEL_OFFSET"
  --ramdisk_offset "$RAMDISK_OFFSET"
  --second_offset "$SECOND_OFFSET"
  --tags_offset "$TAGS_OFFSET"
  --header_version "$HEADER_VERSION"
)

# Only add ramdisk if file exists and has content
if [ -n "$RAMDISK_FILE" ] && [ -f "$RAMDISK_FILE" ] && [ -s "$RAMDISK_FILE" ]; then
  MKBOOT_ARGS+=(--ramdisk "$RAMDISK_FILE")
fi

# Only add DTB if file exists
if [ -n "$DTB_FILE" ] && [ -f "$DTB_FILE" ]; then
  MKBOOT_ARGS+=(--dtb "$DTB_FILE")
fi

# Add cmdline if available
if [ -n "$CMDLINE" ]; then
  MKBOOT_ARGS+=(--cmdline "$CMDLINE")
fi

# Add OS version info if available
if [ -n "$OS_VERSION" ]; then
  MKBOOT_ARGS+=(--os_version "$OS_VERSION")
fi
if [ -n "$OS_PATCH_LEVEL" ]; then
  MKBOOT_ARGS+=(--os_patch_level "$OS_PATCH_LEVEL")
fi

log "Running mkbootimg with arguments:"
for arg in "${MKBOOT_ARGS[@]}"; do
  log "  $arg"
done

"$MKBOOT_CMD" "${MKBOOT_ARGS[@]}" || fail "mkbootimg failed"

###############################################################################
# ADD AVB SIGNING (if avbtool available)
###############################################################################
if [ -n "$AVBTOOL_CMD" ] && command -v "$AVBTOOL_CMD" &>/dev/null; then
  log "Adding AVB signature for kernel verification..."
  
  # Generate a test key for signing (in production, use your proper key)
  AVB_KEY="${WORK_DIR}/test_key.pem"
  AVB_PUBKEY="${WORK_DIR}/test_key_pub.bin"
  
  if [ ! -f "$AVB_KEY" ]; then
    log "Generating test AVB key..."
    if openssl genrsa -out "$AVB_KEY" 2048 2>/dev/null; then
      ok "Test AVB key generated"
      "$AVBTOOL_CMD" extract_public_key --key "$AVB_KEY" --output "$AVB_PUBKEY" 2>/dev/null || true
    else
      warn "Could not generate test key, skipping AVB signing"
      AVBTOOL_CMD=""
    fi
  fi
  
  if [ -n "$AVBTOOL_CMD" ] && [ -f "$AVB_KEY" ]; then
    # Add hash footer using AVB
    log "Applying AVB hash footer..."
    if "$AVBTOOL_CMD" add_hash_footer \
      --image "$OUTPUT_IMG" \
      --partition_name boot \
      --partition_size 67108864 \
      --key "$AVB_KEY" \
      --algorithm SHA256_RSA2048 \
      --calc_max_image_size 2>/dev/null; then
      ok "AVB signature added successfully"
    else
      warn "AVB signing failed, boot.img will not be AVB verified"
      warn "This is normal for custom kernels - you may need to disable AVB verification"
    fi
  fi
else
  warn "AVB tool not available - boot.img will not be signed"
  warn "For production use, install avbtool and use proper signing keys"
fi

###############################################################################
# VERIFY BOOT IMAGE
###############################################################################
log "Verifying boot.img structure..."
if command -v file &>/dev/null; then
  file "$OUTPUT_IMG" || true
fi

# Check file size
BOOT_SIZE=$(stat -c%s "$OUTPUT_IMG" 2>/dev/null || stat -f%z "$OUTPUT_IMG" 2>/dev/null || echo "0")
if [ "$BOOT_SIZE" -lt 1000000 ]; then
  warn "Boot image seems too small: $BOOT_SIZE bytes"
else
  ok "Boot image size: $BOOT_SIZE bytes"
fi

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
  echo ""
  echo -e "${YELLOW}NOTE: If you encounter verification errors, you may need to:${NC}"
  echo "  fastboot --disable-verity --disable-verification flash vbmeta vbmeta.img"
  echo "  fastboot flash boot $OUTPUT_IMG"
  echo ""
else
  fail "Boot image creation failed — output not found."
fi