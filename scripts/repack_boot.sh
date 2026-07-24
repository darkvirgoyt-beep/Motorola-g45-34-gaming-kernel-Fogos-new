#!/usr/bin/env bash
###############################################################################
# FogOS Extreme Gaming — boot.img repacker
# Developer: Prince · VirgoYT707
# Usage: bash scripts/repack_boot.sh <new_kernel_image> [stock_boot.img]
###############################################################################
set -euo pipefail

KERNEL_IMAGE="${1:-}"
STOCK_BOOT="${2:-stock/boot.img}"
OUT_DIR="${3:-release}"
WORK_DIR="/tmp/fogos_bootimg"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()    { echo -e "${GREEN}[boot-repack] $1${NC}"; }
log_warn()    { echo -e "${YELLOW}[boot-repack] ⚠ $1${NC}"; }
log_error()   { echo -e "${RED}[boot-repack] ✗ $1${NC}"; exit 1; }

[ -z "$KERNEL_IMAGE" ] && log_error "Usage: $0 <kernel_image> [stock_boot.img]"
[ -f "$KERNEL_IMAGE" ] || log_error "Kernel image not found: $KERNEL_IMAGE"
[ -f "$STOCK_BOOT"   ] || log_error "Stock boot.img not found: $STOCK_BOOT"

log_info "Kernel:     $KERNEL_IMAGE ($(du -sh $KERNEL_IMAGE | cut -f1))"
log_info "Stock boot: $STOCK_BOOT  ($(du -sh $STOCK_BOOT | cut -f1))"

# ── Install tools ────────────────────────────────────────────────────────────
install_tools() {
  if ! command -v unpackbootimg &>/dev/null; then
    log_info "Installing Android boot tools..."
    pip3 install --quiet mkbootimg 2>/dev/null || true

    # Try AOSP unpackbootimg
    if ! command -v unpackbootimg &>/dev/null; then
      TOOLS_DIR="$(mktemp -d)"
      curl -sL "https://github.com/osm0sis/mkbootimg/archive/refs/heads/master.tar.gz" \
        -o "$TOOLS_DIR/mkbootimg.tar.gz" 2>/dev/null || true
      tar -xf "$TOOLS_DIR/mkbootimg.tar.gz" -C "$TOOLS_DIR" --strip-components=1 2>/dev/null || true
      [ -f "$TOOLS_DIR/unpackbootimg" ] && sudo install "$TOOLS_DIR/unpackbootimg" /usr/local/bin/ || true
    fi
  fi
  command -v unpackbootimg &>/dev/null || log_error "unpackbootimg not found after install attempt"
  command -v mkbootimg    &>/dev/null || log_error "mkbootimg not found after install attempt"
  log_info "Tools ready: $(mkbootimg --version 2>/dev/null || echo 'ok')"
}

# ── Unpack stock boot.img ────────────────────────────────────────────────────
unpack_stock() {
  rm -rf "$WORK_DIR" && mkdir -p "$WORK_DIR"
  log_info "Unpacking stock boot.img..."
  unpackbootimg --input "$STOCK_BOOT" --output "$WORK_DIR" 2>&1
  log_info "Unpacked files:"
  ls -lh "$WORK_DIR/"
}

# ── Repack with new kernel ───────────────────────────────────────────────────
repack_boot() {
  mkdir -p "$OUT_DIR"
  DATE=$(date +%Y%m%d-%H%M)
  NEW_BOOT="${OUT_DIR}/FogOS-Extreme-Gaming-v2.0-boot-${DATE}.img"

  log_info "Reading header parameters..."

  # Read values extracted by unpackbootimg
  HEADER_VER=$(cat "$WORK_DIR/"*header_version  2>/dev/null || echo "3")
  PAGE_SIZE=$(cat  "$WORK_DIR/"*pagesize         2>/dev/null || echo "4096")
  RAMDISK="$WORK_DIR/$(ls $WORK_DIR | grep -i ramdisk | head -1)"

  log_info "Header version: $HEADER_VER"
  log_info "Page size:      $PAGE_SIZE"
  log_info "Ramdisk:        $RAMDISK ($(du -sh $RAMDISK | cut -f1))"

  if [ "$HEADER_VER" = "3" ] || [ "$HEADER_VER" = "4" ]; then
    # GKI v3/v4 — no address fields
    CMDLINE=$(cat "$WORK_DIR/"*cmdline 2>/dev/null || echo "")
    OS_VER=$(cat  "$WORK_DIR/"*os_version 2>/dev/null || echo "")
    OS_PATCH=$(cat "$WORK_DIR/"*os_patch_level 2>/dev/null || echo "")

    log_info "Repacking as GKI v${HEADER_VER}..."
    mkbootimg \
      --header_version "$HEADER_VER" \
      --kernel         "$KERNEL_IMAGE" \
      --ramdisk        "$RAMDISK" \
      ${CMDLINE:+--cmdline "$CMDLINE"} \
      ${OS_VER:+--os_version "$OS_VER"} \
      ${OS_PATCH:+--os_patch_level "$OS_PATCH"} \
      -o "$NEW_BOOT"
  else
    # Legacy v0/v1/v2
    BASE=$(cat         "$WORK_DIR/"*base         2>/dev/null || echo "0x00000000")
    KERNEL_OFF=$(cat   "$WORK_DIR/"*kernel_offset 2>/dev/null || echo "0x00008000")
    RAMDISK_OFF=$(cat  "$WORK_DIR/"*ramdisk_offset 2>/dev/null || echo "0x01000000")
    TAGS_OFF=$(cat     "$WORK_DIR/"*tags_offset   2>/dev/null || echo "0x00000100")
    CMDLINE=$(cat      "$WORK_DIR/"*cmdline       2>/dev/null || echo "")

    log_info "Repacking as legacy v${HEADER_VER}..."
    mkbootimg \
      --header_version  "$HEADER_VER" \
      --kernel          "$KERNEL_IMAGE" \
      --ramdisk         "$RAMDISK" \
      --base            "$BASE" \
      --kernel_offset   "$KERNEL_OFF" \
      --ramdisk_offset  "$RAMDISK_OFF" \
      --tags_offset     "$TAGS_OFF" \
      --pagesize        "$PAGE_SIZE" \
      ${CMDLINE:+--cmdline "$CMDLINE"} \
      -o "$NEW_BOOT"
  fi

  SIZE=$(du -sh "$NEW_BOOT" | cut -f1)
  log_info "✅ boot.img created: $NEW_BOOT ($SIZE)"
  echo "$NEW_BOOT"
}

# ── Main ─────────────────────────────────────────────────────────────────────
install_tools
unpack_stock
repack_boot
