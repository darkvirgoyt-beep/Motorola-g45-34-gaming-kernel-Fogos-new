#!/system/bin/sh
SCRIPT_DIR="${0%/*}"
. "${SCRIPT_DIR}/config.sh"
. "${SCRIPT_DIR}/logger.sh"

write_if_exists() { [ -e "$2" ] && echo "$1" > "$2" 2>/dev/null; }
read_first() { for p in "$@"; do [ -r "$p" ] && { cat "$p" 2>/dev/null; return; }; done; }
profile_current() {
  p="$(cat "$FOGOS_PROFILE_FILE" 2>/dev/null | tr -d '[:space:]')"
  case "$p" in balanced|performance|extreme_gaming) echo "$p";; *) echo "$FOGOS_DEFAULT_PROFILE";; esac
}
set_cpu_policy() {
  gov="$1"; min_pct="$2"
  for pol in /sys/devices/system/cpu/cpufreq/policy*; do
    [ -d "$pol" ] || continue
    write_if_exists "$gov" "$pol/scaling_governor"
    min="$(cat "$pol/cpuinfo_min_freq" 2>/dev/null)"; max="$(cat "$pol/cpuinfo_max_freq" 2>/dev/null)"
    [ -n "$max" ] || continue
    target=$(( min + ((max - min) * min_pct / 100) ))
    [ "$target" -lt "$min" ] && target="$min"
    write_if_exists "$target" "$pol/scaling_min_freq"
    write_if_exists "$max" "$pol/scaling_max_freq"
    for tun in "$pol/schedutil/up_rate_limit_us" "$pol/schedutil/down_rate_limit_us"; do [ -e "$tun" ] && :; done
  done
}
set_sched() {
  boost="$1"; uclamp="$2"
  write_if_exists "$boost" /proc/sys/kernel/sched_boost
  write_if_exists "$uclamp" /proc/sys/kernel/sched_util_clamp_min
  write_if_exists "$uclamp" /dev/stune/top-app/schedtune.boost
  write_if_exists 1 /dev/stune/top-app/schedtune.prefer_idle
}
set_gpu() {
  gov="$1"; min_pct="$2"; keep_awake="$3"
  for gpu in /sys/class/kgsl/kgsl-3d0 /sys/devices/platform/*kgsl*/kgsl/kgsl-3d0; do
    [ -d "$gpu" ] || continue
    write_if_exists "$gov" "$gpu/devfreq/governor"
    min="$(read_first "$gpu/devfreq/min_freq" "$gpu/gpu_available_frequencies")"
    max="$(read_first "$gpu/devfreq/max_freq")"
    [ -n "$max" ] && [ -n "$min" ] && write_if_exists $(( min + ((max - min) * min_pct / 100) )) "$gpu/devfreq/min_freq"
    write_if_exists "$keep_awake" "$gpu/force_clk_on"
    write_if_exists "$keep_awake" "$gpu/force_no_nap"
  done
}
set_vm_io() {
  sysctl -w vm.swappiness="$1" vm.vfs_cache_pressure="$2" vm.dirty_ratio="$3" vm.dirty_background_ratio="$4" 2>/dev/null
  for q in /sys/block/*/queue; do
    [ -d "$q" ] || continue
    [ -e "$q/scheduler" ] && { grep -qw mq-deadline "$q/scheduler" 2>/dev/null && echo mq-deadline > "$q/scheduler" 2>/dev/null; }
    write_if_exists "$5" "$q/read_ahead_kb"
  done
}
set_touch_boost() {
  write_if_exists "$1" /sys/module/msm_performance/parameters/touchboost
  write_if_exists "$1" /sys/module/cpu_boost/parameters/input_boost_enabled
}
set_thermal_safe() {
  limit="${FOGOS_SAFE_THERMAL_LIMIT_MILLIC:-90000}"
  # Keep thermal zones enabled; raise only writable passive trip points up to configured cap.
  for mode in /sys/class/thermal/thermal_zone*/mode; do write_if_exists enabled "$mode"; done
  for trip in /sys/class/thermal/thermal_zone*/trip_point_*_temp; do
    [ -w "$trip" ] || continue
    cur="$(cat "$trip" 2>/dev/null)"
    [ -n "$cur" ] && [ "$cur" -lt "$limit" ] && echo "$limit" > "$trip" 2>/dev/null
  done
}
apply_profile() {
  p="${1:-$(profile_current)}"
  mkdir -p "$(dirname "$FOGOS_PROFILE_FILE")" "$FOGOS_LOG_DIR" 2>/dev/null
  case "$p" in
    balanced) set_cpu_policy schedutil 0; set_sched 0 0; set_gpu msm-adreno-tz 0 0; set_vm_io 60 100 20 5 128; set_touch_boost 0;;
    performance) set_cpu_policy schedutil 35; set_sched 1 256; set_gpu msm-adreno-tz 35 0; set_vm_io 35 80 12 3 256; set_touch_boost 1;;
    extreme_gaming) set_cpu_policy schedutil 60; set_sched 2 512; set_gpu msm-adreno-tz 60 1; set_vm_io 20 60 8 2 512; set_touch_boost 1;;
    *) fogos_log "unknown profile '$p', falling back balanced"; p=balanced; apply_profile balanced; return;;
  esac
  set_thermal_safe
  echo "$p" > "$FOGOS_PROFILE_FILE" 2>/dev/null
  fogos_log "applied profile=$p"
}
[ "${FOGOS_LIB_ONLY:-0}" = 1 ] || apply_profile "$1"
