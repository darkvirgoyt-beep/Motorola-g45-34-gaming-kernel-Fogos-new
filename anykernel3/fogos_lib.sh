#!/system/bin/sh
###############################################################################
# FogOS Extreme Gaming Kernel — Shared Runtime Library
# Device   : Motorola G45 / G34 (SM6375 / Holi)
# Developer: Prince (VirgoYT707)
#
# Common helpers sourced by the on-device runtime scripts
# (fogos_gaming_init.sh, fogos_game_detector.sh) so the CPU/GPU/boost/logging
# logic lives in exactly one place. POSIX sh only — no bashisms.
###############################################################################

# Guard against being sourced twice.
[ -n "${FOG_LIB_LOADED:-}" ] && return 0
FOG_LIB_LOADED=1

# Games that trigger the performance profile (BGMI, PUBG Mobile, Free Fire).
FOG_GAMES="com.pubg.imobile com.tencent.ig com.dts.freefireth com.dts.freefiremax"

# CPU cores treated as "big" cores on SM6375 (used for pinning / idle tuning).
FOG_BIG_CORES="4 5 6 7"
# taskset affinity mask for the big cores (CPU4-7 = 0b11110000).
FOG_BIG_MASK="f0"

###############################################################################
# Low-level sysfs / sysctl helpers
###############################################################################

# fog_write VALUE PATH — write VALUE into PATH, ignoring errors.
fog_write() {
    echo "$1" > "$2" 2>/dev/null
}

# fog_write_if VALUE PATH — write VALUE into PATH only if PATH exists.
fog_write_if() {
    [ -e "$2" ] && echo "$1" > "$2" 2>/dev/null
}

###############################################################################
# CPU
###############################################################################

# fog_cpu_lock_max — switch every core to the performance governor and pin
# scaling_min = scaling_max at the hardware ceiling for every policy.
fog_cpu_lock_max() {
    for _gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        fog_write "performance" "$_gov"
    done
    for _pol in /sys/devices/system/cpu/cpufreq/policy*; do
        _max=$(cat "$_pol/cpuinfo_max_freq" 2>/dev/null)
        if [ -n "$_max" ]; then
            fog_write "$_max" "$_pol/scaling_max_freq"
            fog_write "$_max" "$_pol/scaling_min_freq"
        fi
    done
}

# fog_cpu_unlock — restore the balanced schedutil governor and open the
# frequency range back to the hardware min/max on every policy.
fog_cpu_unlock() {
    for _gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        fog_write "schedutil" "$_gov"
    done
    for _pol in /sys/devices/system/cpu/cpufreq/policy*; do
        _min=$(cat "$_pol/cpuinfo_min_freq" 2>/dev/null)
        _max=$(cat "$_pol/cpuinfo_max_freq" 2>/dev/null)
        [ -n "$_min" ] && fog_write "$_min" "$_pol/scaling_min_freq"
        [ -n "$_max" ] && fog_write "$_max" "$_pol/scaling_max_freq"
    done
}

# fog_cpu_deep_idle STATE — set the "disable" flag (1 = disable, 0 = enable)
# for idle states deeper than C1 on the big cores. Disabling deep idle keeps
# wake-up latency minimal; re-enabling restores battery-friendly idle.
fog_cpu_deep_idle() {
    _val="$1"
    for _cpu in $FOG_BIG_CORES; do
        for _s in /sys/devices/system/cpu/cpu${_cpu}/cpuidle/state*/disable; do
            if [ "$_val" = "1" ]; then
                _depth=$(dirname "$_s" | grep -o 'state[0-9]*' | grep -o '[0-9]*')
                [ -n "$_depth" ] && [ "$_depth" -ge 2 ] && fog_write "1" "$_s"
            else
                fog_write "0" "$_s"
            fi
        done
    done
}

# fog_cpu_input_boost — boost every big core to max on each touch/input event.
fog_cpu_input_boost() {
    fog_write_if "1" /sys/module/cpu_boost/parameters/input_boost_enabled
    fog_write_if "0:0 1:0 2:0 3:0 4:9999999 5:9999999 6:9999999 7:9999999" \
        /sys/module/cpu_boost/parameters/input_boost_freq
    fog_write_if "2000" /sys/module/cpu_boost/parameters/input_boost_ms
}

###############################################################################
# Process affinity
###############################################################################

# fog_pin_big_cores PID [NICE] — pin a process to the big cores and raise its
# priority. NICE defaults to -20 (highest).
fog_pin_big_cores() {
    _pid="$1"
    _nice="${2:--20}"
    [ -z "$_pid" ] && return 1
    taskset -p "$FOG_BIG_MASK" "$_pid" 2>/dev/null
    renice -n "$_nice" -p "$_pid" 2>/dev/null
    fog_write "$_pid" /dev/cpuctl/top-app/tasks
    fog_write "$_pid" /dev/cpuset/top-app/tasks
    return 0
}

###############################################################################
# Membership helper
###############################################################################

# fog_is_game PKG — succeed (0) when PKG is one of the tracked game packages.
fog_is_game() {
    for _game in $FOG_GAMES; do
        [ "$1" = "$_game" ] && return 0
    done
    return 1
}
