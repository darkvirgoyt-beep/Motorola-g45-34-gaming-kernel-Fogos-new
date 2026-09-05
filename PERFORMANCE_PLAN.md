# VirgoYT FogOS Performance Plan

## Scope

This plan targets the Motorola G45/G34 Holi platform and the existing FogOS/Evolution X Android 17 vendor configuration. It is intended to improve responsiveness and frame-time consistency without breaking vendor modules, audio, touch, radio, verified boot, or thermal protection.

The plan does **not** promise a 10x speedup, zero frame drops, unlimited FPS, a fixed 1 Gb/s Internet rate, or identical results across ROMs. Those outcomes depend on the physical device, vendor firmware, game build, network, temperature, and measurement method.

## Already implemented

The current FogOS build contains BBRplus as the default TCP congestion controller and `fq` as the default pacing scheduler. It also contains the bounded FogOS profile interface, which applies a CPU-idle latency quality-of-service hint for `performance` and `extreme_gaming` and restores stock idle behavior for `balanced`.

The current build preserves the stock Holi vendor-module ABI and Android thermal framework. It does not force CPU/GPU frequencies, change voltage tables, bypass thermal cooling maps, or use unrestricted root runtime scripts.

## Next iteration: evidence-led work

First capture a baseline on the exact phone and ROM: sustained BGMI FPS and frame-time variance, touch-to-render latency, gyro event rate, CPU/GPU residency, modem/Wi-Fi throughput and RTT, battery drain, skin temperature, thermal throttling events, audio underruns, and boot time. Repeat each test at least three times under the same graphics, network, brightness, and ambient-temperature conditions.

Then inspect the live device interfaces before changing code. Record the available cpufreq policies and OPP limits, schedutil rate-limit attributes, UCLAMP groups, KGSL/devfreq governors, thermal zones and cooling maps, touch report rate, IIO gyro/accelerometer channels, audio/ALSA devices, charging-current/voltage limits, and active vendor modules. A node must be present, writable, and semantically understood before it can be used.

Candidate changes are limited to measured improvements that remain inside stock policy bounds: schedutil transition responsiveness, top-app UCLAMP hints through the existing Android framework, GPU devfreq governor selection when the vendor exposes a supported governor, queue and VM settings when profiling proves an I/O bottleneck, and bounded FogOS profile behavior. Each candidate must include a rollback path and before/after measurements.

Game-specific behavior belongs in Android GameManager, Power HAL, ADPF, or the FogOS companion rather than in arbitrary kernel code. Bullet registration, aim sensitivity, recoil, gyro sensitivity, touch sampling, animation removal, render pipeline behavior, and game networking are not generic Linux kernel features. They require the game, framework, vendor HAL, or input/display stack and must not be faked by changing unrelated kernel knobs.

Charging must remain controlled by the PMIC, battery gauge, charger IC, USB-PD/QC negotiation, and vendor charging policy. The kernel cannot safely turn a device into an 18 W or higher charger by changing a single setting. Any charging change requires the exact board schematic, battery rating, charger IC limits, thermal validation, and vendor safety policy.

## Explicit exclusions

Do not raise thermal trip points to 95°C or 125°C as a gaming optimization, disable thermal cooling, lock every CPU/GPU policy at maximum, add an unverified overclock, force RT priority for a game, disable power collapse, or remove audio/touch/radio vendor modules. Those changes can cause instability, excessive battery drain, component stress, input/audio faults, or a non-booting device, and the supplied AOSP references do not justify them.

Do not remove Linux, Android, Qualcomm, vendor, or third-party source attribution. VirgoYT/FogOS project credits can be added, but legally required upstream notices and SPDX/GPL information must remain.

## Validation gates for the next build

A change is accepted only if the kernel builds with the FogOS script, the compatibility suite passes, the merged configuration retains the vendor module ABI, the device boots and can return to the balanced profile, and controlled testing shows an improvement without a regression in thermal behavior, audio, touch, gyro, radio, charging, suspend, or battery drain.

## Reusable build prompt

> Audit the Motorola G45/G34 Holi FogOS Linux 5.4.302 tree and VirgoYT-Hermes references. Do not copy generic Android tweaker scripts or invent device values. Preserve vendor module ABI, AVB, audio, touch, gyro, radio, charger, and thermal safety. Measure current behavior first, inspect live cpufreq/UCLAMP/KGSL/input/audio/thermal nodes, and implement only source-backed, bounded changes that improve measured frame-time variance or responsiveness. Keep BBRplus plus fq for TCP pacing. Do not bypass thermal protection, add an unverified overclock, lock all frequencies, force RT game priority, alter charging limits, or claim zero drops/10x performance. Build with `build_fogos.sh --ci`, run the compatibility tests, report exact artifacts, hashes, warnings, and before/after benchmark data.
