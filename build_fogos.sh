#!/usr/bin/env bash
###############################################################################
# VirgoYT Gaming Kernel — FogOS Extreme Gaming Edition
# Build Script (Replit / NixOS Edition)
#
# Developer : Prince · VirgoYT707
# Device    : Motorola G45 / G34 (SM6375 — Holi Platform)
# Base      : Linux 5.4.302 · Android 16
#
# "I don't chase. I attract. I WIN." — VirgoYT707
#
# TOOLCHAIN (auto-detected on Replit):
#   - Clang 19 (LLVM) via Nix
#   - aarch64-unknown-linux-gnu-* (binutils) via Nix
#
# USAGE:
#   ./build_fogos.sh              # Full build
#   ./build_fogos.sh --clean      # Clean before build
#   ./build_fogos.sh --menuconfig # Open menuconfig
#   ./build_fogos.sh --bootimg /path/to/stock_boot.img  # Build boot.img too
###############################################################################

set -e

###############################################################################
# CONFIGURATION
###############################################################################
KERNEL_DIR="$(pwd)"
OUT_DIR="${KERNEL_DIR}/out"
ANYKERNEL_DIR="${KERNEL_DIR}/anykernel3"
ZIP_DIR="${KERNEL_DIR}/release"

# Toolchain — auto-detected for Replit/NixOS
CLANG_BIN="$(dirname "$(which clang)")"
LLVM_BIN="$(dirname "$(which llvm-ar)")"
GCC_AARCH64_BIN="/nix/store/3qwn7dr7n9vhm07bkavlqyxilhnj6b27-aarch64-unknown-linux-gnu-gcc-wrapper-13.3.0/bin"

# Cross-compile settings
ARCH="arm64"
SUBARCH="arm64"
CROSS_COMPILE="aarch64-unknown-linux-gnu-"
CLANG_TRIPLE="aarch64-linux-gnu-"

# Defconfig — full pre-tuned gaming defconfig
DEFCONFIG="vendor/fogos_defconfig"
GAMING_FRAGMENT="${KERNEL_DIR}/arch/arm64/configs/vendor/fogos_gaming.config"

# Branding
KERNEL_VERSION="FogOS-Extreme-Gaming-v2.0-Ultra"
DATE="$(date +%Y%m%d-%H%M)"
ZIP_NAME="${KERNEL_VERSION}-Holi-${DATE}.zip"

JOBS=$(nproc --all)

# boot.img support (pass --bootimg <stock_boot.img>)
STOCK_BOOT_IMG=""
DO_BOOTIMG=false

###############################################################################
# COLORS
###############################################################################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log_info()    { echo -e "${CYAN}[FogOS] $1${NC}"; }
log_success() { echo -e "${GREEN}[FogOS] ✓ $1${NC}"; }
log_warn()    { echo -e "${YELLOW}[FogOS] ⚠ $1${NC}"; }
log_error()   { echo -e "${RED}[FogOS] ✗ $1${NC}"; exit 1; }
log_step()    { echo -e "${MAGENTA}[FogOS] ━━ $1 ━━${NC}"; }

###############################################################################
# ARGUMENT PARSING
###############################################################################
DO_CLEAN=false
DO_MENUCONFIG=false
for ARG in "$@"; do
    case "$ARG" in
        --clean)      DO_CLEAN=true ;;
        --menuconfig) DO_MENUCONFIG=true ;;
        --bootimg)    DO_BOOTIMG=true ;;
        --help|-h)
            echo "Usage: $0 [--clean] [--menuconfig] [--bootimg]"
            echo "  --bootimg : also build boot.img (place stock_boot.img in kernel dir first)"
            exit 0
            ;;
        *)
            if $DO_BOOTIMG && [ -z "$STOCK_BOOT_IMG" ] && [ -f "$ARG" ]; then
                STOCK_BOOT_IMG="$ARG"
            fi
            ;;
    esac
done

###############################################################################
# TOOLCHAIN SETUP
###############################################################################
setup_toolchain() {
    log_step "Toolchain Setup"

    if ! command -v clang &>/dev/null; then
        log_error "clang not found! Run: nix-env -iA nixpkgs.clang"
    fi

    if [ ! -d "$GCC_AARCH64_BIN" ]; then
        log_warn "Expected GCC aarch64 wrapper not found at $GCC_AARCH64_BIN"
        log_warn "Searching for alternative..."
        ALT=$(find /nix/store -maxdepth 2 -name "aarch64-unknown-linux-gnu-gcc" 2>/dev/null | head -1)
        if [ -n "$ALT" ]; then
            GCC_AARCH64_BIN="$(dirname "$ALT")"
            log_info "Found at: $GCC_AARCH64_BIN"
        else
            log_warn "No aarch64 GCC found — using pure LLVM mode"
            CROSS_COMPILE=""
        fi
    fi

    # Add toolchain bins to PATH
    export PATH="${CLANG_BIN}:${LLVM_BIN}:${GCC_AARCH64_BIN}:${PATH}"

    log_success "Clang:   $(clang --version | head -1)"
    log_success "LLD:     $(ld.lld --version | head -1)"
    log_success "LLVM-AR: $(llvm-ar --version | head -1)"
    if [ -n "$CROSS_COMPILE" ]; then
        log_success "GCC:     $(${CROSS_COMPILE}gcc --version | head -1)"
    fi
}

###############################################################################
# COMMON MAKE FLAGS
###############################################################################
MAKE_FLAGS=(
    ARCH="${ARCH}"
    SUBARCH="${SUBARCH}"
    CC="clang"
    CLANG_TRIPLE="${CLANG_TRIPLE}"
    CROSS_COMPILE="${CROSS_COMPILE}"
    LLVM=1
    LLVM_IAS=1
    AR="llvm-ar"
    NM="llvm-nm"
    OBJCOPY="llvm-objcopy"
    OBJDUMP="llvm-objdump"
    STRIP="llvm-strip"
    O="${OUT_DIR}"
    -j"${JOBS}"
)

###############################################################################
# CLEAN
###############################################################################
do_clean() {
    log_step "Clean Build"
    make "${MAKE_FLAGS[@]}" mrproper
    rm -rf "${OUT_DIR}"
    log_success "Cleaned output directory"
}

###############################################################################
# MENUCONFIG
###############################################################################
do_menuconfig() {
    log_step "menuconfig"
    mkdir -p "${OUT_DIR}"
    make "${MAKE_FLAGS[@]}" "${DEFCONFIG}"
    make "${MAKE_FLAGS[@]}" menuconfig
}

###############################################################################
# BUILD KERNEL
###############################################################################
build_kernel() {
    log_step "Configuring FogOS Extreme Gaming Kernel"
    mkdir -p "${OUT_DIR}" "${ZIP_DIR}"

    # Load base defconfig
    log_info "Loading defconfig: ${DEFCONFIG}"
    make "${MAKE_FLAGS[@]}" "${DEFCONFIG}"

    # Merge gaming fragment
    if [ -f "${GAMING_FRAGMENT}" ]; then
        log_info "Merging gaming fragment: fogos_gaming.config"
        ./scripts/kconfig/merge_config.sh -m -O "${OUT_DIR}" \
            "${OUT_DIR}/.config" "${GAMING_FRAGMENT}"
        make "${MAKE_FLAGS[@]}" olddefconfig
    fi

    log_success "Config ready — $(grep -c '=y' "${OUT_DIR}/.config") options enabled"

    log_step "Compiling Linux 5.4.302 — FogOS Extreme Gaming"
    log_info "Jobs: ${JOBS} | Target: ${ARCH} | Compiler: clang+LLVM"
    echo ""

    START_TIME=$(date +%s)

    make "${MAKE_FLAGS[@]}" Image.gz-dtb 2>&1 | tee "${OUT_DIR}/build.log" || {
        log_warn "Image.gz-dtb failed, trying Image..."
        make "${MAKE_FLAGS[@]}" Image 2>&1 | tee -a "${OUT_DIR}/build.log" || {
            log_error "Kernel build failed! Check ${OUT_DIR}/build.log"
        }
    }

    END_TIME=$(date +%s)
    BUILD_TIME=$((END_TIME - START_TIME))
    log_success "Kernel compiled in ${BUILD_TIME}s"
}

###############################################################################
# PACKAGE ANYKERNEL3 ZIP
###############################################################################
package_zip() {
    log_step "Packaging AnyKernel3 Flashable ZIP"

    KERNEL_IMG=""
    for img in "${OUT_DIR}/arch/arm64/boot/Image.gz-dtb" \
               "${OUT_DIR}/arch/arm64/boot/Image.gz" \
               "${OUT_DIR}/arch/arm64/boot/Image"; do
        if [ -f "$img" ]; then
            KERNEL_IMG="$img"
            break
        fi
    done

    if [ -z "$KERNEL_IMG" ]; then
        log_error "No kernel image found in ${OUT_DIR}/arch/arm64/boot/"
    fi

    log_info "Kernel image: $KERNEL_IMG"

    # Copy into AnyKernel dir
    cp "${KERNEL_IMG}" "${ANYKERNEL_DIR}/Image.gz-dtb" 2>/dev/null || \
    cp "${KERNEL_IMG}" "${ANYKERNEL_DIR}/Image"

    # Copy DTBs if present
    if [ -d "${OUT_DIR}/arch/arm64/boot/dts/qcom" ]; then
        mkdir -p "${ANYKERNEL_DIR}/dtbs"
        cp "${OUT_DIR}/arch/arm64/boot/dts/qcom/"*.dtb "${ANYKERNEL_DIR}/dtbs/" 2>/dev/null || true
        log_info "DTBs copied"
    fi

    # Build the zip
    cd "${ANYKERNEL_DIR}"
    zip -r9 "${ZIP_DIR}/${ZIP_NAME}" . \
        --exclude='.git/*' --exclude='*.placeholder'
    cd "${KERNEL_DIR}"

    log_success "AnyKernel3 ZIP: ${ZIP_DIR}/${ZIP_NAME}"
    log_success "Size: $(du -sh "${ZIP_DIR}/${ZIP_NAME}" | cut -f1)"
}

###############################################################################
# BUILD BOOT.IMG (requires stock_boot.img)
###############################################################################
build_bootimg() {
    log_step "Building boot.img"

    if [ ! -f "${STOCK_BOOT_IMG}" ]; then
        # look for it in common locations
        for candidate in "${KERNEL_DIR}/stock_boot.img" "${KERNEL_DIR}/boot.img"; do
            [ -f "$candidate" ] && STOCK_BOOT_IMG="$candidate" && break
        done
    fi

    if [ ! -f "${STOCK_BOOT_IMG}" ]; then
        log_warn "No stock_boot.img found — skipping boot.img creation"
        log_warn "To build boot.img:"
        log_warn "  1. Place your device's stock_boot.img in the kernel directory"
        log_warn "  2. Run: ./build_fogos.sh --bootimg stock_boot.img"
        return 0
    fi

    MKBOOTIMG=$(which mkbootimg 2>/dev/null || echo "")
    if [ -z "$MKBOOTIMG" ]; then
        log_warn "mkbootimg not found — installing..."
        pip3 install --quiet mkbootimg 2>/dev/null || true
        MKBOOTIMG=$(which mkbootimg 2>/dev/null || echo "")
    fi

    if [ -z "$MKBOOTIMG" ]; then
        log_warn "Could not install mkbootimg. Downloading Android tools..."
        local TOOLS_DIR="${OUT_DIR}/android_tools"
        mkdir -p "$TOOLS_DIR"
        if command -v python3 &>/dev/null; then
            python3 - << 'PYEOF'
import urllib.request, os, stat, sys
url = "https://android.googlesource.com/platform/system/tools/mkbootimg/+archive/refs/heads/main.tar.gz"
print(f"Cannot auto-download mkbootimg in this environment.")
print(f"Please provide stock_boot.img and mkbootimg manually.")
PYEOF
        fi
        log_warn "Skipping boot.img — see instructions above"
        return 0
    fi

    log_info "Extracting ramdisk from: ${STOCK_BOOT_IMG}"
    UNPACK_DIR="${OUT_DIR}/boot_unpack"
    mkdir -p "${UNPACK_DIR}"

    # Unpack stock boot image using python3
    python3 - <<PYEOF
import subprocess, sys
r = subprocess.run(
    ["python3", "-m", "mkbootimg", "--unpack", "${STOCK_BOOT_IMG}", "--out", "${UNPACK_DIR}"],
    capture_output=True, text=True
)
if r.returncode != 0:
    print("unpack failed:", r.stderr)
    sys.exit(1)
print("Stock boot.img unpacked")
PYEOF

    # Find our kernel image
    KERNEL_IMG=""
    for img in "${OUT_DIR}/arch/arm64/boot/Image.gz-dtb" \
               "${OUT_DIR}/arch/arm64/boot/Image.gz" \
               "${OUT_DIR}/arch/arm64/boot/Image"; do
        [ -f "$img" ] && KERNEL_IMG="$img" && break
    done

    BOOTIMG_OUT="${ZIP_DIR}/${KERNEL_VERSION}-Holi-${DATE}-boot.img"

    log_info "Building boot.img with new kernel..."
    python3 -m mkbootimg \
        --kernel "${KERNEL_IMG}" \
        --ramdisk "${UNPACK_DIR}/ramdisk" \
        --pagesize 4096 \
        --base 0x00000000 \
        --kernel_offset 0x00008000 \
        --ramdisk_offset 0x01000000 \
        --tags_offset 0x00000100 \
        --cmdline "console=ttyMSM0,115200n8 androidboot.hardware=qcom androidboot.console=ttyMSM0 androidboot.memcg=1 lpm_levels.sleep_disabled=1 video=vfb:640x400,bpp=32,memsize=3072000 msm_rtb.filter=0x237 service_locator.enable=1 androidboot.usbcontroller=4e00000.dwc3 swiotlb=2048 loop.max_part=7 cgroup.memory=nokmem,nosocket reboot=panic_warm buildvariant=user" \
        -o "${BOOTIMG_OUT}"

    log_success "boot.img: ${BOOTIMG_OUT}"
    log_success "Size: $(du -sh "${BOOTIMG_OUT}" | cut -f1)"
}

###############################################################################
# SUMMARY
###############################################################################
print_summary() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  👑  FogOS Extreme Gaming Kernel v2.0 Ultra — DONE  ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║  Device : Motorola G45 / G34 (SM6375 / Holi)        ║${NC}"
    echo -e "${CYAN}║  Dev    : Prince (VirgoYT707)                        ║${NC}"
    echo -e "${CYAN}║  Base   : Linux 5.4.302 · Android 16                ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║  Output:                                             ║${NC}"
    echo -e "${CYAN}║  AnyKernel3 ZIP → release/ folder                   ║${NC}"
    if $DO_BOOTIMG; then
    echo -e "${CYAN}║  boot.img       → release/ folder                   ║${NC}"
    fi
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║  Flash: TWRP → Install → Select ZIP                 ║${NC}"
    if $DO_BOOTIMG; then
    echo -e "${CYAN}║     or: fastboot flash boot boot.img                 ║${NC}"
    fi
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}  👑 Built Different · VirgoYT707 · Prince 👑${NC}"
    echo ""
}

###############################################################################
# ENTRY POINT
###############################################################################
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║    VirgoYT Gaming Kernel — FogOS Extreme v2.0 Ultra  ║${NC}"
echo -e "${CYAN}║   Device: Motorola G45/G34 (SM6375/Holi)            ║${NC}"
echo -e "${CYAN}║   Developer: Prince (VirgoYT707)                    ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

setup_toolchain

if $DO_CLEAN; then
    do_clean
fi

if $DO_MENUCONFIG; then
    do_menuconfig
    exit 0
fi

build_kernel
package_zip

if $DO_BOOTIMG; then
    build_bootimg
fi

print_summary
