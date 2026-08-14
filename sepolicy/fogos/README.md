# FogOS non-root profile control

The kernel driver creates `/dev/fogos_profile`. It accepts only these complete values:

```text
balanced
performance
extreme_gaming
```

The driver is intentionally not a general sysfs or scheduler interface. The existing FogOS runtime service runs with the device's trusted root context, reads the selected value, and applies the profile through the existing `profile_manager.sh`. The Kotlin application never invokes `su` and never writes CPU, GPU, thermal, scheduler, or VM paths directly.

## Required ROM integration

A kernel flash alone is not enough to authorize an ordinary APK. The ROM maintainer must merge the policy snippets in this directory into the device/vendor SELinux policy, install the APK as the platform-signed privileged package `com.fogos.control`, and ensure the package receives the `fogos_app` SELinux domain through the ROM's `seapp_contexts` and `mac_permissions.xml` configuration.

The exact merge locations differ between AOSP, LineageOS, and vendor trees. The required logical rules are:

```text
# file_contexts
/dev/fogos_profile    u:object_r:fogos_profile_device:s0

# ueventd.rc
/dev/fogos_profile    0666    root      root

# fogos_app.te
allow fogos_app fogos_profile_device:chr_file { getattr open read write };
```

The package-to-domain mapping must bind only the signed package to the domain. A representative `seapp_contexts` line is:

```text
user=_app isPrivApp=true seinfo=fogos_app name=com.fogos.control domain=fogos_app type=privapp_data_file levelFrom=user
```

The corresponding `mac_permissions.xml` mapping must set `seinfo="fogos_app"` only for the platform-signed `com.fogos.control` package. Use the syntax required by the target Android release; Android policy XML formats differ between releases.

Do **not** add `sys_admin`, `dac_override`, broad `sysfs` write permissions, or `su` calls. The node uses mode `0666` only so the dedicated SELinux `fogos_app` domain can open it without inheriting root or system UID privileges; the driver validates every value and SELinux is the actual authorization boundary. If the ROM uses a system service instead of direct app access, use a restrictive `0660` owner/group and keep the service as the only client.

## Runtime requirement

The profile manager service must run after boot. The AnyKernel package now includes `magisk/fogos/` and installs the profile bridge into the FogOS Magisk module when Magisk is available. On a ROM without Magisk, the maintainer must run the same `service.sh` from an equivalent trusted system service or init stage. Without this trusted applier, the app can update the kernel's selected value but no CPU/GPU tuning will be applied.

## Device verification

After flashing the kernel and booting the matching ROM, verify from a trusted development shell:

```sh
cat /dev/fogos_profile
printf 'performance\n' > /dev/fogos_profile
cat /dev/fogos_profile
logcat -d | grep -i fogos
```

The application should be installed only after the device node and SELinux mapping are present. A read or write failure in the app means the ROM-side privileged-app integration is incomplete; it is not a reason to weaken SELinux globally.
