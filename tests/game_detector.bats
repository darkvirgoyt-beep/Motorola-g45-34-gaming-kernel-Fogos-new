#!/usr/bin/env bats
#
# Unit tests for anykernel3/fogos_game_detector.sh
# Covers: is_game, write, log, truncate_log, get_foreground_app.

load helpers/common

setup() {
  REPO_ROOT="$(fogos_repo_root)"
  FOGOS_TMP="$(fogos_mktemp_dir)"
  fogos_init_mocks
  export FOGOS_LIB_ONLY=1
  # Source only the function definitions (guard skips the daemon loop).
  source "${REPO_ROOT}/anykernel3/fogos_game_detector.sh"
  # Redirect the log target into the throwaway dir.
  LOG="${FOGOS_TMP}/game.log"
  ACTIVE_LOG="${FOGOS_TMP}/active.txt"
}

teardown() {
  fogos_cleanup
}

@test "is_game matches every supported game package" {
  is_game "com.pubg.imobile"
  is_game "com.tencent.ig"
  is_game "com.dts.freefireth"
}

@test "is_game rejects non-game packages" {
  run is_game "com.android.settings"
  [ "$status" -ne 0 ]
}

@test "is_game rejects an empty package name" {
  run is_game ""
  [ "$status" -ne 0 ]
}

@test "is_game does not partial-match a longer package name" {
  run is_game "com.pubg.imobile.extra"
  [ "$status" -ne 0 ]
}

@test "write puts the value into the target file" {
  write "performance" "${FOGOS_TMP}/gov"
  [ "$(cat "${FOGOS_TMP}/gov")" = "performance" ]
}

@test "write reports failure for an unwritable target" {
  run write "1" "/proc/does/not/exist/node"
  [ "$status" -ne 0 ]
}

@test "log appends a timestamped, tagged line to LOG" {
  log "hello world"
  run cat "$LOG"
  [[ "$output" == *"[FogOS-Game]"* ]]
  [[ "$output" == *"hello world"* ]]
}

@test "truncate_log shrinks an oversized log to ~256KiB" {
  head -c 600000 /dev/zero | tr '\0' 'x' > "$LOG"
  truncate_log
  local size
  size=$(wc -c < "$LOG")
  [ "$size" -eq 262144 ]
}

@test "truncate_log leaves a small log untouched" {
  echo "small" > "$LOG"
  run truncate_log
  [ "$(cat "$LOG")" = "small" ]
}

@test "get_foreground_app extracts the package name of the focused window" {
  mock_cmd dumpsys 'case "$1" in
      activity) exit 0 ;;
      window)   echo "  mCurrentFocus=Window{abc123 u0 com.pubg.imobile/com.epicgames.ue4.GameActivity}" ;;
      *)        exit 0 ;;
    esac'
  run get_foreground_app
  [ "$output" = "com.pubg.imobile" ]
}

@test "get_foreground_app returns empty when nothing is focused" {
  mock_cmd dumpsys 'exit 0'
  run get_foreground_app
  [ -z "$output" ]
}
