#!/usr/bin/env bats
#
# Unit tests for build_fogos.sh (host build script).
# Covers: parse_args, select_defconfig, log_* helpers, setup_toolchain.

load helpers/common

setup() {
  REPO_ROOT="$(fogos_repo_root)"
  FOGOS_TMP="$(fogos_mktemp_dir)"
  fogos_init_mocks
  export FOGOS_LIB_ONLY=1
  # Source only the function definitions (guard skips the build entry point).
  source "${REPO_ROOT}/build_fogos.sh"
}

teardown() {
  fogos_cleanup
}

# ---------------------------------------------------------------------------
# parse_args
# ---------------------------------------------------------------------------
@test "parse_args defaults to all flags off" {
  parse_args
  [ "$DO_CLEAN" = false ]
  [ "$DO_MENUCONFIG" = false ]
  [ "$CI_MODE" = false ]
}

@test "parse_args recognises --clean, --menuconfig and --ci" {
  parse_args --clean --menuconfig --ci
  [ "$DO_CLEAN" = true ]
  [ "$DO_MENUCONFIG" = true ]
  [ "$CI_MODE" = true ]
}

@test "parse_args ignores unknown flags" {
  parse_args --frobnicate
  [ "$DO_CLEAN" = false ]
}

@test "parse_args --help prints usage and returns 2" {
  run parse_args --help
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage:"* ]]
}

# ---------------------------------------------------------------------------
# select_defconfig
# ---------------------------------------------------------------------------
@test "select_defconfig prefers vendor/fogos_defconfig" {
  KERNEL_DIR="$FOGOS_TMP"
  mkdir -p "${FOGOS_TMP}/arch/arm64/configs/vendor"
  touch "${FOGOS_TMP}/arch/arm64/configs/vendor/fogos_defconfig"
  touch "${FOGOS_TMP}/arch/arm64/configs/vendor/holi-qgki_defconfig"
  [ "$(select_defconfig)" = "vendor/fogos_defconfig" ]
}

@test "select_defconfig falls back to holi-qgki when fogos is absent" {
  KERNEL_DIR="$FOGOS_TMP"
  mkdir -p "${FOGOS_TMP}/arch/arm64/configs/vendor"
  touch "${FOGOS_TMP}/arch/arm64/configs/vendor/holi-qgki_defconfig"
  [ "$(select_defconfig)" = "vendor/holi-qgki_defconfig" ]
}

@test "select_defconfig falls back to plain defconfig when neither exists" {
  KERNEL_DIR="$FOGOS_TMP"
  mkdir -p "${FOGOS_TMP}/arch/arm64/configs/vendor"
  [ "$(select_defconfig)" = "defconfig" ]
}

# ---------------------------------------------------------------------------
# logging helpers
# ---------------------------------------------------------------------------
@test "log_info emits its message" {
  run log_info "detecting toolchain"
  [ "$status" -eq 0 ]
  [[ "$output" == *"detecting toolchain"* ]]
}

@test "log_error emits its message and exits non-zero" {
  run log_error "no clang found"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no clang found"* ]]
}

# ---------------------------------------------------------------------------
# setup_toolchain
# ---------------------------------------------------------------------------
@test "setup_toolchain succeeds and defaults CROSS_COMPILE in LLVM-only mode" {
  export HOME="$FOGOS_TMP"   # no ~/toolchains
  mock_cmd clang 'case "$*" in
      *--version*)              echo "clang version 19.0.0" ;;
      *--print-prog-name=clang*) echo "clang" ;;
      *--print-resource-dir*)   echo "" ;;
    esac'
  run setup_toolchain
  [ "$status" -eq 0 ]
  [[ "$output" == *"Toolchain ready."* ]]
  [[ "$output" == *"none (LLVM-only mode)"* ]]
}
