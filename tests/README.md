# FogOS validation tests

These host-side tests protect the non-stock release logic in this kernel fork. They validate source and packaging contracts; they do not substitute for a physical test on the Motorola G45/G34.

| Component under test | Test file | What is covered |
|---|---|---|
| `build_fogos.sh` | `build_fogos.bats` | Argument parsing, defconfig selection, logging, toolchain setup, and release packaging helpers. |
| Android 17 ABI, rootless installer, PulseControl, boot packer | `compatibility_contract.bats` | Vendor-module modes, stock local-version/CFI/modversion invariants, no KernelSU, no unsafe thermal overlay, active-slot installer, rootless `/dev/fogos_profile` client, bounded kernel latency QoS, no Magisk runtime payload, and the AVB validator gate. |

## Framework

Tests use [bats-core](https://github.com/bats-core/bats-core), the standard unit-testing framework for shell. Host-only tests replace external build tools with lightweight mocks on `PATH` where needed, so the logic runs deterministically without a connected phone.

## Running

```bash
# Install bats (Debian/Ubuntu)
sudo apt-get install -y bats

# Run the whole suite
./tests/run_tests.sh

# Run the core Android 17 safety contract
./tests/run_tests.sh tests/compatibility_contract.bats
```

CI runs the suite automatically via `.github/workflows/tests.yml`. The same workflow builds the `fogos-control` debug APK against Android API 35, preventing silent regressions in the rootless profile client.
