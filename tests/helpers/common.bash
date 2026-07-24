# Shared helpers for the FogOS shell unit-test suite (bats).
#
# These helpers let the .bats files source the FogOS scripts with
# FOGOS_LIB_ONLY=1 (so only function definitions load, no side effects) and
# stub out external commands (pgrep, taskset, dumpsys, clang, ...) so the
# pure logic can be exercised deterministically on a normal Linux host.

# Absolute path to the repository root (parent of the tests/ directory).
fogos_repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

# Create a throwaway directory that is removed in teardown.
fogos_mktemp_dir() {
  mktemp -d "${BATS_TMPDIR:-/tmp}/fogos.XXXXXX"
}

# Prepare an isolated directory of mock executables and put it first on PATH.
# Call once in setup(); every mock_cmd afterwards lands in this dir.
fogos_init_mocks() {
  MOCK_BIN="$(fogos_mktemp_dir)"
  MOCK_LOG="${MOCK_BIN}/.calls.log"
  : > "$MOCK_LOG"
  PATH="${MOCK_BIN}:${PATH}"
  export PATH MOCK_BIN MOCK_LOG
}

# mock_cmd <name> [body]
# Registers an executable <name> on PATH. Every invocation appends
# "<name> <args...>" to $MOCK_LOG. If <body> is given it becomes the mock's
# behaviour (has access to "$@"); otherwise the mock just succeeds.
mock_cmd() {
  local name="$1"; shift
  local body="${1:-true}"
  {
    echo '#!/usr/bin/env bash'
    echo "echo \"${name} \$*\" >> \"${MOCK_LOG}\""
    echo "${body}"
  } > "${MOCK_BIN}/${name}"
  chmod +x "${MOCK_BIN}/${name}"
}

# Assert that $MOCK_LOG recorded a call whose line matches the given regex.
assert_called() {
  local pattern="$1"
  grep -Eq "$pattern" "$MOCK_LOG"
}

# Assert that no recorded call matches the given regex.
refute_called() {
  local pattern="$1"
  ! grep -Eq "$pattern" "$MOCK_LOG"
}

# Remove the mock/temp directories created during a test.
fogos_cleanup() {
  [ -n "${MOCK_BIN:-}" ] && rm -rf "$MOCK_BIN"
  [ -n "${FOGOS_TMP:-}" ] && rm -rf "$FOGOS_TMP"
}
