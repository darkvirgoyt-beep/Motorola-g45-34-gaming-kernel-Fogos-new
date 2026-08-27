#!/usr/bin/env bats
#
# Unit tests for anykernel3/fogos_gaming_init.sh
# Covers: log, optimize_game (process pinning via mocked userspace tools).

load helpers/common

setup() {
  REPO_ROOT="$(fogos_repo_root)"
  FOGOS_TMP="$(fogos_mktemp_dir)"
  fogos_init_mocks
  export FOGOS_LIB_ONLY=1
  # Source only the function definitions (guard skips the boot sequence).
  source "${REPO_ROOT}/anykernel3/fogos_gaming_init.sh"
}

teardown() {
  fogos_cleanup
}

@test "log echoes a tagged line to stdout" {
  run log "boot step done"
  [[ "$output" == *"[FogOS]"* ]]
  [[ "$output" == *"boot step done"* ]]
}

@test "optimize_game pins a running game to big cores with bounded priority" {
  mock_cmd pgrep 'echo 4242'
  mock_cmd renice
  mock_cmd chrt
  mock_cmd taskset

  run optimize_game "com.pubg.imobile"

  [[ "$output" == *"Optimized: com.pubg.imobile (PID 4242)"* ]]
  assert_called "renice -n -10 -p 4242"
  refute_called "chrt"
  assert_called "taskset -p f0 4242"
}

@test "optimize_game is a no-op when the game is not running" {
  mock_cmd pgrep 'exit 1'
  mock_cmd renice
  mock_cmd chrt
  mock_cmd taskset

  run optimize_game "com.pubg.imobile"

  [ -z "$output" ]
  refute_called "renice"
  refute_called "taskset"
}
