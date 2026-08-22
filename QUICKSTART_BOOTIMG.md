# Fogos Kernel Boot-Image Integration

## Scope

This repository can build a Fogos kernel payload (`Image.gz`) and Fogos device-tree outputs. The payload is **not** a standalone Android `boot.img`, and it must not be flashed directly with Fastboot.

> **Never run** `fastboot flash boot Image.gz`, rename `Image.gz` to `boot.img`, or disable Android Verified Boot merely to force an image to flash. A `Preflash validation failed` message means the bootloader rejected the image before writing it.

A flashable Android boot image is specific to the installed ROM build. It must preserve the exact boot header, ramdisk, command line, vendor modules, DTB/DTBO arrangement, and verified-boot metadata expected by that ROM.

## Supported build artifact

Build the Fogos Gaming configuration with:

```bash
make O=out ARCH=arm64 vendor/fogos_gaming_defconfig
make -j"$(nproc)" O=out ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
  KCFLAGS='-Wno-error' Image.gz dtbs
```

The output files are:

| File | Meaning |
|---|---|
| `out/arch/arm64/boot/Image.gz` | Kernel payload. It is not directly flashable. |
| `out/arch/arm64/boot/dts/vendor/qcom/blair-moto-fogos-base.dtb` | Fogos base device tree. |
| `out/arch/arm64/boot/dts/vendor/qcom/blair-fogos-*-overlay.dtbo` | Fogos board overlays. |

## Before creating any boot image

Only proceed when all of the following are true.

1. You have the unmodified `boot.img` from the **same Evolution X build currently installed** on your Fogos device.
2. You have a known-good Fogos-compatible unpack/repack workflow that retains the original boot header and ramdisk.
3. The ROM maintainer has confirmed that the kernel ABI, modules, DTB/DTBO layout, and boot-image format match this source.
4. The bootloader is unlocked, and you have recovery files for both boot slots.
5. You can restore the original matching `boot.img` if the test fails.

## Android version compatibility

| Target ROM | Status |
|---|---|
| Android 16, with the matching Fogos 5.4 source and boot interface | Kernel payload is build-validated. Repacking and device testing are still required. |
| Android 17 | Not verified by this repository. Do not flash until the ROM maintainer confirms the ABI and boot-image interface match. |

## Recovery from a rejected Fastboot flash

If Fastboot reported `Preflash validation failed`, it normally rejected the image before it wrote the partition. Rebooting should return to the existing slot. Do not retry with the same file. Verify the phone’s product, unlock state, current slot, Fastboot mode, ROM build, and the provenance of the boot image first.

The correct recovery image is the original `boot.img` from the same ROM/firmware build, not a random stock image from another Android version.

## References

[1]: https://source.android.com/docs/core/architecture/bootloader/boot-image-header "Android boot image header"
[2]: https://source.android.com/docs/security/features/verifiedboot "Android Verified Boot"
[3]: https://developer.android.com/tools/releases/platform-tools "Android SDK Platform-Tools"
