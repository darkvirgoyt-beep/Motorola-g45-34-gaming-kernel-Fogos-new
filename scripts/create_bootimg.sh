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
# Ensure tools are available
###############################################################################
if ! command -v unpack_bootimg &>/dev/null || ! command -v mkbootimg &>/dev/null; then
  log "Installing mkbootimg tools..."
  sudo apt-get install -y mkbootimg
fi

# Fix Ubuntu 24.04 broken 'gki' import in Python mkbootimg
python3 - <<'PYFIX'
import site, pathlib
gki = pathlib.Path(site.getsitepackages()[0]) / "gki"
gki.mkdir(exist_ok=True)
init = gki / "__init__.py"
cert = gki / "generate_gki_certificate.py"
if not init.exists():   init.write_text("")
if not cert.exists():   cert.write_text("def generate_gki_certificate(*a, **k): return None\n")
PYFIX

###############################################################################
# Parse stock boot image header
###############################################################################
log "Parsing stock boot image header..."

HEADER_VER=$(python3 - "$STOCK_IMG" <<'PYEOF'
import struct, sys
path = sys.argv[1]
with open(path, 'rb') as f:
    hdr = f.read(4096)
if hdr[0:8] != b'ANDROID!':
    print("0"); sys.exit(0)
print(struct.unpack_from('<I', hdr, 40)[0])
PYEOF
)

# Validate — treat anything non-numeric as 0
if ! [[ "$HEADER_VER" =~ ^[0-9]+$ ]]; then
  log "Warning: could not read header version, defaulting to 0"
  HEADER_VER=0
fi
log "Header version : $HEADER_VER"

# Parse OS version/patch only if header_ver >= 3 and fields are non-zero
OS_VERSION=""
OS_PATCH=""
if [ "$HEADER_VER" -ge 3 ]; then
  OS_RAW=$(python3 - "$STOCK_IMG" <<'PYEOF'
import struct, sys
path = sys.argv[1]
with open(path, 'rb') as f:
    hdr = f.read(4096)
v = struct.unpack_from('<I', hdr, 16)[0]
maj  = (v >> 25) & 0x7f
minr = (v >> 18) & 0x7f
pat  = (v >> 11) & 0x7f
year = ((v >> 4) & 0x7f) + 2000
mon  = v & 0xf
# Only print if values are non-zero/valid
ver  = f"{maj}.{minr}.{pat}" if (maj or minr or pat) else ""
# month must be 1-12 and year must be >= 2018 to be valid
patch = f"{year}-{mon:02d}" if (1 <= mon <= 12 and year >= 2018) else ""
print(f"{ver}|{patch}")
PYEOF
  )
  OS_VERSION=$(echo "$OS_RAW" | cut -d'|' -f1)
  OS_PATCH=$(echo "$OS_RAW"   | cut -d'|' -f2)
  [ -n "$OS_VERSION" ] && log "OS version     : $OS_VERSION" || log "OS version     : (not set — skipping)"
  [ -n "$OS_PATCH"   ] && log "OS patch       : $OS_PATCH"   || log "OS patch       : (not set — skipping)"
fi

###############################################################################
# Unpack stock boot image to extract ramdisk
###############################################################################
WORK_DIR=$(mktemp -d /tmp/fogos-boot.XXXXX)
trap 'rm -rf "$WORK_DIR"' EXIT

log "Unpacking stock boot.img..."
unpack_bootimg --boot_img "$STOCK_IMG" --out "$WORK_DIR" 2>&1 || \
  fail "unpack_bootimg failed — is the stock image a valid Android boot image?"

log "Extracted files:"
ls -lh "$WORK_DIR/"

# Find ramdisk — handle naming differences across unpack_bootimg versions
RAMDISK=""
for name in ramdisk ramdisk.cpio ramdisk.img; do
  if [ -f "$WORK_DIR/$name" ]; then
    RAMDISK="$WORK_DIR/$name"
    break
  fi
done

if [ -z "$RAMDISK" ]; then
  echo ""
  echo "❌ No ramdisk found. Contents of work dir:"
  ls -la "$WORK_DIR/"
  fail "ramdisk not extracted — stock image may be corrupt or unsupported format"
fi
ok "Ramdisk : $(du -sh "$RAMDISK" | cut -f1)"

###############################################################################
# Repack with our kernel + stock ramdisk
###############################################################################
mkdir -p "$(dirname "$OUTPUT_IMG")"

log "Repacking boot.img (header v${HEADER_VER})..."

MKBOOT_ARGS=(
  --kernel  "$KERNEL_IMG"
  --ramdisk "$RAMDISK"
  --output  "$OUTPUT_IMG"
)

# GKI v3/v4: add header_version; only add os_version/os_patch if valid
if [ "$HEADER_VER" -ge 3 ]; then
  MKBOOT_ARGS+=(--header_version "$HEADER_VER")
  [ -n "$OS_VERSION" ] && MKBOOT_ARGS+=(--os_version     "$OS_VERSION")
  [ -n "$OS_PATCH"   ] && MKBOOT_ARGS+=(--os_patch_level "$OS_PATCH")
fi

# Include DTB if present (some v3 images carry it)
if [ -f "$WORK_DIR/dtb" ]; then
  MKBOOT_ARGS+=(--dtb "$WORK_DIR/dtb")
  ok "DTB included"
fi

log "Running: mkbootimg ${MKBOOT_ARGS[*]}"
mkbootimg "${MKBOOT_ARGS[@]}"

###############################################################################
# Result
###############################################################################
[ -f "$OUTPUT_IMG" ] || fail "Output file not created — mkbootimg may have failed silently"

IN_SIZE=$(du -sh "$STOCK_IMG"  | cut -f1)
OUT_SIZE=$(du -sh "$OUTPUT_IMG" | cut -f1)

echo ""
ok "Boot image created successfully!"
ok "  Stock  : $IN_SIZE"
ok "  Output : $OUT_SIZE  →  $OUTPUT_IMG"
echo ""
echo -e "${CYAN}Flash via fastboot:${NC}"
echo "  adb reboot bootloader"
echo "  fastboot flash boot $OUTPUT_IMG"
echo "  fastboot reboot"
echo ""
echo -e "${CYAN}If AVB / verity error:${NC}"
echo "  fastboot --disable-verity --disable-verification flash boot $OUTPUT_IMG"
echo ""
