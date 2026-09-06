# FogOS flagship-performance plan

## Executive summary

The Moto G45/G34 uses Qualcomm SM6375/Holi hardware. A kernel cannot create flagship-class silicon performance, guarantee zero lag, or deliver a fixed “10x” improvement. The practical target is **stable frame pacing, low wake-up latency, predictable thermal behavior, and preserved Android vendor compatibility**.

The current FogOS tree already contains the most important safe foundations: preemptible scheduling, WALT integration, utilization clamping, schedutil, zram, FQ/BBR networking, Clang LTO/CFI, and a bounded `/dev/fogos_profile` latency hint. The changes in this branch make those assumptions enforceable in CI rather than adding unsafe frequency or voltage hacks.

## Recommended worklist

| Area | Recommendation | Status and safety boundary |
|---|---|---|
| Scheduling | Keep preemption, WALT, schedutil, and uclamp. Use top-app/task-group policy from userspace. | Already present; do not replace with FIFO/RT scheduling. |
| CPU/GPU clocks | Use only firmware-reported OPPs and stock governors. | Do not add invented bins, voltage tables, or overclocking. |
| Thermal control | Keep all thermal zones, cooling devices, and emergency shutdown paths active. | Mandatory for sustained gaming and battery safety. |
| Memory | Keep zram and zsmalloc; validate the Android userspace zram policy on-device. | Do not force aggressive swap or LMK values in the kernel. |
| Storage | Use the device's supported blk-mq scheduler and measure fsync/latency before changing it. | Do not force a scheduler globally without a workload trace. |
| Network | Keep FQ and BBR/BBRPLUS as selectable options; choose through measured userspace policy. | Network congestion control cannot fix radio latency or server tick rate. |
| Input/display | Validate touch IRQ latency, SurfaceFlinger frame deadlines, and refresh-rate policy. | These are usually device/vendor/userspace controls, not kernel overclocking. |
| ABI/security | Preserve vendor_dlkm module modes, AVB expectations, CFI, LTO, and SELinux policy. | A booting kernel that breaks camera, audio, Dolby, or charging is not an improvement. |
| Observability | Record Perfetto, frame-time percentiles, thermal headroom, and battery drain for every profile. | Required before claiming an improvement. |

## What this branch changes

The branch adds a release-config contract validator and a CI test for it. The validator checks the configuration that is actually shipped, including preemption, WALT/uclamp, schedutil, zram, FQ/BBR, CFI/LTO, FogOS profile support, and the absence of KernelSU or unsafe thermal/clock bypass symbols. It is intentionally a guardrail: it does not silently rewrite configuration values.

## Device test protocol

Use the same game build, resolution, refresh-rate mode, battery range, ambient temperature, and Android background state for each comparison. Capture at least 10 minutes per profile and report p50/p95/p99 frame time, missed-frame count, sustained CPU/GPU clocks, skin/battery temperature, battery drain per hour, and network RTT/jitter. Compare `balanced`, `performance`, and `extreme_gaming`; revert if the latter increases throttling or frame-time variance.

A responsible release claim is “validated for stable frame pacing on the tested build.” Claims such as “1000% lag-free,” “10x faster,” or “never heats” are not technically supportable without repeatable measurements and are not made by this project.

## Compatibility checklist

Before flashing, confirm the exact Android build and vendor_dlkm set. Boot the matching image temporarily first, then test camera, audio/Dolby, charging, Wi-Fi, Bluetooth, fingerprint, sensors, touch, reboot, OTA/slot behavior, and a sustained thermal run. Keep an original boot image and an unmodified active slot available for recovery.
