# FogOS Control

Kotlin Android companion app for FogOS. It uses root (`su -c`) to write `/data/local/fogos_profile` and invokes the FogOS profile manager when present under Magisk, KernelSU, APatch-compatible module paths, or `/system/bin`.

## Build

```sh
gradle -p fogos-control assembleDebug
```

The project uses Groovy Gradle scripts so task discovery works on newer host JDKs; use an Android Gradle Plugin supported JDK such as JDK 21 for release builds.
