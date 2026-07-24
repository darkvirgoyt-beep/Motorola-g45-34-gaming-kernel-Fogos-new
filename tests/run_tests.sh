#!/usr/bin/env bash
###############################################################################
# FogOS shell unit-test runner
#
# Runs the bats test suite for the FogOS custom shell scripts.
#
#   ./tests/run_tests.sh            # run every *.bats file
#   ./tests/run_tests.sh game_detector.bats
#
# Requires `bats` (bats-core). On Debian/Ubuntu: sudo apt-get install -y bats
###############################################################################
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"

if ! command -v bats >/dev/null 2>&1; then
  echo "error: 'bats' is not installed." >&2
  echo "  Debian/Ubuntu : sudo apt-get install -y bats" >&2
  echo "  macOS         : brew install bats-core" >&2
  echo "  From source   : https://github.com/bats-core/bats-core" >&2
  exit 127
fi

if [ "$#" -gt 0 ]; then
  exec bats "$@"
fi

exec bats "${TESTS_DIR}"/*.bats
