# FogOS non-root profile control

The kernel driver creates `/dev/fogos_profile`. It accepts only these complete values:

```text
balanced
performance
extreme_gaming
```

The driver is intentionally not a general sysfs or scheduler interface. Profile selection is applied inside the restricted kernel driver as a bounded CPU-idle latency quality-of-service hint: `performance` uses a 1000 microsecond limit and `extreme_gaming` uses a 500 microsecond limit. These hints may improve wake-up responsiveness, but they do not set CPU/GPU frequencies, voltages, scheduler values, thermal trips, charging limits, or AVB state. The Kotlin application never invokes `su` and never writes CPU, GPU, thermal, scheduler, or VM paths directly.

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

## Runtime behavior

No Magisk module, init.d script, background daemon, root shell, or systemless payload is required or shipped. After the platform-signed privileged application writes one validated profile value to `/dev/fogos_profile`, the kernel applies or removes only its own bounded CPU-idle latency request. `balanced` removes the FogOS request and restores stock idle behavior immediately. Android and Motorola thermal mitigation remains authoritative in every profile.

## Device verification

After flashing the kernel and booting the matching ROM, select each profile from the signed FogOS control application and confirm that its read-back succeeds. For trusted development validation, inspect the kernel log after changing a profile:

```sh
cat /dev/fogos_profile
logcat -d | grep -i fogos_profile
```

The application should be installed only after the device node and SELinux mapping are present. A read or write failure in the app means the ROM-side privileged-app integration is incomplete; it is not a reason to weaken SELinux globally.
