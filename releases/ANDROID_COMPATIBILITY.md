# Android 17 Fogos Compatibility Findings

Source review date: 2026-08-22.

The LineageOS `lineage-23.2` Android 17 device tree for Motorola Fogos explicitly adds `vendor/ext_config/moto-holi-fogos.config` through `TARGET_KERNEL_CONFIG`. This confirms the user-provided Fogos configuration fragment remains relevant for current Android 17 device builds.

The Android 17 device tree expects vendor/kernel modules defined in `modules.load` and `modules.load.recovery`. Therefore, an Android 17-compatible kernel release must preserve the exact module ABI and module set; it cannot safely be reduced to a standalone generic `boot.img` generated from kernel source alone.

The device tree declares a July 2026 boot security patch and AVB rollback indexes. A boot image must be packaged with the boot-image parameters, ramdisk, DTB/DTBO, and verified-boot metadata that match the user's exact Evolution X build. The kernel source archive by itself cannot provide those parameters or the matching ramdisk.

References:
- https://github.com/LineageOS/android_device_motorola_fogos/tree/lineage-23.2
- https://raw.githubusercontent.com/LineageOS/android_device_motorola_fogos/lineage-23.2/BoardConfig.mk

Additional verification: The LineageOS Fogos wiki identifies the current `lineage-23.2` branch as Android 16 with Linux 5.4, not Android 17. This means cross-version support cannot be claimed solely from the user-provided `sixteen-qpr2` source. The kernel source can be built as a shared candidate only; a direct `boot.img` still requires the exact boot image and module set from each target ROM build.

Additional source:
- https://wiki.lineageos.org/devices/fogos/variant2/
