# FogOS profile bridge runtime service

Install this directory as a trusted root module payload so `service.sh` runs after boot. The Kotlin FogOS Control app is non-root: it writes only a validated profile name to `/dev/fogos_profile`. This service watches that device and applies the corresponding CPU, GPU, scheduler, VM/I/O, touch, and thermal-safe settings through `profile_manager.sh`.

## Profiles

The kernel driver accepts only these values:

```sh
printf 'balanced\n' > /dev/fogos_profile
printf 'performance\n' > /dev/fogos_profile
printf 'extreme_gaming\n' > /dev/fogos_profile
```

For trusted maintenance shells, the legacy state file remains available:

```sh
echo balanced > /data/local/fogos_profile
sh /data/adb/modules/fogos/profile_manager.sh
```

The AnyKernel packaging script copies this directory into the FogOS Magisk module when Magisk is detected. On a ROM without Magisk, run `service.sh` from an equivalent trusted system service or init stage. The Android app must not be granted root and must not be changed to call `su`.

## Thermal policy

Thermal zones remain enabled. `FOGOS_SAFE_THERMAL_LIMIT_MILLIC` defaults to `90000` in `config.sh`; this caps writable trip-point raises at 90°C while keeping emergency platform protection active.

## Logs

Runtime logs are written to `/data/local/fogos/fogos.log`.
