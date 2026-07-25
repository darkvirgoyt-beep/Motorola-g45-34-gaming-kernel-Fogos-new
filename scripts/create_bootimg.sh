#!/usr/bin/env bash
###############################################################################
# FogOS Extreme Gaming Kernel — Boot Image Creator
#
# Developer : Prince · VirgoYT707
# Device    : Motorola G45 / G34 (SM6375 — Holi Platform)
#
# Usage:
#   bash scripts/create_bootimg.sh <stock_boot.img> [kernel_image] [output.img]
#
# Example:
#   bash scripts/create_bootimg.sh stock/boot.img \
#       out/arch/arm64/boot/Image \
#       release/FogOS-boot.img
#
# This script:
#   1. Unpacks your stock boot.img (preserving all headers + ramdisk)
#   2. Replaces ONLY the kernel with your FogOS kernel
#   3. Repacks a new boot.img identical in structure to your stock image
#
# Supports boot header v0, v1, v2, v3 (GKI) — Moto G45 uses v3.
#
# Requirements:
#   apt install mkbootimg    (includes mkbootimg and unpack_bootimg)
###############################################################################

set -euo pipefail

STOCK_IMG="${1:-stock/boot.img}"
KERNEL_IMG="${2:-out/arch/arm64/boot/Image}"
OUTPUT_IMG="${3:-release/FogOS-Extreme-Gaming-boot.img}"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${CYAN}[bootimg] $*${NC}"; }
ok()   { echo -e "${GREEN}[bootimg] ✓ $*${NC}"; }
warn() { echo -e "${YELLOW}[bootimg] ⚠ $*${NC}"; }
fail() { echo -e "${RED}[bootimg] ✗ $*${NC}"; exit 1; }

###############################################################################
# VALIDATE INPUTS
###############################################################################
[ ! -f "$STOCK_IMG" ]  && fail "Stock boot.img not found: $STOCK_IMG"
[ ! -f "$KERNEL_IMG" ] && fail "Kernel image not found: $KERNEL_IMG"

log "Stock image : $STOCK_IMG  ($(du -sh "$STOCK_IMG"  | cut -f1))"
log "Kernel      : $KERNEL_IMG ($(du -sh "$KERNEL_IMG" | cut -f1))"
log "Output      : $OUTPUT_IMG"

###############################################################################
# CHECK / INSTALL TOOLS
###############################################################################
install_tools() {
  log "Installing mkbootimg via apt..."
  if command -v sudo &>/dev/null; then
    sudo apt-get install -y mkbootimg
  else
    apt-get install -y mkbootimg
  fi
}

UNPACK_CMD=""
MKBOOT_CMD=""

for cmd in unpack_bootimg unpackbootimg; do
  command -v "$cmd" &>/dev/null && { UNPACK_CMD="$cmd"; break; }
done
command -v mkbootimg &>/dev/null && MKBOOT_CMD="mkbootimg"

if [ -z "$UNPACK_CMD" ] || [ -z "$MKBOOT_CMD" ]; then
  install_tools
  for cmd in unpack_bootimg unpackbootimg; do
    command -v "$cmd" &>/dev/null && { UNPACK_CMD="$cmd"; break; }
  done
  command -v mkbootimg &>/dev/null && MKBOOT_CMD="mkbootimg"
fi

[ -z "$UNPACK_CMD" ] && fail "unpack_bootimg not found. Run: apt install mkbootimg"
[ -z "$MKBOOT_CMD" ] && fail "mkbootimg not found. Run: apt install mkbootimg"
ok "Tools: $UNPACK_CMD + $MKBOOT_CMD"

###############################################################################
# UNPACK
###############################################################################
WORK_DIR="$(mktemp -d /tmp/fogos-bootimg.XXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

log "Unpacking stock boot.img..."

# ── Primary: --format mkbootimg writes the exact mkbootimg flags to stdout ──
# Example output: --header_version 3 --os_version 16.0.0 --kernel kernel ...
FORMAT_OUT="${WORK_DIR}/mkbootimg_args.txt"
if "$UNPACK_CMD" --boot_img "$STOCK_IMG" \
       --out "$WORK_DIR" \
       --format mkbootimg \
       > "$FORMAT_OUT" 2>/tmp/fogos-unpack.log; then
  ok "Unpacked (--format mkbootimg)"
  USE_FORMAT=true
else
  # Fallback: plain unpack (older unpack_bootimg builds)
  "$UNPACK_CMD" --boot_img "$STOCK_IMG" --out "$WORK_DIR" \
    2>/tmp/fogos-unpack.log || \
  "$UNPACK_CMD" --input "$STOCK_IMG" --output "$WORK_DIR" \
    2>>/tmp/fogos-unpack.log || true
  USE_FORMAT=false
fi

log "Extracted:"
ls -lh "$WORK_DIR/" || true

mkdir -p "$(dirname "$OUTPUT_IMG")"

###############################################################################
# REPACK — Strategy A: --format mkbootimg parsed with Python shlex (quote-safe)
###############################################################################
if [ "$USE_FORMAT" = "true" ] && [ -s "$FORMAT_OUT" ]; then
  log "Header: v3/GKI (--format mkbootimg path)"

  # Python shlex.split() correctly tokenises the tool's output including any
  # shell-quoted values (e.g. --cmdline 'console=ttyMSM0 androidboot.foo=bar').
  # We pass all substitution values as argv so no shell quoting issues arise.
  python3 - "$FORMAT_OUT" "$KERNEL_IMG" "$OUTPUT_IMG" "$WORK_DIR" \
            "$MKBOOT_CMD" <<'PYEOF'
import shlex, subprocess, sys, os

format_out = sys.argv[1]
kernel_img = sys.argv[2]
output_img = sys.argv[3]
work_dir   = sys.argv[4]
mkboot_cmd = sys.argv[5]

file_flags = {
    '--ramdisk', '--vendor_ramdisk', '--dtb',
    '--second', '--recovery_dtbo',
}

with open(format_out) as fh:
    raw = fh.read().strip()

tokens = shlex.split(raw)           # honours shell quoting correctly
args   = [mkboot_cmd]

i = 0
while i < len(tokens):
    tok = tokens[i]
    i += 1
    val = tokens[i] if i < len(tokens) else ''

    if tok == '--output':
        # Discard the embedded output path; we provide our own.
        i += 1

    elif tok == '--kernel':
        # Substitute our built kernel image.
        args += ['--kernel', kernel_img]
        i += 1   # skip extracted kernel path from tokens

    elif tok in file_flags:
        # File paths may be bare names relative to WORK_DIR — make absolute.
        abs_val = val if os.path.isabs(val) else os.path.join(work_dir, val)
        if os.path.isfile(abs_val):
            args += [tok, abs_val]
        elif os.path.isfile(val):
            args += [tok, val]
        else:
            print(f'[bootimg] ⚠ Skipping {tok}: file not found ({abs_val})',
                  file=sys.stderr)
        i += 1

    elif tok.startswith('--'):
        # Scalar flags (--header_version, --os_version, --cmdline, …)
        if val and not val.startswith('--'):
            args += [tok, val]
            i += 1
        # else: boolean flag with no value (rare in mkbootimg, but safe)

    # else: bare token with no leading '--', skip

# Ensure --output is always present.
if '--output' not in args:
    args += ['--output', output_img]
else:
    idx = args.index('--output')
    args[idx + 1] = output_img




print('[bootimg] Running:', ' '.join(shlex.quote(a) for a in args))
sys.exit(subprocess.call(args))
PYEOF

###############################################################################
# REPACK — Strategy B: manual header parsing (fallback for older tools)
###############################################################################
else
  warn "Falling back to manual parameter extraction (older unpack_bootimg)."

  # Detect header version from binary
  HEADER_VERSION="$(python3 -c "
import struct, sys
with open('$STOCK_IMG','rb') as f:
    f.seek(8)
    data = f.read(40)
# v3: magic(8) kernel_size(4) ramdisk_size(4) os_version(4)
#     header_size(4) reserved(16) header_version(4)  → offset 36
print(struct.unpack_from('<I', data, 36)[0])
" 2>/dev/null || echo "0")"

  log "Boot header version: ${HEADER_VERSION}"

  # Locate ramdisk and dtb
  RAMDISK_FILE="$(ls "$WORK_DIR"/*ramdisk* 2>/dev/null | head -1 || echo "")"
  DTB_FILE="$(ls "$WORK_DIR"/*dtb* 2>/dev/null | head -1 || echo "")"

  # Parse scalar params from unpack output log
  get_param() {
    grep -i "$1" /tmp/fogos-unpack.log 2>/dev/null \
      | grep -oP '(?<=: )[0-9xa-fA-F]+' | head -1 || echo ""
  }
  CMDLINE="$(grep -i "command.line\|cmdline" /tmp/fogos-unpack.log 2>/dev/null \
    | sed 's/.*command.line[: ]*//I' | head -1 || echo "")"
  PAGESIZE="$(get_param 'page.size')"
  OS_VERSION="$(get_param 'os.version')"
  OS_PATCH="$(get_param 'os.patch')"

  # Build arg array — no eval, no string substitution
  declare -a MKBOOT_ARGS
  MKBOOT_ARGS=( --kernel "$KERNEL_IMG" --output "$OUTPUT_IMG" )

  [ -n "$RAMDISK_FILE"  ] && MKBOOT_ARGS+=( --ramdisk "$RAMDISK_FILE" )
  [ -n "$DTB_FILE"      ] && MKBOOT_ARGS+=( --dtb "$DTB_FILE" )
  [ -n "$CMDLINE"       ] && MKBOOT_ARGS+=( --cmdline "$CMDLINE" )
  [ -n "$PAGESIZE"      ] && MKBOOT_ARGS+=( --pagesize "$PAGESIZE" )
  [ -n "$HEADER_VERSION" ] && [ "$HEADER_VERSION" != "0" ] \
                            && MKBOOT_ARGS+=( --header_version "$HEADER_VERSION" )
  [ -n "$OS_VERSION"    ] && MKBOOT_ARGS+=( --os_version "$OS_VERSION" )
  [ -n "$OS_PATCH"      ] && MKBOOT_ARGS+=( --os_patch_level "$OS_PATCH" )

  log "Repacking boot.img..."
  "$MKBOOT_CMD" "${MKBOOT_ARGS[@]}"
fi

###############################################################################
# RESULT
###############################################################################
if [ -f "$OUTPUT_IMG" ]; then
  SIZE_ORIG="$(du -sh "$STOCK_IMG" | cut -f1)"
  SIZE_NEW="$(du -sh "$OUTPUT_IMG"  | cut -f1)"
  echo ""
  ok "Boot image created!"
  ok "  Stock : $SIZE_ORIG"
  ok "  New   : $SIZE_NEW"
  ok "  Path  : $OUTPUT_IMG"
  echo ""
  echo -e "${CYAN}━━━ Flash via Fastboot ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  adb reboot bootloader"
  echo -e "  fastboot flash boot $OUTPUT_IMG"
  echo -e "  fastboot reboot"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "${YELLOW}If you see 'FAILED (remote: AVB footer not found)':${NC}"
  echo -e "  fastboot --disable-verity --disable-verification flash boot $OUTPUT_IMG"
  echo ""
else
  fail "Boot image creation failed — output not found."
fi
