#!/system/bin/sh
MODDIR=${0%/*}
STATE="$MODDIR/state"
LOG="$MODDIR/boost.log"
log() { echo "[$(date '+%F %T')] $*" >> "$LOG"; }
write_node() { node="$1"; value="$2"; [ -e "$node" ] || return 1; chmod u+w "$node" 2>/dev/null || true; printf '%s\n' "$value" > "$node" 2>/dev/null; }
save_once() {
    mkdir -p "$STATE"; [ -f "$STATE/saved" ] && return 0; : > "$STATE/saved"
    for p in /sys/devices/system/cpu/cpufreq/policy*; do
        [ -d "$p" ] || continue; name=$(basename "$p")
        cat "$p/scaling_min_freq" 2>/dev/null > "$STATE/${name}.min"
        cat "$p/scaling_max_freq" 2>/dev/null > "$STATE/${name}.max"
        [ -e "$p/scaling_governor" ] && cat "$p/scaling_governor" > "$STATE/${name}.gov"
    done
    [ -e /sys/class/kgsl/kgsl-3d0/max_gpuclk ] && cat /sys/class/kgsl/kgsl-3d0/max_gpuclk > "$STATE/gpu.max"
    [ -e /sys/class/kgsl/kgsl-3d0/devfreq/governor ] && cat /sys/class/kgsl/kgsl-3d0/devfreq/governor > "$STATE/gpu.gov"
}
start_boost() {
    save_once
    for p in /sys/devices/system/cpu/cpufreq/policy*; do
        [ -d "$p" ] || continue; max=$(cat "$p/cpuinfo_max_freq" 2>/dev/null); [ -n "$max" ] || max=$(cat "$p/scaling_max_freq" 2>/dev/null); [ -n "$max" ] || continue
        write_node "$p/scaling_max_freq" "$max"; write_node "$p/scaling_min_freq" "$max"; write_node "$p/scaling_governor" performance; log "CPU $(basename "$p") locked to $max"
    done
    gpu_max=/sys/class/kgsl/kgsl-3d0/max_gpuclk
    if [ -e "$gpu_max" ]; then available=$(cat /sys/class/kgsl/kgsl-3d0/gpu_available_frequencies 2>/dev/null); max=$(printf '%s\n' "$available" | awk '{print $1}'); [ -n "$max" ] && write_node "$gpu_max" "$max" && log "GPU ceiling set to $max"; fi
    write_node /sys/class/kgsl/kgsl-3d0/devfreq/governor performance
    touch "$STATE/active"; log "MAX BOOST ACTIVE; thermal protection was not changed"
}
stop_boost() {
    for p in /sys/devices/system/cpu/cpufreq/policy*; do
        [ -d "$p" ] || continue; name=$(basename "$p")
        [ -s "$STATE/${name}.min" ] && write_node "$p/scaling_min_freq" "$(cat "$STATE/${name}.min")"
        [ -s "$STATE/${name}.max" ] && write_node "$p/scaling_max_freq" "$(cat "$STATE/${name}.max")"
        [ -s "$STATE/${name}.gov" ] && write_node "$p/scaling_governor" "$(cat "$STATE/${name}.gov")"
    done
    [ -s "$STATE/gpu.max" ] && write_node /sys/class/kgsl/kgsl-3d0/max_gpuclk "$(cat "$STATE/gpu.max")"
    [ -s "$STATE/gpu.gov" ] && write_node /sys/class/kgsl/kgsl-3d0/devfreq/governor "$(cat "$STATE/gpu.gov")"
    rm -f "$STATE/active" "$STATE/saved"; log "BOOST STOPPED; previous policy restored"
}
status() {
    echo "module=$MODDIR"; [ -e "$STATE/active" ] && echo active=1 || echo active=0
    for p in /sys/devices/system/cpu/cpufreq/policy*; do [ -d "$p" ] || continue; echo "$(basename "$p") current=$(cat "$p/scaling_cur_freq" 2>/dev/null) min=$(cat "$p/scaling_min_freq" 2>/dev/null) max=$(cat "$p/scaling_max_freq" 2>/dev/null) gov=$(cat "$p/scaling_governor" 2>/dev/null) hwmax=$(cat "$p/cpuinfo_max_freq" 2>/dev/null)"; done
    echo "gpu=$(cat /sys/class/kgsl/kgsl-3d0/gpuclk 2>/dev/null) gpu_max=$(cat /sys/class/kgsl/kgsl-3d0/max_gpuclk 2>/dev/null) gpu_gov=$(cat /sys/class/kgsl/kgsl-3d0/devfreq/governor 2>/dev/null)"
}
case "$1" in start|gaming) start_boost ;; stop|restore) stop_boost ;; status) status ;; *) echo "usage: $MODDIR/boost.sh {start|stop|status}" >&2; exit 2 ;; esac
