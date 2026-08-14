###############################################################################
# FogOS Extreme Gaming Kernel — AnyKernel3 Installer
# Device  : Motorola G45 / G34 (SM6375 / Holi)
# Developer: Prince · VirgoYT707
# Version : v3.1
# "I don't chase. I attract. I WIN." — VirgoYT707
###############################################################################

# AnyKernel setup — REQUIRED block
properties() { '
kernel.string=FogOS Extreme Gaming Kernel v3 | VirgoYT707 | Built Different
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

# Split current boot.img into ramdisk + kernel, then reflash with our kernel.
# split_boot handles both legacy and GKI v3 header format automatically.
split_boot;
flash_boot;

###############################################################################
# GAMING INIT — install boot-time profile daemon
###############################################################################

ui_print " ";
ui_print "  +--------------------------------------+";
ui_print "  |  FogOS Extreme Gaming Kernel v3.1   |";
ui_print "  |  Developer: Prince (VirgoYT707)     |";
ui_print "  |  Device: Motorola G45 (SM6375)      |";
ui_print "  +--------------------------------------+";
ui_print " ";
ui_print "  Installing gaming init scripts...";

# ── Install to /data/adb/fogos (Magisk module convention) ──────────────────
# Modern Android (SAR / system-as-root) does not execute /system/etc/init.d
# scripts unless a dedicated init.d execution module (e.g., busybox) is
# present. Installing to /data/adb/fogos works reliably with Magisk because
# the Magisk service.sh / post-fs-data.sh scripts in the Magisk module
# directory run from /data. This location also survives OTAs safely.

FOGOS_DATA_DIR="/data/adb/fogos";
mkdir -p "$FOGOS_DATA_DIR" 2>/dev/null;

# Install shared runtime library
cp -f $INSTALLER/fogos_lib.sh "$FOGOS_DATA_DIR/fogos_lib.sh" 2>/dev/null && \
  chmod 644 "$FOGOS_DATA_DIR/fogos_lib.sh" 2>/dev/null && \
  ui_print "  + Shared library: $FOGOS_DATA_DIR/fogos_lib.sh" || \
  ui_print "  ! Shared library install skipped";

# Install boot-time gaming init script
cp -f $INSTALLER/fogos_gaming_init.sh "$FOGOS_DATA_DIR/fogos_gaming_init.sh" 2>/dev/null && \
  chmod 755 "$FOGOS_DATA_DIR/fogos_gaming_init.sh" 2>/dev/null && \
  ui_print "  + Gaming init: $FOGOS_DATA_DIR/fogos_gaming_init.sh" || \
  ui_print "  ! Gaming init install skipped";

# Install game detector daemon
cp -f $INSTALLER/fogos_game_detector.sh "$FOGOS_DATA_DIR/fogos_game_detector.sh" 2>/dev/null && \
  chmod 755 "$FOGOS_DATA_DIR/fogos_game_detector.sh" 2>/dev/null && \
  ui_print "  + Game detector: $FOGOS_DATA_DIR/fogos_game_detector.sh" || \
  ui_print "  ! Game detector install skipped";

# ── Also attempt legacy init.d install as fallback ────────────────────────
# For users without Magisk but with an init.d executor (e.g., BusyBox init.d),
# install a stub that calls the /data/adb version.
mkdir -p /system/etc/init.d 2>/dev/null;
cat > /system/etc/init.d/99fogos_gaming << 'STUB'
#!/system/bin/sh
# FogOS init.d stub — calls the main script from /data/adb
[ -x /data/adb/fogos/fogos_gaming_init.sh ] && \
    /data/adb/fogos/fogos_gaming_init.sh
STUB
chmod 755 /system/etc/init.d/99fogos_gaming 2>/dev/null && \
  ui_print "  + init.d stub: /system/etc/init.d/99fogos_gaming" || \
  ui_print "  ! init.d stub skipped (SAR/system-as-root — normal)";

# ── Magisk module: write service.sh to trigger gaming init at boot ─────────
# If Magisk is present (/data/adb/magisk exists), create a minimal module
# so the gaming init runs automatically via Magisk's late_start service stage.
if [ -d /data/adb/magisk ]; then
    MAGISK_MODULE="/data/adb/modules/fogos_gaming";
    mkdir -p "$MAGISK_MODULE" 2>/dev/null;

    # Module metadata
    cat > "$MAGISK_MODULE/module.prop" << 'EOF'
id=fogos_gaming
name=FogOS Extreme Gaming Kernel
version=v3.1
versionCode=31
author=VirgoYT707
description=FogOS gaming init: CPU/GPU/audio/network tuned for BGMI
EOF

    # service.sh: runs in Magisk late_start service context (post-boot)
    cat > "$MAGISK_MODULE/service.sh" << 'EOF'
#!/system/bin/sh
# FogOS Magisk service — boot gaming init after system is ready
FOGOS_DIR=/data/adb/fogos
[ -x "$FOGOS_DIR/fogos_gaming_init.sh" ] && \
    sh "$FOGOS_DIR/fogos_gaming_init.sh" &
EOF
    chmod 755 "$MAGISK_MODULE/service.sh" 2>/dev/null;

    # skip_mount: we don't mount anything (systemless = no /system changes)
    touch "$MAGISK_MODULE/skip_mount" 2>/dev/null;

    ui_print "  + Magisk module: $MAGISK_MODULE";
else
    ui_print "  ! Magisk not detected — init.d fallback will be used";
fi;

ui_print " ";
ui_print "  Supported games (auto-profile):";
ui_print "    * BGMI       (com.pubg.imobile)";
ui_print "    * PUBG Mobile (com.tencent.ig)";
ui_print "    * Free Fire  (com.dts.freefireth)";
ui_print " ";
ui_print "  Flash complete! Reboot when ready.";
ui_print "  Logs: /data/local/fogos_boot.log";
ui_print "  Profile: echo extreme_gaming > /data/local/fogos_profile";
ui_print " ";

## end setup
