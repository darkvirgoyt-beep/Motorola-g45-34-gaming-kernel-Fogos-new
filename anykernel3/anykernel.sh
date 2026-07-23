###############################################################################
# VirgoYT Gaming Kernel — FogOS Extreme Gaming Edition
# Device: Motorola G45 / G34 (SM6375 / Holi)
# Developer: Prince · VirgoYT707
# "I don't chase. I attract. I WIN."
###############################################################################

# AnyKernel setup
properties() { '
kernel.string=VirgoYT Gaming Kernel FogOS v2.0 | Developer: Prince (VirgoYT707) | Built Different
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=holi
device.name2=fogos
device.name3=moto_g45
device.name4=MotoG45
device.name5=SM6375
'; }

# AnyKernel methods (auto-included from anykernel.sh header)
. tools/ak3-core.sh;

# Dump device info for logging
dump_boot;

###############################################################################
# CUSTOM FLASHING SECTION
###############################################################################

# Flash the kernel image
split_boot;
flash_boot;

###############################################################################
# GAMING INIT - Applied post-flash via init.d
###############################################################################
# The gaming_init.sh is installed to /system/etc/init.d/
# It runs on every boot to apply FogOS gaming tweaks.
###############################################################################

## end setup
