#!/usr/bin/env bash
###############################################################################
# FogOS Extreme Gaming Kernel — AVB/Verification Issues Fix Script
#
# This script helps resolve common Android Verified Boot (AVB) issues
# that may prevent the kernel from booting
#
# Usage:
#   bash scripts/fix_avb_issues.sh [options]
#
# Options:
#   --disable-verity     Disable dm-verity verification
#   --disable-verification Disable AVB verification
#   --help              Show this help message
###############################################################################

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()    { echo -e "${CYAN}[AVB-Fix] $1${NC}"; }
ok()     { echo -e "${GREEN}[AVB-Fix] ✓ $1${NC}"; }
warn()   { echo -e "${YELLOW}[AVB-Fix] ⚠ $1${NC}"; }
fail()   { echo -e "${RED}[AVB-Fix] ✗ $1${NC}"; exit 1; }

SHOW_HELP=false
DISABLE_VERITY=false
DISABLE_VERIFICATION=false

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --disable-verity)
        DISABLE_VERITY=true
        shift
        ;;
      --disable-verification)
        DISABLE_VERIFICATION=true
        shift
        ;;
      --help|-h)
        SHOW_HELP=true
        shift
        ;;
      *)
        fail "Unknown option: $1"
        ;;
    esac
  done
}

show_help() {
  cat << EOF
FogOS AVB/Verification Issues Fix Script

This script helps resolve common Android Verified Boot (AVB) issues that may
prevent the kernel from booting.

Usage:
  bash scripts/fix_avb_issues.sh [options]

Options:
  --disable-verity       Disable dm-verity verification
  --disable-verification Disable AVB verification  
  --help                 Show this help message

Common Issues and Solutions:

1. "Your device is corrupt" or AVB verification failed:
   fastboot --disable-verity --disable-verification flash vbmeta vbmeta.img
   fastboot flash boot your_boot.img

2. "No OS installed" error:
   fastboot flash vbmeta --disable-verity --disable-verification vbmeta.img
   fastboot flash boot your_boot.img

3. Boot verification errors:
   - Disable AVB temporarily
   - Flash kernel
   - Re-enable AVB if needed

4. dm-verity errors:
   - This script can generate commands to disable dm-verity
   - Use --disable-verity flag

Example:
  # Generate commands to disable verification
  bash scripts/fix_avb_issues.sh --disable-verification

  # This will output the fastboot commands you need to run
EOF
}

parse_args "$@"

if [ "$SHOW_HELP" = true ]; then
  show_help
  exit 0
fi

log "FogOS AVB/Verification Issues Fix Script"
log "========================================="

# Check if fastboot is available
if ! command -v fastboot &>/dev/null; then
  warn "fastboot not found in PATH"
  log "Please install Android Platform Tools"
  log "Ubuntu/Debian: sudo apt install android-tools-fastboot"
  log "Or download from: https://developer.android.com/studio/releases/platform-tools"
fi

# Generate fix commands
log ""
log "Recommended fix commands for your device:"
log ""

if [ "$DISABLE_VERITY" = true ] || [ "$DISABLE_VERIFICATION" = true ]; then
  log "Step 1: Boot to bootloader"
  log "  adb reboot bootloader"
  log ""
  
  if [ "$DISABLE_VERITY" = true ]; then
    log "Step 2: Disable dm-verity (fixes filesystem verification errors)"
    log "  fastboot flash vbmeta --disable-verity vbmeta.img"
    log ""
  fi
  
  if [ "$DISABLE_VERIFICATION" = true ]; then
    log "Step 2: Disable AVB verification (fixes boot verification errors)"
    log "  fastboot --disable-verity --disable-verification flash vbmeta vbmeta.img"
    log ""
  fi
  
  log "Step 3: Flash the FogOS kernel"
  log "  fastboot flash boot release/FogOS-Extreme-Gaming-boot.img"
  log ""
  
  log "Step 4: Reboot"
  log "  fastboot reboot"
  log ""
else
  log "Standard kernel flash procedure:"
  log "  adb reboot bootloader"
  log "  fastboot flash boot release/FogOS-Extreme-Gaming-boot.img"
  log "  fastboot reboot"
  log ""
fi

log "If you encounter verification errors, run with:"
log "  bash scripts/fix_avb_issues.sh --disable-verification"
log ""

log "Common error messages and their fixes:"
log ""
log "1. 'Your device is corrupt' or 'Verification failed':"
log "   fastboot --disable-verity --disable-verification flash vbmeta vbmeta.img"
log "   fastboot flash boot release/FogOS-Extreme-Gaming-boot.img"
log ""
log "2. 'No OS installed':"
log "   fastboot flash vbmeta --disable-verity --disable-verification vbmeta.img"
log "   fastboot flash boot release/FogOS-Extreme-Gaming-boot.img"
log ""
log "3. 'dm-verity failed':"
log "   fastboot flash vbmeta --disable-verity vbmeta.img"
log "   fastboot flash boot release/FogOS-Extreme-Gaming-boot.img"
log ""

ok "Fix script completed. Follow the commands above to resolve boot issues."