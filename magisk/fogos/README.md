# FogOS Magisk / KernelSU / APatch runtime service

Install this directory as a root module payload so `service.sh` runs at boot. The service waits for Android userspace, applies `/data/local/fogos_profile`, and watches foreground apps to switch known games to `extreme_gaming`.

## Profiles

```sh
echo balanced > /data/local/fogos_profile
echo performance > /data/local/fogos_profile
echo extreme_gaming > /data/local/fogos_profile
sh /data/adb/modules/fogos/profile_manager.sh
```

## Thermal policy

Thermal zones remain enabled. `FOGOS_SAFE_THERMAL_LIMIT_MILLIC` defaults to `90000` in `config.sh`; this caps writable trip-point raises at 90°C while keeping emergency platform protection active.

## Logs

Runtime logs are written to `/data/local/fogos/fogos.log`.
