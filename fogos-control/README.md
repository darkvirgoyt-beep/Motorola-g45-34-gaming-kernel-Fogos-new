# FogOS Control

Kotlin Android companion app for FogOS. It uses root (`su -c`) to write `/data/local/fogos_profile` and invokes the FogOS profile manager when present under Magisk, KernelSU, APatch-compatible module paths, or `/system/bin`.

## Build

```sh
gradle -p fogos-control assembleDebug
```

Use JDK 21 or a Kotlin/Gradle-supported JDK if the host defaults to a newer Java feature release.
