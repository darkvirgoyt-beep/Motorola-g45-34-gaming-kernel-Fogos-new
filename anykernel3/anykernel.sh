#!/system/bin/sh
# shellcheck disable=SC2148,SC2289
###############################################################################
# FogOS Gaming Kernel — rootless AnyKernel3 installer
# Device   : Motorola G45 / G34 5G (SM6375 / Holi, fogos)
# Base ROM : Evolution X Android 17
#
# This installer replaces only the kernel in the currently active boot slot.
# Runtime profiles are provided by the rootless privileged FogOS PulseControl
# integration through /dev/fogos_profile; no Magisk, init.d, or shell bridge
# is installed by this ZIP.
###############################################################################

properties() { '
kernel.string=FogOS Gaming Kernel | fogos | Evolution X Android 17
do.devicecheck=1
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0

# Motorola G45 / G34 (Holi) device identifiers.
device.name1=holi
device.name2=fogos
device.name3=moto_g45
device.name4=MotoG45
device.name5=MotoG34
device.name6=motorola_holi
device.name7=SM6375
device.name8=msm6375
'; }

# AnyKernel3 supplies slot-aware boot partition discovery. dump_boot and
# flash_boot operate on the currently active slot; with Evolution X running
# from slot B, FKM therefore writes boot_b and does not touch slot A.
# Explicitly skip Magisk-aware repatching: this release contains no root
# integration and must leave the supplied kernel payload unchanged.
NO_MAGISK_CHECK=1
. tools/ak3-core.sh;
dump_boot;
split_boot;
flash_boot;

ui_print " ";
ui_print "  FogOS Gaming Kernel installed to the active boot slot.";
ui_print "  Rootless profile endpoint: /dev/fogos_profile";
ui_print "  Reboot when ready.";
ui_print " ";

## end setup
