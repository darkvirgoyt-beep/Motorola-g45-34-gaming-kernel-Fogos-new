# FogOS shell unit tests

Unit tests for the custom developer-authored shell scripts in this kernel
fork. These are the only non-stock, self-contained modules in the tree and
previously had **no test coverage**.

| Script under test | Test file | What is covered |
|-------------------|-----------|-----------------|
| `anykernel3/fogos_game_detector.sh` | `game_detector.bats` | `is_game`, `write`, `log`, `truncate_log`, `get_foreground_app` |
| `anykernel3/fogos_gaming_init.sh`   | `gaming_init.bats`   | `log`, `optimize_game` (process pinning / RT priority) |
| `build_fogos.sh`                    | `build_fogos.bats`   | `parse_args`, `select_defconfig`, `log_*`, `setup_toolchain` |

## Framework

Tests use [bats-core](https://github.com/bats-core/bats-core), the standard
unit-testing framework for shell.

Each script is sourced with `FOGOS_LIB_ONLY=1`, a guard that loads **only the
function definitions** and skips the daemon loop / boot sequence / build entry
point. In every normal invocation the variable is unset and the scripts behave
exactly as before. External commands (`pgrep`, `taskset`, `renice`, `chrt`,
`dumpsys`, `clang`, ...) are replaced with lightweight mocks on `PATH` (see
`helpers/common.bash`) so the logic runs deterministically on a plain Linux
host with no device.

## Running

```bash
# Install bats (Debian/Ubuntu)
sudo apt-get install -y bats

# Run the whole suite
./tests/run_tests.sh

# Run a single file
./tests/run_tests.sh tests/game_detector.bats
```

CI runs the suite automatically via `.github/workflows/tests.yml`.
