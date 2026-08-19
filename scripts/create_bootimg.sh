#!/usr/bin/env bash
###############################################################################
# FogOS Extreme Gaming Kernel — Boot Image Creator
#
# Developer : Prince · VirgoYT707
# Device    : Motorola G45 / G34 (SM6375 — Holi Platform)
#
# Usage:
#   bash scripts/create_bootimg.sh <stock_boot.img> <kernel_image> <output.img>
#
# This script:
#   1. Unpacks the stock boot.img (preserving header fields + ramdisk)
#   2. Replaces ONLY the kernel with the freshly built FogOS kernel
#   3. Repacks a new boot.img identical in structure to the stock image
#
# Supports boot header v0, v1, v2, v3 (GKI) — Moto G45 (Holi) uses v3.
#
# Unpacking/repacking uses the AOSP mkbootimg/unpack_bootimg tools vendored in
# scripts/vendor/mkbootimg/ instead of the distro `mkbootimg` apt package.
# The Ubuntu apt package's unpack_bootimg predates boot header v3 (GKI): it
# reads a "page_size" field that v3 images don't have, gets 0, and crashes
# with "ZeroDivisionError" in get_number_of_pages(). Vendoring the current
# AOSP scripts (which hardcode the v3+ page size instead of trusting a
# nonexistent field) fixes that without touching any kernel config.
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNPACK_PY="$SCRIPT_DIR/vendor/mkbootimg/unpack_bootimg.py"
MKBOOT_PY="$SCRIPT_DIR/vendor/mkbootimg/mkbootimg.py"

STOCK_IMG="${1:-stock/boot.img}"
KERNEL_IMG="${2:-out/arch/arm64/boot/Image}"
OUTPUT_IMG="${3:-release/FogOS-Extreme-Gaming-boot.img}"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${CYAN}[bootimg] $*${NC}"; }
ok()   { echo -e "${GREEN}[bootimg] ✓ $*${NC}"; }
fail() { echo -e "${RED}[bootimg] ✗ $*${NC}"; exit 1; }

[ -f "$STOCK_IMG" ]  || fail "Stock boot.img not found: $STOCK_IMG"
[ -f "$KERNEL_IMG" ] || fail "Kernel image not found: $KERNEL_IMG"
[ -f "$UNPACK_PY" ]  || fail "Vendored unpack_bootimg.py missing: $UNPACK_PY"
[ -f "$MKBOOT_PY" ]  || fail "Vendored mkbootimg.py missing: $MKBOOT_PY"

log "Stock  : $STOCK_IMG  ($(du -sh "$STOCK_IMG"  | cut -f1))"
log "Kernel : $KERNEL_IMG ($(du -sh "$KERNEL_IMG" | cut -f1))"
log "Output : $OUTPUT_IMG"

WORK_DIR="$(mktemp -d /tmp/fogos-boot.XXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

###############################################################################
# Unpack — vendored AOSP unpack_bootimg, GKI v3/v4-safe
###############################################################################
log "Unpacking stock boot.img..."
FORMAT_OUT="$WORK_DIR/mkbootimg_args.txt"
python3 "$UNPACK_PY" --boot_img "$STOCK_IMG" --out "$WORK_DIR" \
    --format mkbootimg > "$FORMAT_OUT" \
  || fail "unpack_bootimg failed — is the stock image a valid Android boot image?"

log "Extracted files:"
ls -lh "$WORK_DIR/"

###############################################################################
# Repack — substitute only the kernel; every other stock field (cmdline,
# header_version, os_version, os_patch_level, ramdisk, dtb, ...) is carried
# over unchanged from the --format mkbootimg output above.
###############################################################################
mkdir -p "$(dirname "$OUTPUT_IMG")"
log "Repacking boot.img (stock header + our kernel)..."

python3 - "$FORMAT_OUT" "$KERNEL_IMG" "$OUTPUT_IMG" "$WORK_DIR" "$MKBOOT_PY" <<'PYEOF'
import shlex, subprocess, sys, os

format_out, kernel_img, output_img, work_dir, mkboot_py = sys.argv[1:6]

# Flags whose value is a file path that may need to be resolved relative to
# the unpack output directory.
file_flags = {'--ramdisk', '--vendor_ramdisk', '--dtb', '--second', '--recovery_dtbo'}

with open(format_out) as fh:
    tokens = shlex.split(fh.read().strip())

args = [sys.executable, mkboot_py]
i = 0
while i < len(tokens):
    tok = tokens[i]
    i += 1
    val = tokens[i] if i < len(tokens) else ''

    if tok == '--output':
        i += 1  # discard the embedded output path; we set our own below

    elif tok == '--kernel':
        # Substitute our freshly built kernel image.
        args += ['--kernel', kernel_img]
        i += 1  # skip the stock kernel path from the tokens

    elif tok in file_flags:
        abs_val = val if os.path.isabs(val) else os.path.join(work_dir, val)
        if os.path.isfile(abs_val):
            args += [tok, abs_val]
        elif os.path.isfile(val):
            args += [tok, val]
        else:
            print(f'[bootimg] Skipping {tok}: file not found ({abs_val})', file=sys.stderr)
        i += 1

    elif tok.startswith('--'):
        # Scalar flags (--header_version, --os_version, --cmdline, ...)
        if val and not val.startswith('--'):
            args += [tok, val]
            i += 1
        # else: boolean flag with no value (not emitted by unpack_bootimg today)

    # else: bare token with no leading '--', ignore

args += ['--output', output_img]

print('[bootimg] Running:', ' '.join(shlex.quote(a) for a in args))
sys.exit(subprocess.call(args))
PYEOF

###############################################################################
# Result
###############################################################################
[ -f "$OUTPUT_IMG" ] || fail "Output file not created — mkbootimg may have failed silently"

###############################################################################
# AVB2.0 Block — Minimal vbmeta with allow_verification_disabled
#
# Motorola / Holi boot images have a 40+ MB AVB2.0 hash tree + vbmeta
# descriptor appended after the ramdisk.  The stock hash tree is computed over
# the STOCK kernel — copying it verbatim after replacing the kernel makes the
# hashes INVALID, and the bootloader rejects the image with "Preflash
# validation failed".
#
# Fix: Build a MINIMAL AVB block with a vbmeta descriptor that has
# allow_verification_disabled (flags bit 0) set. This tells the bootloader
# "verification can be skipped" — no hash tree needed, no size bloat.
# The image stays small and flashes cleanly with --disable-verification.
###############################################################################
log "Creating minimal AVB block (allow_verification_disabled)..."
python3 - "$STOCK_IMG" "$OUTPUT_IMG" <<'AVBEOF'
import struct, sys, hashlib

STOCK_IMG  = sys.argv[1]
OUTPUT_IMG = sys.argv[2]

AVB_FOOTER_MAGIC  = b'AVBf'
AVB_FOOTER_SIZE   = 64
AVB_DESCRIPTOR_MAGIC = b'AVB0'
# Big-endian: 4s magic + I vmajor + I vminor + Q orig_size + Q vbmeta_off + Q vbmeta_size + 28s reserved
AVB_FOOTER_FMT = '>4sIIQQQ28s'

with open(STOCK_IMG, 'rb') as f:
    stock = f.read()

footer_raw = stock[-AVB_FOOTER_SIZE:]
if footer_raw[:4] != AVB_FOOTER_MAGIC:
    print('[bootimg] No AVBf footer in stock image — skipping AVB, flashing raw image')
    sys.exit(0)

stock_vmajor, stock_vminor, stock_orig_size, stock_vbmeta_off, stock_vbmeta_size, stock_reserved = \
    struct.unpack(AVB_FOOTER_FMT, footer_raw)[1:7]

print(f'[bootimg] Stock AVB version: {stock_vmajor}.{stock_vminor}')
print(f'[bootimg] Stock vbmeta descriptor size: {stock_vbmeta_size} bytes')

with open(OUTPUT_IMG, 'rb') as f:
    new_image = f.read()

new_image_size = len(new_image)

###############################################################################
# Build a minimal AVB vbmeta header (Android Verified Boot 2.0)
#
# Layout (all big-endian):
#   AVB magic: "AVB0" (4 bytes)
#   Required header size: 256 bytes (minimum)
#   Algorithm: NONE (0) — no signature, allows verification to be disabled
#   Hash size: 0
#   Salt size: 0
#   Flags: 0x01 (AVB_VBMETA_IMAGE_FLAGS_VERIFICATION_DISABLED)
#   Rollback index: 0
#   Reserved fields: 0
#   Descriptors: none (minimal)
#   Auxiliary data: empty
###############################################################################

# AVB vbmeta header fields (from external/avb/libavb/avb_vbmeta_image.h):
#   uint8_t  magic[4];              // 'AVB0'
#   uint32_t required_header_size;  // 256
#   uint32_t algorithm;             // NONE = 0
#   uint64_t hash_offset;           // 0 (no hash)
#   uint64_t hash_size;             // 0
#   uint64_t signature_offset;      // 0 (no signature)
#   uint64_t signature_size;        // 0
#   uint64_t auxiliary_data_offset; // 256 (right after header)
#   uint64_t auxiliary_data_size;   // 0 (no descriptors)
#   uint32_t header_attr;           // flags (bit 0 = VERIFICATION_DISABLED)
#   uint64_t rollback_index;        // 0
#   uint8_t  reserved[64];
# Total struct = 136 bytes, padded to required_header_size (256)

# AvbVBMetaImageHeader is a fixed 256-byte big-endian structure. The old
# shortened record was merely padded to 256 B, which is not a valid libavb
# header. This complete header uses AVB_ALGORITHM_TYPE_NONE with no descriptor,
# auxiliary, or authentication data and explicitly disables verification.
# After `algorithm` there are 11 uint64_t values: the ten offset/size fields
# plus rollback_index. The packed result must be exactly 256 bytes.
header_format = '>4sIIQQI' + ('Q' * 11) + 'II48s80s'
avb_header = struct.pack(
    header_format,
    b'AVB0',
    1, 0,                    # required_libavb_version_major/minor
    0, 0,                    # authentication_data_block_size, auxiliary_data_block_size
    0,                       # AVB_ALGORITHM_TYPE_NONE
    *([0] * 11),             # no hash/signature/key/metadata/descriptors; rollback index = 0
    1,                       # AVB_VBMETA_IMAGE_FLAGS_VERIFICATION_DISABLED
    0,                       # rollback_index_location
    b'\x00' * 48,            # release_string
    b'\x00' * 80,            # reserved
)
assert len(avb_header) == 256, f"AVB header is {len(avb_header)} bytes, expected 256"

# Minimal but complete vbmeta image: valid header, no auxiliary data.
vbmeta_image = avb_header

print(f'[bootimg] Minimal vbmeta created: {len(vbmeta_image)} bytes (was {stock_vbmeta_size} + 41 MB hash tree)')

# Build AVBf footer pointing at the minimal vbmeta
new_footer = struct.pack(AVB_FOOTER_FMT,
    AVB_FOOTER_MAGIC,
    stock_vmajor,       # keep stock AVB version
    stock_vminor,
    new_image_size,     # original_image_size = end of boot data in new image
    new_image_size,     # vbmeta_offset = right after boot data
    len(vbmeta_image),  # vbmeta_size = our minimal descriptor size
    stock_reserved,     # reserved bytes unchanged
)

# Write: boot data + minimal vbmeta + AVBf footer
with open(OUTPUT_IMG, 'wb') as f:
    f.write(new_image)
    f.write(vbmeta_image)
    f.write(new_footer)

final_size = new_image_size + len(vbmeta_image) + AVB_FOOTER_SIZE
saved_mb = ((new_image_size + 41 * 1024 * 1024 + 64) - final_size) / 1024 / 1024
print(f'[bootimg] ✓ Minimal AVB block appended: {len(vbmeta_image)} B descriptor + 64 B footer')
print(f'[bootimg] ✓ New image size: {final_size/1024/1024:.1f} MB (saved ~{saved_mb:.0f} MB vs stock AVB block)')
print(f'[bootimg] ✓ Flags: VERIFICATION_DISABLED — flash with --disable-verification')
AVBEOF

IN_SIZE=$(du -sh "$STOCK_IMG"  | cut -f1)
OUT_SIZE=$(du -sh "$OUTPUT_IMG" | cut -f1)
OUT_BYTES=$(wc -c < "$OUTPUT_IMG")

###############################################################################
# Hard size-budget gate
#
# The Moto G45/G34 (Holi) boot_a/boot_b partitions are 100,663,296 bytes
# (96 MiB) -- fastboot's preflash validation rejects anything bigger. A build
# has shipped an oversized image before (compiled fine, only failed at flash
# time on the actual device), so refuse to hand back an image that cannot
# fit instead of only discovering it at flash time.
###############################################################################
BOOT_PARTITION_SIZE_BYTES="${BOOT_PARTITION_SIZE_BYTES:-100663296}"  # 96 MiB, device partition table
# The trimmed release Image leaves about 1.54 MiB below the exact partition
# limit. Keep a 1 MiB default margin; callers can raise it with
# SIZE_MARGIN_BYTES when using a stricter release policy.
SIZE_MARGIN_BYTES="${SIZE_MARGIN_BYTES:-1048576}"                    # 1 MiB safety margin
BUDGET_BYTES=$((BOOT_PARTITION_SIZE_BYTES - SIZE_MARGIN_BYTES))

if [ "$OUT_BYTES" -gt "$BUDGET_BYTES" ]; then
  OVER_BYTES=$((OUT_BYTES - BUDGET_BYTES))
  OVER_MB=$(( (OVER_BYTES + 524288) / 1048576 ))
  echo ""
  echo -e "${RED}[bootimg] ✗ Boot image exceeds the size budget -- refusing to ship it.${NC}"
  echo -e "${RED}[bootimg]   Output          : $OUT_BYTES bytes ($OUT_SIZE)${NC}"
  echo -e "${RED}[bootimg]   Partition size  : $BOOT_PARTITION_SIZE_BYTES bytes (96 MiB)${NC}"
  echo -e "${RED}[bootimg]   Budget (-margin): $BUDGET_BYTES bytes${NC}"
  echo -e "${RED}[bootimg]   Over by         : $OVER_BYTES bytes (~${OVER_MB} MiB)${NC}"
  echo -e "${RED}[bootimg] This would fail fastboot's preflash validation on-device.${NC}"
  echo -e "${RED}[bootimg] Shrink the compiled kernel (CC_OPTIMIZE_FOR_SIZE, drop debug-only${NC}"
  echo -e "${RED}[bootimg] Kconfig options) -- do not compress it instead: this bootloader${NC}"
  echo -e "${RED}[bootimg] cannot decompress a compressed Image and will bootloop.${NC}"
  echo ""
  exit 1
fi

echo ""
ok "Boot image created successfully!"
ok "  Stock  : $IN_SIZE"
ok "  Output : $OUT_SIZE  →  $OUTPUT_IMG  ($OUT_BYTES / $BUDGET_BYTES bytes budget)"
echo ""
echo -e "${CYAN}Flash via fastboot:${NC}"
echo "  adb reboot bootloader"
echo "  fastboot flash boot $OUTPUT_IMG"
echo "  fastboot reboot"
echo ""
echo -e "${CYAN}If AVB / verity error:${NC}"
echo "  fastboot --disable-verity --disable-verification flash boot $OUTPUT_IMG"
echo ""
