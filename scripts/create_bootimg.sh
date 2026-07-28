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
