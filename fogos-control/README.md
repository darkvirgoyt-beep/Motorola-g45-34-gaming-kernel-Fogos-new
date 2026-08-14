# FogOS Control

**Canonical controller source:** [FogOS PulseControl](https://github.com/darkvirgoyt-beep/FogOS-PulseControl)
**Kernel integration:** [Motorola G45/G34 FogOS Gaming Kernel](https://github.com/darkvirgoyt-beep/Motorola-g45-34-gaming-kernel-Fogos-new/tree/sixteen-qpr2)

FogOS Control is a Kotlin Android companion application for the FogOS kernel. It changes profiles without calling `su`, launching a shell, or writing arbitrary kernel paths. The app reads and writes only `/dev/fogos_profile`, which accepts `balanced`, `performance`, and `extreme_gaming`.

## Important deployment requirement

This is a **non-root app**, not an ordinary unprivileged APK. The ROM must install the platform-signed package `com.fogos.control` as a privileged system application and assign it the `fogos_app` SELinux domain. Merge the policy snippets under `../sepolicy/fogos/` into the ROM policy. Flashing the kernel without the matching ROM-side device label and SELinux mapping will make the app show “Connection unavailable,” by design.

The kernel driver stores the selected profile. The trusted FogOS runtime service under `magisk/fogos/` reads the selected value and applies the existing CPU, GPU, scheduler, VM/I/O, touch, and thermal-safe tuning. A ROM without Magisk must run that same manager from an equivalent trusted system service or init stage.

## Build

From the repository root, use a JDK supported by Android Gradle Plugin 8.x and run:

```sh
gradle -p fogos-control assembleDebug
```

The repository workflow `.github/workflows/fogos-control.yml` builds the debug APK and uploads it as an artifact on pushes that change the app or its policy documentation. For a production package, sign the APK with the same platform key used by the target ROM and install it under `system/priv-app/FogOSControl/`.

## Supported profiles

| Profile | Kernel request | Runtime behavior |
|---|---|---|
| Balanced | `balanced` | Normal scheduler, frequency, GPU, I/O, touch, and thermal-safe settings. |
| Performance | `performance` | Higher minimum CPU/GPU operating points and input boost while preserving thermal protection. |
| Extreme gaming | `extreme_gaming` | Strongest validated FogOS gaming tuning, with thermal zones and emergency protection retained. |

The application intentionally does not expose raw frequency, thermal-trip, scheduler, or sysctl sliders. That keeps the kernel interface bounded and allows the runtime service to reject unsupported hardware paths safely.
