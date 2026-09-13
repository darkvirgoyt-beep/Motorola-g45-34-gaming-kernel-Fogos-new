# FogOS Gaming Kernel — Prepared Release

## Stability and touchscreen fixes

This release removes unsupported 1000 Hz touchscreen device-tree properties that were never consumed by either touchscreen driver. It also keeps the Holi device-tree `spi-max-frequency` value effective across Ilitek probe, reset, and recovery instead of overwriting it with the legacy 9 MHz compile-time value. The 16 MHz setting is still subject to the SPI controller and panel hardware limits.

## Performance profile

The built-in `/dev/fogos_profile` endpoint now starts in `performance` mode. Profile changes remain restricted to `balanced`, `performance`, and `extreme_gaming`; thermal mitigation, voltage safety, and throttling remain active. The custom Holi CPU/GPU maximum tables remain present, with CPU values of 2592 MHz at 1.080 V for the 2-core cluster and 2208 MHz at 1.020 V for the 6-core cluster, plus the 1050 MHz GPU top level. These values require device-level validation because this sandbox cannot flash or thermally test the phone.

## Control app and Magisk bridge

The companion app now uses the Magisk bridge at `/data/adb/modules/fogos-control/action.sh` for actual profile reads and writes, with direct device access retained only as a fallback. The module selects performance at boot unless the user has stored another validated profile.

## Validation

The Magisk archive passed `unzip -t`, both shell scripts passed `sh -n`, the changed tree passed `git diff --check`, and the Android debug APK built successfully with Gradle and API 35. The kernel repository's latest GitHub Actions runs were green before these changes. A complete kernel image build and phone boot/thermal validation still need to run in GitHub Actions and on the target device.
