# FogOS Control

**Canonical controller source:** [FogOS PulseControl](https://github.com/darkvirgoyt-beep/FogOS-PulseControl)
**Kernel integration:** [Motorola G45/G34 FogOS Gaming Kernel](https://github.com/darkvirgoyt-beep/Motorola-g45-34-gaming-kernel-Fogos-new/tree/sixteen-qpr2)

FogOS Control is a Kotlin Android companion application for the FogOS kernel. It changes profiles without calling `su`, launching a shell, or writing arbitrary kernel paths. The app reads and writes only `/dev/fogos_profile`, which accepts `balanced`, `performance`, and `extreme_gaming`.

## Important deployment requirement

This is a **non-root app**, not an ordinary unprivileged APK. The ROM must install the platform-signed package `com.fogos.control` as a privileged system application and assign it the `fogos_app` SELinux domain. Merge the policy snippets under `../sepolicy/fogos/` into the ROM policy. Flashing the kernel without the matching ROM-side device label and SELinux mapping will make the app show “Connection unavailable,” by design.

The kernel driver applies the selected profile directly. `performance` and `extreme_gaming` add a bounded CPU-idle latency quality-of-service request, while `balanced` removes that request and restores stock idle behavior. The driver does not alter CPU/GPU frequencies, voltages, scheduler tunables, VM/I/O values, touch settings, thermal zones, charging limits, or AVB state; Android and Motorola thermal protection remain active in every profile.

## Build

From the repository root, use a JDK supported by Android Gradle Plugin 8.x and run:

```sh
gradle -p fogos-control assembleDebug
```

The repository workflow `.github/workflows/fogos-control.yml` builds the debug APK and uploads it as an artifact on pushes that change the app or its policy documentation. For a production package, sign the APK with the same platform key used by the target ROM and install it under `system/priv-app/FogOSControl/`.

## Supported profiles

| Profile | Kernel request | Runtime behavior |
|---|---|---|
| Balanced | `balanced` | Removes the FogOS latency request and restores stock CPU-idle behavior. |
| Performance | `performance` | Applies a 1000 microsecond CPU-idle latency cap for improved wake-up responsiveness. |
| Extreme gaming | `extreme_gaming` | Applies a 500 microsecond CPU-idle latency cap for the strongest supported FogOS latency hint. |

The application intentionally does not expose raw frequency, thermal-trip, scheduler, sysctl, voltage, or charging sliders. That keeps the kernel interface bounded and lets the driver reject unsupported values safely.
