# VirgoYT Gaming Kernel — Credits

## Project maintainer

**Prince · VirgoYT707** is the project maintainer and FogOS integration author for the Motorola G45/G34 Holi target. The project branding, device integration, FogOS profile interface, build orchestration, testing, and release packaging are maintained under the VirgoYT/FogOS project identity.

## Kernel and platform sources

This repository is based on the Linux kernel and Android common/vendor kernel work. Existing source-file copyright notices, SPDX identifiers, GPL notices, Qualcomm platform attribution, Android common-kernel attribution, and third-party notices remain part of the source tree and must not be removed when redistributing or modifying the kernel.

The BBRplus implementation is derived from the `UJX6N/bbrplus-5.4` port and its upstream BBRplus contributors. The FogOS tree keeps the applicable GPL licensing and source attribution for that code.

## FogOS work

VirgoYT/FogOS-specific work includes the bounded `fogos_profile` kernel interface, the rootless FogOS Control integration, Motorola G45/G34 configuration fragments, build and compatibility checks, and device-focused documentation. These changes do not claim to provide unlimited FPS, zero frame drops, radio-speed increases, or thermal-limit bypasses.

## Device compatibility

The intended target is the Motorola G45/G34 Holi platform using the matching FogOS/Evolution X vendor configuration. A kernel image must be built and tested against the exact device software, vendor modules, partition layout, boot chain, and AVB configuration before flashing.

## Reporting and benchmarking

Performance claims should be supported by repeatable measurements on the target device. Recommended measurements include sustained FPS and frame-time variance in BGMI, touch/input latency, network throughput and RTT, skin temperature, battery drain, and thermal throttling state. The project does not treat a marketing target as a benchmark result.
