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
# Preserve AVB2.0 block from stock image
#
# Motorola / Holi boot images have a 40+ MB AVB2.0 hash tree + vbmeta
# descriptor appended after the ramdisk.  mkbootimg.py does not reconstruct
# this block — so without this step the output image is ~75 MB while stock is
# 96 MB, and some bootloaders refuse to load the truncated image even with
# --disable-verity (they still look for the AVBf footer to locate the hash
# tree).  We copy the entire AVB block verbatim from the stock image and
# update the footer fields to point at the correct offset in the new image.
###############################################################################
log "Preserving AVB block from stock image..."
python3 - "$STOCK_IMG" "$OUTPUT_IMG" <<'AVBEOF'
import struct, sys

STOCK_IMG  = sys.argv[1]
OUTPUT_IMG = sys.argv[2]

AVB_FOOTER_MAGIC  = b'AVBf'
AVB_FOOTER_SIZE   = 64
# Big-endian: 4s magic + I vmajor + I vminor + Q orig_size + Q vbmeta_off + Q vbmeta_size + 28s reserved
AVB_FOOTER_FMT = '>4sIIQQQ28s'

with open(STOCK_IMG, 'rb') as f:
    stock = f.read()

footer_raw = stock[-AVB_FOOTER_SIZE:]
if footer_raw[:4] != AVB_FOOTER_MAGIC:
    print('[bootimg] No AVBf footer in stock image — skipping AVB preservation')
    sys.exit(0)

magic, vmajor, vminor, orig_size, vbmeta_off, vbmeta_size, reserved = \
    struct.unpack(AVB_FOOTER_FMT, footer_raw)

print(f'[bootimg] Stock AVB  : vbmeta_offset={vbmeta_off:,}  vbmeta_size={vbmeta_size:,}  orig_image_size={orig_size:,}')

# The vbmeta descriptor lives at stock[vbmeta_off : vbmeta_off + vbmeta_size]
# followed by the 64-byte footer at the very end.
# The AVB block in the partition is:
#   [vbmeta_off]  vbmeta descriptor  (vbmeta_size bytes, starts with "AVB0")
#   [vbmeta_off + vbmeta_size ... -64]  hash tree  (the bulk — typically 40+ MB)
#   [last 64 bytes]  AVBf footer
#
# We copy the descriptor + hash tree verbatim (bootloader won't check hashes
# when --disable-verity is used), then write an updated footer pointing at the
# correct offsets in the new image.
avb_payload = stock[vbmeta_off : -AVB_FOOTER_SIZE]   # descriptor + hash tree
if len(avb_payload) == 0:
    print('[bootimg] WARNING: AVB payload is empty — skipping AVB preservation')
    sys.exit(0)

with open(OUTPUT_IMG, 'rb') as f:
    new_image = f.read()

new_image_size = len(new_image)

# Build updated footer: same magic/versions/vbmeta_size, new offsets
new_footer = struct.pack(AVB_FOOTER_FMT,
    magic,
    vmajor,
    vminor,
    new_image_size,          # original_image_size = end of kernel+ramdisk in new image
    new_image_size,          # vbmeta_offset       = right after the new image content
    vbmeta_size,             # vbmeta_size stays the same (descriptor size unchanged)
    reserved,                # reserved bytes unchanged
)

with open(OUTPUT_IMG, 'wb') as f:
    f.write(new_image)
    f.write(avb_payload)
    f.write(new_footer)

final_size = new_image_size + len(avb_payload) + AVB_FOOTER_SIZE
hash_tree_mb = (len(avb_payload) - vbmeta_size) / 1024 / 1024
print(f'[bootimg] ✓ AVB block appended  : {vbmeta_size} B descriptor + {hash_tree_mb:.1f} MB hash tree + 64 B footer')
print(f'[bootimg] ✓ New image size      : {final_size/1024/1024:.1f} MB  (stock was {len(stock)/1024/1024:.1f} MB)')
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
SIZE_MARGIN_BYTES="${SIZE_MARGIN_BYTES:-2097152}"                    # 2 MiB safety margin
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
