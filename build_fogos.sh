#!/usr/bin/env bash
###############################################################################
# FogOS Extreme Gaming Kernel — Build Script v2.0
#
# Developer : Prince · VirgoYT707
# Device    : Motorola G45 / G34 (SM6375 — Holi Platform)
# Base      : Linux 5.4.302 · Android 16
#
# "I don't chase. I attract. I WIN." — VirgoYT707
#
# USAGE:
#   ./build_fogos.sh              # Full build
#   ./build_fogos.sh --clean      # Clean before build
#   ./build_fogos.sh --menuconfig # Open menuconfig
#   ./build_fogos.sh --ci         # CI mode (auto-detect toolchain, no prompts)
###############################################################################

set -euo pipefail

###############################################################################
# DIRECTORIES
###############################################################################
KERNEL_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="${KERNEL_DIR}/out"
ANYKERNEL_DIR="${KERNEL_DIR}/anykernel3"
ZIP_DIR="${KERNEL_DIR}/release"

###############################################################################
# BUILD SETTINGS
###############################################################################
ARCH="arm64"
SUBARCH="arm64"

# Primary defconfig: use vendor/fogos_defconfig if it exists, else holi-qgki
if [ -f "${KERNEL_DIR}/arch/arm64/configs/vendor/fogos_defconfig" ]; then
  BASE_DEFCONFIG="vendor/fogos_defconfig"
elif [ -f "${KERNEL_DIR}/arch/arm64/configs/vendor/holi-qgki_defconfig" ]; then
  BASE_DEFCONFIG="vendor/holi-qgki_defconfig"
else
  BASE_DEFCONFIG="defconfig"
fi

GAMING_FRAGMENT="${KERNEL_DIR}/arch/arm64/configs/vendor/fogos_gaming.config"

KERNEL_VERSION="FogOS-Extreme-Gaming-v2.0"
DATE="$(date +%Y%m%d-%H%M)"
ZIP_NAME="${KERNEL_VERSION}-Holi-${DATE}.zip"
JOBS="${JOBS:-$(nproc --all)}"

###############################################################################
# COLORS
###############################################################################
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'

log_info()    { echo -e "${CYAN}[FogOS] $1${NC}"; }
log_success() { echo -e "${GREEN}[FogOS] ✓ $1${NC}"; }
log_warn()    { echo -e "${YELLOW}[FogOS] ⚠ $1${NC}"; }
log_error()   { echo -e "${RED}[FogOS] ✗ $1${NC}"; exit 1; }

###############################################################################
# ARGUMENT PARSING
###############################################################################
DO_CLEAN=false
DO_MENUCONFIG=false
CI_MODE=false

for ARG in "$@"; do
  case "$ARG" in
    --clean)      DO_CLEAN=true ;;
    --menuconfig) DO_MENUCONFIG=true ;;
    --ci)         CI_MODE=true ;;
    --help|-h)
      echo "Usage: $0 [--clean] [--menuconfig] [--ci]"
      exit 0
      ;;
  esac
done

###############################################################################
# TOOLCHAIN AUTO-DETECTION
###############################################################################
setup_toolchain() {
  log_info "Detecting toolchain..."

  # --- Clang detection ---
  # Priority: custom dir → unwrapped system clang → versioned wrappers
  #
  # NixOS ships a "clang-wrapper" that explicitly refuses cross-compilation
  # to a different target (--target=aarch64-linux-gnu on an x86_64 host)
  # and prints "cc-wrapper is not designed with multi-target compilers in
  # mind".  For kernel cross-builds we need the *unwrapped* clang binary,
  # obtained via --print-prog-name=clang.
  CLANG_BIN=""
  for candidate in \
    "${HOME}/toolchains/clang/bin" \
    "$(dirname "$(command -v clang-19 2>/dev/null)" 2>/dev/null)" \
    "$(dirname "$(command -v clang-20 2>/dev/null)" 2>/dev/null)" \
    "$(dirname "$(command -v clang-18 2>/dev/null)" 2>/dev/null)" \
    "$(dirname "$(command -v clang 2>/dev/null)" 2>/dev/null)"; do
    [ -n "$candidate" ] && [ -d "$candidate" ] && \
      { CLANG_BIN="$candidate"; break; }
  done

  [ -z "$CLANG_BIN" ] && log_error "No clang found. Install clang-19 or set HOME/toolchains/clang."

  export PATH="${CLANG_BIN}:${PATH}"

  CLANG_EXEC="$(ls "${CLANG_BIN}"/clang* 2>/dev/null | grep -E 'clang(-[0-9]+)?$' | head -1)"
  [ -z "$CLANG_EXEC" ] && CLANG_EXEC="clang"

  # Resolve the real (unwrapped) binary so cross-compilation works on NixOS.
  CLANG_REAL="$("${CLANG_EXEC}" --print-prog-name=clang 2>/dev/null || true)"
  if [ -x "${CLANG_REAL}" ] && [ "${CLANG_REAL}" != "${CLANG_EXEC}" ]; then
    log_info "Using unwrapped clang for cross-compilation: ${CLANG_REAL}"
    # Prepend the unwrapped clang's bin dir so llvm-* tools are also unwrapped.
    UNWRAPPED_BIN="$(dirname "${CLANG_REAL}")"
    export PATH="${UNWRAPPED_BIN}:${PATH}"
    CLANG_EXEC="${CLANG_REAL}"
  fi
  CLANG_BASENAME="$(basename "${CLANG_EXEC}")"

  CLANG_VER="$("${CLANG_EXEC}" --version 2>/dev/null | head -1 || echo 'unknown')"
  log_info "Clang: ${CLANG_VER}"

  # --- Cross-compiler detection ---
  # Verify each candidate prefix actually has a gcc binary before accepting it.
  CROSS=""
  for pfx in \
    "${HOME}/toolchains/gcc/aarch64-linux-android-4.9/bin/aarch64-linux-android-" \
    "$(command -v aarch64-linux-gnu-gcc 2>/dev/null | sed 's/gcc$//')" \
    "$(command -v aarch64-linux-android-gcc 2>/dev/null | sed 's/gcc$//')"; do
    [ -n "$pfx" ] && [ -x "${pfx}gcc" ] && { CROSS="$pfx"; break; }
  done

  CROSS32=""
  for pfx in \
    "${HOME}/toolchains/gcc/arm-linux-androideabi-4.9/bin/arm-linux-androideabi-" \
    "$(command -v arm-linux-gnueabihf-gcc 2>/dev/null | sed 's/gcc$//')" \
    "$(command -v arm-linux-androideabi-gcc 2>/dev/null | sed 's/gcc$//')"; do
    [ -n "$pfx" ] && [ -x "${pfx}gcc" ] && { CROSS32="$pfx"; break; }
  done

  log_info "CROSS_COMPILE  : ${CROSS:-none (LLVM-only mode)}"
  log_info "CROSS_COMPILE_ARM32: ${CROSS32:-none}"

  # --- Export Make variables ---
  export CROSS_COMPILE="${CROSS:-aarch64-linux-gnu-}"
  export CROSS_COMPILE_ARM32="${CROSS32:-arm-linux-gnueabihf-}"

  # LLVM=1 tells the kernel Makefile to use clang/lld/llvm-ar etc.
  # HOSTCC: use gcc for host tools (fixdep, etc.) — gcc carries the glibc
  # sysroot in Nix/NixOS; clang alone does not find sys/types.h there.
  HOSTCC_BIN="$(command -v gcc 2>/dev/null || echo gcc)"

  # NixOS ships clang builtin headers (stdarg.h etc.) inside the *wrapper*
  # package's resource-root, not inside the raw clang store path.  When we
  # use the raw (unwrapped) clang as CC, we must tell it where to find those
  # headers via -resource-dir; otherwise target-side files such as
  # scripts/mod/devicetable-offsets.s fail with 'stdarg.h not found'.
  # We detect it from the wrapper's --print-resource-dir (the wrapper knows
  # where its resource-root is even if the raw binary does not).
  WRAPPER_CLANG="$(command -v clang 2>/dev/null || true)"
  CLANG_RESOURCE_FLAGS=""
  if [ -n "${WRAPPER_CLANG}" ]; then
    WRAPPER_RDIR="$("${WRAPPER_CLANG}" --print-resource-dir 2>/dev/null || true)"
    if [ -f "${WRAPPER_RDIR}/include/stdarg.h" ]; then
      CLANG_RESOURCE_FLAGS="-resource-dir ${WRAPPER_RDIR}"
      log_info "Clang resource dir: ${WRAPPER_RDIR}"
    fi
  fi

  MAKE_FLAGS=(
    O="${OUT_DIR}"
    ARCH="${ARCH}"
    SUBARCH="${SUBARCH}"
    LLVM=1
    LLVM_IAS=1
    CC="${CLANG_BASENAME}"
    HOSTCC="${HOSTCC_BIN}"
    LD=ld.lld
    AR=llvm-ar
    NM=llvm-nm
    OBJCOPY=llvm-objcopy
    OBJDUMP=llvm-objdump
    STRIP=llvm-strip
    # Pin the clang target triple to aarch64-linux-gnu so the kernel uses
    # --target=aarch64-linux-gnu (not android) in all CC invocations.
    CLANG_TRIPLE=aarch64-linux-gnu-
    CROSS_COMPILE="${CROSS_COMPILE}"
    CROSS_COMPILE_ARM32="${CROSS_COMPILE_ARM32}"
    -j"${JOBS}"
  )

  # Append resource-dir flag so all target-side CC calls can find builtins.
  [ -n "${CLANG_RESOURCE_FLAGS}" ] && \
    MAKE_FLAGS+=( KCFLAGS="${CLANG_RESOURCE_FLAGS}" )

  log_success "Toolchain ready."
}

###############################################################################
# VDSO32 CLANG FIX
# Clang 19+ may emit -fzero-call-used-regs=used-gpr which breaks ARM32 VDSO.
# Patch the ARM VDSO Makefile to strip that flag if not already patched.
###############################################################################
apply_vdso32_fix() {
  local VDSO_MK="${KERNEL_DIR}/arch/arm/vdso/Makefile"
  if [ -f "$VDSO_MK" ] && ! grep -q "zero-call-used-regs" "$VDSO_MK"; then
    log_info "Applying VDSO32 Clang 19 compatibility fix..."
    sed -i 's/^ccflags-y :=.*/# FogOS clang fix: strip -fzero-call-used-regs\nKBUILD_CFLAGS := $(filter-out -fzero-call-used-regs=%,$(KBUILD_CFLAGS))\n\0/' \
      "$VDSO_MK" 2>/dev/null || true

    # Explicit approach: prepend the filter line
    if ! grep -q "filter-out -fzero-call-used-regs" "$VDSO_MK"; then
      sed -i '1a # FogOS: strip clang 19 flag incompatible with ARM32 VDSO\nKBUILD_CFLAGS := $(filter-out -fzero-call-used-regs=%,$(KBUILD_CFLAGS))\nccflags-y := $(filter-out -fzero-call-used-regs=%,$(KBUILD_CFLAGS))' \
        "$VDSO_MK" 2>/dev/null || true
    fi
    log_success "VDSO32 fix applied."
  fi
}

###############################################################################
# CLEAN
###############################################################################
do_clean() {
  log_info "Cleaning output directory..."
  rm -rf "${OUT_DIR}"
  # Remove the specific generated files the kernel's outputmakefile check
  # looks for in the source root.  Running full 'mrproper' on a large tree
  # can take minutes; targeted deletion is instant and sufficient.
  rm -f  "${KERNEL_DIR}/.config"
  rm -f  "${KERNEL_DIR}/scripts/basic/fixdep"
  rm -rf "${KERNEL_DIR}/include/generated"
  rm -rf "${KERNEL_DIR}/include/config"
  log_success "Clean done."
}

###############################################################################
# MENUCONFIG
###############################################################################
do_menuconfig() {
  mkdir -p "${OUT_DIR}"
  make "${MAKE_FLAGS[@]}" "${BASE_DEFCONFIG}"
  make "${MAKE_FLAGS[@]}" menuconfig
}

###############################################################################
# BUILD
###############################################################################
build_kernel() {
  log_info "Starting FogOS Extreme Gaming Kernel build..."
  log_info "  Defconfig : ${BASE_DEFCONFIG}"
  log_info "  Fragment  : ${GAMING_FRAGMENT}"
  log_info "  Jobs      : ${JOBS}"
  log_info "  Output    : ${OUT_DIR}"

  mkdir -p "${OUT_DIR}"

  # Step 1: Apply base defconfig
  log_info "Applying base defconfig: ${BASE_DEFCONFIG}"
  make "${MAKE_FLAGS[@]}" "${BASE_DEFCONFIG}"

  # Step 2: Merge gaming fragment if it exists
  if [ -f "${GAMING_FRAGMENT}" ]; then
    log_info "Merging gaming fragment: fogos_gaming.config"
    # Use kernel's merge_config.sh
    MERGE_SCRIPT="${KERNEL_DIR}/scripts/kconfig/merge_config.sh"
    if [ -f "$MERGE_SCRIPT" ]; then
      # -O "${OUT_DIR}" keeps the merged .config inside out/ so the source
      # root stays clean (required for O=out builds; see outputmakefile check).
      ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" \
        bash "$MERGE_SCRIPT" -m -O "${OUT_DIR}" "${OUT_DIR}/.config" "${GAMING_FRAGMENT}"
      # Regenerate from merged .config
      make "${MAKE_FLAGS[@]}" olddefconfig
    else
      # Fallback: append fragment lines and run olddefconfig
      grep -v "^#" "${GAMING_FRAGMENT}" >> "${OUT_DIR}/.config"
      make "${MAKE_FLAGS[@]}" olddefconfig
    fi
    log_success "Gaming config merged."
  else
    log_warn "Gaming fragment not found at ${GAMING_FRAGMENT} — using base config only."
    make "${MAKE_FLAGS[@]}" olddefconfig
  fi

  # Step 3: Compile
  log_info "Compiling kernel (${JOBS} jobs)..."
  make "${MAKE_FLAGS[@]}" Image Image.gz Image.lz4 2>&1 || \
    make "${MAKE_FLAGS[@]}" Image 2>&1

  # Step 4: Build DTBs (non-fatal — Moto overlay check may fail in CI)
  log_info "Building device tree blobs..."
  make "${MAKE_FLAGS[@]}" dtbs 2>&1 || true

  # Step 5: Verify output
  KERNEL_OUT=""
  for img in \
    "${OUT_DIR}/arch/arm64/boot/Image" \
    "${OUT_DIR}/arch/arm64/boot/Image.gz" \
    "${OUT_DIR}/arch/arm64/boot/Image.lz4" \
    "${OUT_DIR}/arch/arm64/boot/Image.gz-dtb"; do
    [ -f "$img" ] && { KERNEL_OUT="$img"; break; }
  done

  [ -z "$KERNEL_OUT" ] && log_error "Kernel image not found after build!"

  KERNEL_SIZE=$(du -sh "$KERNEL_OUT" | cut -f1)
  log_success "Kernel built: ${KERNEL_OUT} (${KERNEL_SIZE})"
}

###############################################################################
# PACKAGE AnyKernel3 ZIP
###############################################################################
package_zip() {
  log_info "Packaging AnyKernel3 ZIP..."
  mkdir -p "${ZIP_DIR}"

  # Copy kernel image(s) into anykernel dir
  for img in \
    "${OUT_DIR}/arch/arm64/boot/Image" \
    "${OUT_DIR}/arch/arm64/boot/Image.gz" \
    "${OUT_DIR}/arch/arm64/boot/Image.lz4" \
    "${OUT_DIR}/arch/arm64/boot/Image.gz-dtb"; do
    [ -f "$img" ] && cp "$img" "${ANYKERNEL_DIR}/" && break
  done

  # Copy DTBs
  mkdir -p "${ANYKERNEL_DIR}/dtbs"
  find "${OUT_DIR}/arch/arm64/boot/dtbs" \
       \( -name "*holi*" -o -name "*sm6375*" -o -name "*moto*" \) \
       -exec cp {} "${ANYKERNEL_DIR}/dtbs/" \; 2>/dev/null || true

  # Build ZIP
  cd "${ANYKERNEL_DIR}"
  zip -r9 "${ZIP_DIR}/${ZIP_NAME}" \
    anykernel.sh fogos_gaming_init.sh META-INF \
    dtbs Image* tools 2>/dev/null || \
  zip -r9 "${ZIP_DIR}/${ZIP_NAME}" . --exclude="*.log" 2>/dev/null

  cd "${KERNEL_DIR}"
  log_success "ZIP: ${ZIP_DIR}/${ZIP_NAME}"
}

###############################################################################
# SUMMARY
###############################################################################
print_summary() {
  echo ""
  echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║   FogOS Extreme Gaming Kernel v2.0 — BUILD DONE!    ║${NC}"
  echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
  echo -e "${GREEN}║  Device  : Motorola G45 (SM6375 / Holi)             ║${NC}"
  echo -e "${GREEN}║  Dev     : Prince (VirgoYT707)                      ║${NC}"
  echo -e "${GREEN}║  Base    : Linux 5.4.302 · Android 16               ║${NC}"
  echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
  echo -e "${GREEN}║  Output:                                             ║${NC}"
  echo -e "${GREEN}║  • ${ZIP_DIR}/${ZIP_NAME}  ${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${CYAN}Flash with TWRP: Install → ${ZIP_NAME}${NC}"
  echo -e "${CYAN}Or use: bash scripts/create_bootimg.sh stock_boot.img ${NC}"
  echo ""
}

###############################################################################
# ENTRY POINT
###############################################################################
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       FogOS Extreme Gaming Kernel Builder v2.0       ║${NC}"
echo -e "${CYAN}║   Motorola G45 (SM6375/Holi) · Developer: VirgoYT   ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

setup_toolchain
apply_vdso32_fix

$DO_CLEAN && do_clean

if $DO_MENUCONFIG; then
  do_menuconfig
  exit 0
fi

build_kernel
package_zip
print_summary
