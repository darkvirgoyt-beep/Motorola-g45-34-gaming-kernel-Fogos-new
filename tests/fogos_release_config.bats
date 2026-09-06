#!/usr/bin/env bats

load helpers/common

setup() {
  REPO_ROOT="$(fogos_repo_root)"
}

@test "FogOS release defconfig passes the flagship safety contract" {
  local merged
  merged="$(mktemp)"
  cat "${REPO_ROOT}/arch/arm64/configs/vendor/fogos_defconfig" \
    "${REPO_ROOT}/arch/arm64/configs/vendor/fogos_gaming.config" > "$merged"
  run python3 "${REPO_ROOT}/scripts/validate_fogos_release_config.py" "$merged"
  rm -f "$merged"
  [ "$status" -eq 0 ]
  [[ "$output" == *"FogOS release config OK"* ]]
}

@test "validator rejects an unsafe thermal or clock override" {
  local tmp
  tmp="$(mktemp)"
  cp "${REPO_ROOT}/arch/arm64/configs/vendor/fogos_defconfig" "$tmp"
  printf '\nCONFIG_FOGOS_DISABLE_THERMAL=y\nforce_clk_on=1\n' >> "$tmp"
  run python3 "${REPO_ROOT}/scripts/validate_fogos_release_config.py" "$tmp"
  rm -f "$tmp"
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be disabled"* ]]
  [[ "$output" == *"unsafe tuning token"* ]]
}
