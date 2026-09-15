# FogOS Gaming Optimization Module

This Magisk/KernelSU-compatible module provides a reversible Gaming Mode. It sets each CPU policy to its running kernel's exposed hardware ceiling, selects the `performance` CPU governor when supported, sets the KGSL GPU ceiling to its highest advertised frequency, and selects the GPU `performance` devfreq governor when supported. It does not alter game files, aim behavior, network hit registration, thermal trips, or thermal drivers.

The module starts Gaming Mode at boot. This can cause rapid heating, battery drain, throttling, instability, or rebooting. Use short tests only.

## Termux controls

```sh
su -c /data/adb/modules/fogos-max-frequency/boost.sh status
su -c /data/adb/modules/fogos-max-frequency/boost.sh start
su -c /data/adb/modules/fogos-max-frequency/boost.sh stop
```

`stop` restores the CPU/GPU policy and governor values captured when Gaming Mode started. The KernelSU WebUI provides LOCK MAX, RESTORE, and REFRESH buttons; Magisk users use the commands above or FKM.

This cannot guarantee 120 rendered FPS. The panel refresh rate and game frame rate are separate, and thermal limits remain authoritative.
