# FogOS Control Bridge

This Magisk module is the privileged bridge for the FogOS profile endpoint. It waits for `/dev/fogos_profile`, selects `performance` by default, and remembers an explicitly selected profile in `/data/adb/fogos-control/profile`.

The companion app must invoke the bridge through Magisk `su` rather than assuming that an ordinary APK can read or write `/dev/fogos_profile`. The only accepted values are `balanced`, `performance`, and `extreme_gaming`; arbitrary shell commands and frequency or voltage writes are not supported.

To package the module, zip the **contents** of this directory so that `module.prop` is at the archive root. Install it from Magisk, reboot once, and verify with:

```sh
su -c /data/adb/modules/fogos-control/action.sh get
su -c '/data/adb/modules/fogos-control/action.sh set performance'
```

The kernel endpoint remains responsible for validating and applying the profile. Thermal throttling and safety limits are not disabled.
