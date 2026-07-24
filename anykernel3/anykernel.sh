###############################################################################
# FogOS Extreme Gaming Kernel — AnyKernel3 Installer
# Device  : Motorola G45 / G34 (SM6375 / Holi)
# Developer: Prince · VirgoYT707
# Version : v2.0
# "I don't chase. I attract. I WIN." — VirgoYT707
###############################################################################

# AnyKernel setup — REQUIRED block
properties() { '
kernel.string=FogOS Extreme Gaming Kernel v2.0 | VirgoYT707 | Built Different
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0

# Device detection — matches Motorola G45 / G34 (Holi platform)
device.name1=holi
device.name2=fogos
device.name3=moto_g45
device.name4=MotoG45
device.name5=MotoG34
device.name6=motorola_holi
device.name7=SM6375
device.name8=msm6375
'; }

# AnyKernel methods (provided by tools/ak3-core.sh from AnyKernel3)
. tools/ak3-core.sh;

# Dump device + boot info to log
dump_boot;

###############################################################################
# KERNEL FLASH
###############################################################################

# Split current boot.img into ramdisk + kernel, then reflash with our kernel
split_boot;
flash_boot;

###############################################################################
# GAMING INIT — install boot-time profile daemon
###############################################################################

ui_print " ";
ui_print "  ╔══════════════════════════════════════╗";
ui_print "  ║   FogOS Extreme Gaming Kernel v2.0  ║";
ui_print "  ║   Developer: Prince (VirgoYT707)    ║";
ui_print "  ║   Device: Motorola G45 (SM6375)     ║";
ui_print "  ╚══════════════════════════════════════╝";
ui_print " ";
ui_print "  Installing gaming init scripts...";

# Install boot-time gaming tweaks to init.d
mkdir -p /system/etc/init.d 2>/dev/null;
cp -f $INSTALLER/fogos_gaming_init.sh /system/etc/init.d/99fogos_gaming 2>/dev/null && \
  chmod 755 /system/etc/init.d/99fogos_gaming 2>/dev/null && \
  ui_print "  ✓ Gaming init installed: /system/etc/init.d/99fogos_gaming" || \
  ui_print "  ⚠ init.d install skipped (Magisk init.d module recommended)";

# Install game detector daemon
mkdir -p /system/bin 2>/dev/null;
cp -f $INSTALLER/fogos_game_detector.sh /system/bin/fogos_game_detector 2>/dev/null && \
  chmod 755 /system/bin/fogos_game_detector 2>/dev/null && \
  ui_print "  ✓ Game detector installed: /system/bin/fogos_game_detector" || \
  ui_print "  ⚠ Game detector install skipped";

ui_print " ";
ui_print "  Supported games (auto-profile):";
ui_print "    • BGMI       (com.pubg.imobile)";
ui_print "    • PUBG Mobile (com.tencent.ig)";
ui_print "    • Free Fire  (com.dts.freefireth)";
ui_print " ";
ui_print "  Flash complete! Reboot when ready.";
ui_print "  Logs: /data/local/fogos_boot.log";
ui_print " ";

## end setup
