#!/system/bin/sh
###############################################################################
# FogOS Extreme Gaming Kernel - Runtime Tuning Script
# Developer: Prince (VirgoYT707)
# Device: Motorola G45 (SM6375 / Holi)
# Version: v1.0
#
# This script runs at boot via init.d to apply gaming-optimized
# sysctl values and kernel parameters.
###############################################################################

# Wait for system to settle
sleep 5

TAG="FogOS"
log() { echo "[$TAG] $1"; }

log "=== FogOS Extreme Gaming Kernel v1.0 Boot Tuning ==="

###############################################################################
# CPU - Performance tuning
###############################################################################

# Set CPU governor to schedutil for all CPUs
for CPU in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo "schedutil" > $CPU 2>/dev/null
done

# schedutil rate limit - lower = faster ramp, higher = smoother
# 500us for gaming responsiveness
for CPU in /sys/devices/system/cpu/cpufreq/policy*/schedutil/rate_limit_us; do
    echo "500" > $CPU 2>/dev/null
done

# Up threshold - ramp up quickly under load
for CPU in /sys/devices/system/cpu/cpufreq/policy*/schedutil/up_rate_limit_us; do
    echo "200" > $CPU 2>/dev/null
done

# Down threshold - slow to ramp down (keeps big cores active longer during gaming)
for CPU in /sys/devices/system/cpu/cpufreq/policy*/schedutil/down_rate_limit_us; do
    echo "2000" > $CPU 2>/dev/null
done

# Hispeed load threshold - jump to hispeed freq at this util %
for CPU in /sys/devices/system/cpu/cpufreq/policy*/hispeed_load; do
    echo "75" > $CPU 2>/dev/null
done

# Boost CPU freq minimum for big cores (SM6375 big cluster = CPU4-7)
# Kryo 560 big cores go up to ~2.4GHz
for POL in /sys/devices/system/cpu/cpufreq/policy4 /sys/devices/system/cpu/cpufreq/policy6; do
    [ -d $POL ] && echo "1708800" > $POL/scaling_min_freq 2>/dev/null
done

# Enable CPU boost
[ -f /sys/module/cpu_boost/parameters/input_boost_enabled ] && \
    echo "1" > /sys/module/cpu_boost/parameters/input_boost_enabled

# Input boost frequency (touch events boost big cores)
[ -f /sys/module/cpu_boost/parameters/input_boost_freq ] && \
    echo "0:0 1:0 2:0 3:0 4:1708800 5:1708800 6:1708800 7:1708800" \
    > /sys/module/cpu_boost/parameters/input_boost_freq

# Input boost duration (ms)
[ -f /sys/module/cpu_boost/parameters/input_boost_ms ] && \
    echo "80" > /sys/module/cpu_boost/parameters/input_boost_ms

log "CPU governor: schedutil (gaming tuned)"

###############################################################################
# GPU - Adreno Performance
###############################################################################

GPU_PATH="/sys/class/kgsl/kgsl-3d0"

if [ -d "$GPU_PATH" ]; then
    # Set GPU governor to performance during boot, then msm-adreno-tz
    echo "performance" > $GPU_PATH/devfreq/governor 2>/dev/null
    sleep 1
    echo "msm-adreno-tz" > $GPU_PATH/devfreq/governor 2>/dev/null

    # Adreno Idler - reduce idle latency
    echo "0" > $GPU_PATH/idle_timer 2>/dev/null || \
    echo "64" > $GPU_PATH/idle_timer 2>/dev/null

    # Disable GPU throttling as much as safely possible
    echo "0" > $GPU_PATH/throttling 2>/dev/null

    # GPU power level - 0 = max performance
    echo "0" > $GPU_PATH/default_pwrlevel 2>/dev/null
    echo "0" > $GPU_PATH/min_pwrlevel 2>/dev/null

    # Enable GPU bus split
    echo "1" > $GPU_PATH/bus_split 2>/dev/null

    log "GPU: msm-adreno-tz governor (max performance)"
else
    log "GPU sysfs not found, skipping GPU tuning"
fi

###############################################################################
# MEMORY - VM & LMK Optimization
###############################################################################

# swappiness: 60 is default; lower = keep more in RAM
# 40 keeps gaming workloads in RAM while still allowing swap when needed
sysctl -w vm.swappiness=40

# vfs_cache_pressure: lower = keep dentry/inode cache longer
sysctl -w vm.vfs_cache_pressure=50

# dirty page ratios - allow more dirty pages to reduce write stalls
sysctl -w vm.dirty_ratio=20
sysctl -w vm.dirty_background_ratio=5

# dirty expire and writeback intervals (ms) - 2s expire, 1s writeback check
sysctl -w vm.dirty_expire_centisecs=200
sysctl -w vm.dirty_writeback_centisecs=100

# Overcommit memory for faster allocation
sysctl -w vm.overcommit_memory=1

# Reserve more watermark memory to avoid OOM during gaming
sysctl -w vm.watermark_scale_factor=50

# Compact memory less aggressively (reduces stutter)
sysctl -w vm.compaction_proactiveness=0

# Extra free kilobytes (give LMKD a bigger buffer)
sysctl -w vm.extra_free_kbytes=24300

# Page cluster (readahead pages) - 0 for random access gaming workloads
sysctl -w vm.page-cluster=0

# Stat interval
sysctl -w vm.stat_interval=10

log "Memory: vm tuned for gaming"

###############################################################################
# ZRAM - Optimize compression
###############################################################################

ZRAM0="/sys/block/zram0"
if [ -d "$ZRAM0" ]; then
    # ZSTD is the best ratio/speed for gaming
    echo "zstd" > $ZRAM0/comp_algorithm 2>/dev/null
    log "ZRAM: zstd compression active"
fi

###############################################################################
# I/O SCHEDULER - BFQ Tuned
###############################################################################

# Apply BFQ to all block devices
for QUEUE in /sys/block/*/queue; do
    DEV=$(echo $QUEUE | cut -d'/' -f4)
    
    # Set BFQ scheduler
    echo "bfq" > $QUEUE/scheduler 2>/dev/null
    
    # Read-ahead in KB - 128KB for gaming (balance latency vs throughput)
    echo "128" > $QUEUE/read_ahead_kb 2>/dev/null
    
    # nr_requests - more in-flight requests for better throughput
    echo "256" > $QUEUE/nr_requests 2>/dev/null
    
    # Reduce I/O latency
    echo "0" > $QUEUE/add_random 2>/dev/null
    echo "0" > $QUEUE/rotational 2>/dev/null
    
    # BFQ specific: low latency mode ON (prioritize interactive)
    echo "1" > $QUEUE/iosched/low_latency 2>/dev/null
    
    # BFQ slice_idle: 0 for non-rotational (UFS), reduces latency
    echo "0" > $QUEUE/iosched/slice_idle 2>/dev/null
    echo "0" > $QUEUE/iosched/group_idle 2>/dev/null
done

log "I/O: BFQ scheduler (low_latency=1, slice_idle=0)"

###############################################################################
# NETWORK - Low Ping TCP Tuning
###############################################################################

# TCP BBR congestion control (lowest latency, best for BGMI)
sysctl -w net.ipv4.tcp_congestion_control=bbr

# Packet pacing with FQ
sysctl -w net.core.default_qdisc=fq

# TCP Fast Open - reduces handshake latency
sysctl -w net.ipv4.tcp_fastopen=3

# TCP timestamps (needed for BBR)
sysctl -w net.ipv4.tcp_timestamps=1

# TCP SACK (selective acknowledgement - better packet loss recovery)
sysctl -w net.ipv4.tcp_sack=1

# TCP window scaling
sysctl -w net.ipv4.tcp_window_scaling=1

# TCP buffer sizes - tuned for gaming (lower latency, not max throughput)
sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216"

# Core network buffers
sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216
sysctl -w net.core.netdev_max_backlog=5000
sysctl -w net.core.somaxconn=4096

# Reduce TIME_WAIT connections faster
sysctl -w net.ipv4.tcp_fin_timeout=15
sysctl -w net.ipv4.tcp_tw_reuse=1

# IPv4 route cache
sysctl -w net.ipv4.route.flush=1

# Reduce DNS latency by enabling negative caching TTL reduction
sysctl -w net.ipv4.tcp_syn_retries=3
sysctl -w net.ipv4.tcp_synack_retries=3

# TCP keepalive - detect dead connections faster
sysctl -w net.ipv4.tcp_keepalive_time=60
sysctl -w net.ipv4.tcp_keepalive_intvl=10
sysctl -w net.ipv4.tcp_keepalive_probes=6

log "Network: TCP BBR + FQ (gaming low-latency tuning)"

###############################################################################
# SCHEDULER - Gaming Task Priority
###############################################################################

# kernel.sched_min_granularity_ns: minimum time each task runs before preemption
# Lower = better interactive response
sysctl -w kernel.sched_min_granularity_ns=1000000

# sched_latency_ns: target scheduling latency (how often all tasks get a turn)
sysctl -w kernel.sched_latency_ns=5000000

# sched_wakeup_granularity_ns: waking task preempts if running task is this old
sysctl -w kernel.sched_wakeup_granularity_ns=500000

# sched_migration_cost_ns: cost of migrating a task to another CPU
# Higher = less migration = less cache misses for gaming
sysctl -w kernel.sched_migration_cost_ns=5000000

# Disable auto-grouping (breaks Android task priority hierarchy)
sysctl -w kernel.sched_autogroup_enabled=0

# Increase inotify limits for Android
sysctl -w fs.inotify.max_user_watches=524288
sysctl -w fs.inotify.max_user_instances=256

log "Scheduler: WALT tuned for gaming responsiveness"

###############################################################################
# THERMAL - Gaming Profile
###############################################################################

THERMAL_PATH="/sys/class/thermal"

if [ -d "$THERMAL_PATH" ]; then
    # Raise trip points on cooling devices to delay throttling
    # Note: conservative approach - only raise by reasonable margin
    for TRIP in $THERMAL_PATH/thermal_zone*/trip_point_*_temp; do
        CURRENT=$(cat $TRIP 2>/dev/null)
        if [ -n "$CURRENT" ] && [ "$CURRENT" -lt "95000" ]; then
            # Raise limit by 3°C (3000 millidegrees) if safely below 95°C
            NEW_TEMP=$((CURRENT + 3000))
            echo "$NEW_TEMP" > $TRIP 2>/dev/null
        fi
    done
    log "Thermal: trip points raised +3°C for gaming (max 95°C)"
else
    log "Thermal sysfs not found, skipping"
fi

###############################################################################
# TOUCH - Maximum Sampling Rate
###############################################################################

# Enable touch boost (kernel-side input boost is set via cpu_boost above)
# Try common touchscreen sysfs paths for Holi/Moto
for TOUCH_PATH in \
    /proc/touchpanel \
    /sys/class/input/input*/polling_rate \
    /sys/devices/virtual/touchscreen/touchscreen_dev; do
    [ -e "$TOUCH_PATH" ] && log "Touch path found: $TOUCH_PATH"
done

# Input event boost (WALT input boost)
[ -f /proc/sys/kernel/sched_boost ] && \
    echo "1" > /proc/sys/kernel/sched_boost

log "Touch: input boost enabled"

###############################################################################
# DISPLAY - Smooth Rendering
###############################################################################

# Reduce SurfaceFlinger scheduling delays
sysctl -w kernel.sched_rt_runtime_us=950000 2>/dev/null

###############################################################################
# FILESYSTEM - Periodic fstrim
###############################################################################

# Kick off a background fstrim on /data to maintain storage performance
(sleep 30 && fstrim /data 2>/dev/null && fstrim /cache 2>/dev/null && log "fstrim completed") &

###############################################################################
# POWER - Sustained Performance Mode
###############################################################################

# Disable power-efficient workqueues for gaming (lower latency)
[ -f /sys/module/workqueue/parameters/power_efficient ] && \
    echo "N" > /sys/module/workqueue/parameters/power_efficient

# Enable performance mode MSM devfreq
for DEV in /sys/class/devfreq/*/governor; do
    echo "performance" > $DEV 2>/dev/null
done
sleep 2
# Restore msm governors after initial perf burst
for DEV in /sys/class/devfreq/soc:qcom,cpu0-llcc-ddr-lat/governor \
           /sys/class/devfreq/soc:qcom,cpu6-llcc-ddr-lat/governor; do
    echo "bw_hwmon" > $DEV 2>/dev/null
done

log "Power: sustained performance (workqueue power_efficient=N)"

###############################################################################
# KERNEL LOGGING - Reduce overhead
###############################################################################

# Reduce kernel log level (3 = errors only, 4 = warnings+errors)
sysctl -w kernel.printk="4 4 1 7"

# Disable dynamic debug overhead
[ -f /sys/kernel/debug/dynamic_debug/control ] && \
    echo "module * =_" > /sys/kernel/debug/dynamic_debug/control 2>/dev/null

log "Logging: reduced to errors/warnings only"

###############################################################################
# DONE
###############################################################################

log "=== FogOS Extreme Gaming Kernel v1.0 - Boot tuning COMPLETE ==="
log "=== Enjoy maximum BGMI performance! ==="
log "=== Developer: Prince (VirgoYT707) ==="
