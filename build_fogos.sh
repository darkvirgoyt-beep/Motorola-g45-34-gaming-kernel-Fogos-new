#!/usr/bin/env bash
###############################################################################
# FogOS Extreme Gaming Kernel - Build Script
# Device: Motorola G45 (SM6375 / Holi)
# Developer: Prince (VirgoYT707)
# Kernel Base: 5.4.302
#
# REQUIREMENTS (Ubuntu 20.04/22.04 recommended):
#   sudo apt-get install -y bc bison build-essential ccache curl flex \
#     g++-multilib gcc-multilib git gnupg gperf imagemagick lib32ncurses5-dev \
#     lib32readline-dev lib32z1-dev liblz4-tool libncurses5 libncurses5-dev \
#     libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync \
#     schedtool squashfs-tools xsltproc zip zlib1g-dev python3 python-is-python3
#
# TOOLCHAIN:
#   - Clang 20.0+ (Android kernel toolchain)
#   - Download: https://github.com/ZyCromerZ/Clang or Android clang prebuilts
#
# USAGE:
#   ./build_fogos.sh              # Full build
#   ./build_fogos.sh --clean      # Clean build
#   ./build_fogos.sh --menuconfig # Open menuconfig
###############################################################################

set -e

###############################################################################
# CONFIGURATION — Edit these paths for your machine
###############################################################################

KERNEL_DIR="$(pwd)"
OUT_DIR="${KERNEL_DIR}/out"
ANYKERNEL_DIR="${KERNEL_DIR}/anykernel3"
ZIP_DIR="${KERNEL_DIR}/release"

# Toolchain paths — adjust to where you installed clang
CLANG_DIR="${HOME}/toolchains/clang"
GCC_DIR="${HOME}/toolchains/gcc/aarch64-linux-android-4.9/bin"
GCC32_DIR="${HOME}/toolchains/gcc/arm-linux-androideabi-4.9/bin"

# Cross-compile target
ARCH="arm64"
SUBARCH="arm64"

# Defconfig: base Holi QGKI + FogOS gaming fragment
BASE_DEFCONFIG="vendor/holi-qgki_defconfig"
GAMING_FRAGMENT="${KERNEL_DIR}/arch/arm64/configs/vendor/fogos_gaming.config"

# Kernel version branding
KERNEL_VERSION="FogOS-Extreme-Gaming-v1.0"
DATE="$(date +%Y%m%d)"
ZIP_NAME="${KERNEL_VERSION}-Holi-${DATE}.zip"

# Number of build jobs
JOBS=$(nproc --all)

###############################################################################
# COLORS
###############################################################################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()    { echo -e "${CYAN}[FogOS] $1${NC}"; }
log_success() { echo -e "${GREEN}[FogOS] ✓ $1${NC}"; }
log_warn()    { echo -e "${YELLOW}[FogOS] ⚠ $1${NC}"; }
log_error()   { echo -e "${RED}[FogOS] ✗ $1${NC}"; exit 1; }

###############################################################################
# ARGUMENT PARSING
###############################################################################
DO_CLEAN=false
DO_MENUCONFIG=false
for ARG in "$@"; do
    case "$ARG" in
        --clean)      DO_CLEAN=true ;;
        --menuconfig) DO_MENUCONFIG=true ;;
        --help|-h)
            echo "Usage: $0 [--clean] [--menuconfig]"
            exit 0
            ;;
    esac
done

###############################################################################
# TOOLCHAIN SETUP
###############################################################################
setup_toolchain() {
    log_info "Setting up toolchain..."

    # Try to auto-detect clang
    if [ -d "$CLANG_DIR" ]; then
        CLANG_BIN="$CLANG_DIR/bin"
    elif command -v clang-20 &>/dev/null; then
        CLANG_BIN="$(dirname $(which clang-20))"
    elif command -v clang &>/dev/null; then
        CLANG_BIN="$(dirname $(which clang))"
    else
        log_error "Clang not found! Install from:\n  https://github.com/ZyCromerZ/Clang\n  or: sudo apt install clang"
    fi

    # Try to auto-detect GCC (needed for some modules)
    if [ -d "$GCC_DIR" ]; then
        CROSS_COMPILE="${GCC_DIR}/aarch64-linux-android-"
        CROSS_COMPILE_ARM32="${GCC32_DIR}/arm-linux-androideabi-"
    elif command -v aarch64-linux-gnu-gcc &>/dev/null; then
        CROSS_COMPILE="aarch64-linux-gnu-"
        CROSS_COMPILE_ARM32="arm-linux-gnueabihf-"
    else
        log_warn "GCC not found, using clang for everything"
        CROSS_COMPILE="$CLANG_BIN/aarch64-linux-gnu-"
        CROSS_COMPILE_ARM32="$CLANG_BIN/arm-linux-gnueabihf-"
    fi

    log_success "Clang: $(${CLANG_BIN}/clang --version 2>/dev/null | head -1)"
}

###############################################################################
# BUILD ARGUMENTS
###############################################################################
make_args() {
    echo \
        O="${OUT_DIR}" \
        ARCH="${ARCH}" \
        SUBARCH="${SUBARCH}" \
        CC="${CLANG_BIN}/clang" \
        CLANG_TRIPLE="aarch64-linux-gnu-" \
        CROSS_COMPILE="${CROSS_COMPILE}" \
        CROSS_COMPILE_ARM32="${CROSS_COMPILE_ARM32}" \
        LD="${CLANG_BIN}/ld.lld" \
        AR="${CLANG_BIN}/llvm-ar" \
        NM="${CLANG_BIN}/llvm-nm" \
        OBJCOPY="${CLANG_BIN}/llvm-objcopy" \
        OBJDUMP="${CLANG_BIN}/llvm-objdump" \
        STRIP="${CLANG_BIN}/llvm-strip" \
        -j${JOBS} \
        LOCALVERSION="-FogOS-Extreme-Gaming-v1.0"
}

###############################################################################
# GENERATE DEFCONFIG
###############################################################################
generate_defconfig() {
    log_info "Generating defconfig: ${BASE_DEFCONFIG} + gaming fragment..."

    mkdir -p "${OUT_DIR}"

    # Start from the base Holi QGKI defconfig
    make $(make_args) "${BASE_DEFCONFIG}"

    # Merge in gaming optimizations fragment
    if [ -f "${GAMING_FRAGMENT}" ]; then
        log_info "Merging gaming fragment: fogos_gaming.config"
        ./scripts/kconfig/merge_config.sh \
            -m \
            -O "${OUT_DIR}" \
            "${OUT_DIR}/.config" \
            "${GAMING_FRAGMENT}"
        make $(make_args) olddefconfig
        log_success "Gaming fragment merged"
    else
        log_warn "Gaming fragment not found at: ${GAMING_FRAGMENT}"
    fi
}

###############################################################################
# CLEAN
###############################################################################
do_clean() {
    log_info "Cleaning build artifacts..."
    rm -rf "${OUT_DIR}"
    log_success "Clean complete"
}

###############################################################################
# MENUCONFIG
###############################################################################
do_menuconfig() {
    generate_defconfig
    make $(make_args) menuconfig
    make $(make_args) savedefconfig
    log_success "Saved defconfig to ${OUT_DIR}/defconfig"
}

###############################################################################
# MAIN BUILD
###############################################################################
build_kernel() {
    log_info "Starting FogOS Extreme Gaming Kernel build..."
    log_info "Jobs: ${JOBS} | Arch: ${ARCH}"

    START_TIME=$(date +%s)

    # Generate config
    generate_defconfig

    # Build kernel image
    log_info "Building kernel image (Image.gz)..."
    make $(make_args) Image.gz-dtb dtbs

    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    log_success "Kernel built in $((ELAPSED/60))m $((ELAPSED%60))s"
}

###############################################################################
# PACKAGE - AnyKernel3 ZIP
###############################################################################
package_zip() {
    log_info "Packaging AnyKernel3 ZIP..."

    KERNEL_IMAGE="${OUT_DIR}/arch/${ARCH}/boot/Image.gz"
    KERNEL_IMAGE_DTB="${OUT_DIR}/arch/${ARCH}/boot/Image.gz-dtb"

    [ ! -f "${KERNEL_IMAGE_DTB}" ] && \
        [ ! -f "${KERNEL_IMAGE}" ] && \
        log_error "Kernel image not found! Build failed?"

    # Prepare AnyKernel3 directory
    cp -f "${KERNEL_IMAGE_DTB:-$KERNEL_IMAGE}" "${ANYKERNEL_DIR}/Image.gz-dtb" 2>/dev/null || \
    cp -f "${KERNEL_IMAGE}" "${ANYKERNEL_DIR}/Image.gz"

    # Copy DTBO if present
    DTBO="${OUT_DIR}/arch/${ARCH}/boot/dtbo.img"
    [ -f "${DTBO}" ] && cp -f "${DTBO}" "${ANYKERNEL_DIR}/dtbo.img"

    # Install gaming init script to AnyKernel3
    mkdir -p "${ANYKERNEL_DIR}/system/etc/init.d"
    cp -f "${ANYKERNEL_DIR}/fogos_gaming_init.sh" \
          "${ANYKERNEL_DIR}/system/etc/init.d/99-fogos-gaming"
    chmod 755 "${ANYKERNEL_DIR}/system/etc/init.d/99-fogos-gaming"

    # Create ZIP
    mkdir -p "${ZIP_DIR}"
    cd "${ANYKERNEL_DIR}"
    zip -r9 "${ZIP_DIR}/${ZIP_NAME}" . \
        --exclude="*.git*" \
        --exclude="*.DS_Store*" \
        --exclude="fogos_gaming_init.sh"
    cd "${KERNEL_DIR}"

    log_success "ZIP created: ${ZIP_DIR}/${ZIP_NAME}"
}

###############################################################################
# SUMMARY
###############################################################################
print_summary() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   FogOS Extreme Gaming Kernel v1.0 - BUILD DONE!    ║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║  Device  : Motorola G45 (SM6375 / Holi)             ║${NC}"
    echo -e "${GREEN}║  Dev     : Prince (VirgoYT707)                      ║${NC}"
    echo -e "${GREEN}║  Base    : Linux 5.4.302                            ║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║  Output:                                            ║${NC}"
    echo -e "${GREEN}║  • ${ZIP_DIR}/${ZIP_NAME}  ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Flash with: TWRP → Install → ${ZIP_NAME}${NC}"
    echo ""
}

###############################################################################
# ENTRY POINT
###############################################################################
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       FogOS Extreme Gaming Kernel Builder            ║${NC}"
echo -e "${CYAN}║   Device: Motorola G45 (SM6375/Holi) | v1.0         ║${NC}"
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
print_summary
