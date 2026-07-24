#!/system/bin/sh
###############################################################################
# FogOS Extreme Gaming Kernel — Per-Game Profile Manager v2.0
#
# Developer : Prince (VirgoYT707)
# Device    : Motorola G45 (SM6375 / Holi)
#
# Runs as a background daemon after boot.
# Monitors foreground app and switches kernel/CPU/GPU profile:
#   GAME MODE  → performance-locked
#   NORMAL     → balanced (saves battery, reduces heat)
#
# Supported games:
#   BGMI     : com.pubg.imobile
#   PUBG     : com.tencent.ig
#   Free Fire: com.dts.freefireth
###############################################################################

TAG="FogOS-Game"
LOG="/data/local/fogos_game.log"
ACTIVE_LOG="/data/local/fogos_active_game.txt"

log() { echo "[$TAG][$(date '+%H:%M:%S')] $1" >> "$LOG" 2>/dev/null; }

# Load shared FogOS runtime helpers (CPU/GPU/boost/game-list utilities).
# BASH_SOURCE lets the unit-test suite locate the lib when sourcing this file.
for FOG_LIB in \
    "${FOG_LIB:-}" \
    "$(dirname "${BASH_SOURCE:-$0}")/fogos_lib.sh" \
    /system/etc/fogos/fogos_lib.sh \
    /system/bin/fogos_lib.sh; do
    [ -n "$FOG_LIB" ] && [ -f "$FOG_LIB" ] && { . "$FOG_LIB"; break; }
done

# Thin sysfs-write alias kept for the on-device callers and the unit tests.
write() { fog_write "$@"; }

# Truncate log if too large
truncate_log() {
  [ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -gt 524288 ] && \
    tail -c 262144 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
}
[ "${FOGOS_LIB_ONLY:-0}" = "1" ] || truncate_log

###############################################################################
# PROFILE: GAME (Performance)
###############################################################################
apply_game_profile() {
  local game="$1"
  log "=== GAME START: $game ==="

  # --- CPU: Performance + lock big cores ---
  fog_cpu_lock_max

  # Disable deep idle on big cores (CPU4-7) for minimal wake latency
  fog_cpu_deep_idle 1

  # WALT: force max boost
  fog_write "2" /proc/sys/kernel/sched_boost 2>/dev/null
  fog_write "1024" /proc/sys/kernel/sched_util_clamp_min 2>/dev/null

  # uclamp: boost foreground
  fog_write "100" /dev/stune/top-app/schedtune.boost 2>/dev/null
  fog_write "1"   /dev/stune/top-app/schedtune.prefer_idle 2>/dev/null

  # Input boost: big cores on every touch
  fog_cpu_input_boost

  # --- GPU: Lock to max ---
  GPU_BASE="/sys/class/kgsl/kgsl-3d0"
  max_gpu=$(cat "$GPU_BASE/devfreq/max_freq" 2>/dev/null || \
            cat "$GPU_BASE/gpuclk" 2>/dev/null)
  [ -n "$max_gpu" ] && fog_write "$max_gpu" "$GPU_BASE/devfreq/min_freq"
  fog_write "0"  "$GPU_BASE/max_pwrlevel" 2>/dev/null
  fog_write "0"  "$GPU_BASE/min_pwrlevel" 2>/dev/null
  fog_write "1"  "$GPU_BASE/force_no_nap" 2>/dev/null

  # --- Memory: gaming VM tuning ---
  sysctl -w vm.swappiness=20        2>/dev/null
  sysctl -w vm.vfs_cache_pressure=50 2>/dev/null
  sysctl -w vm.extra_free_kbytes=49152 2>/dev/null
  sysctl -w vm.dirty_ratio=5        2>/dev/null
  sysctl -w vm.dirty_background_ratio=1 2>/dev/null

  # --- Network: gaming TCP ---
  sysctl -w net.ipv4.tcp_congestion_control=bbr  2>/dev/null
  sysctl -w net.core.default_qdisc=fq            2>/dev/null
  sysctl -w net.ipv4.tcp_nodelay=1               2>/dev/null
  sysctl -w net.ipv4.tcp_keepalive_time=10       2>/dev/null
  sysctl -w net.ipv4.tcp_keepalive_intvl=3       2>/dev/null
  sysctl -w net.ipv4.tcp_keepalive_probes=3      2>/dev/null
  sysctl -w net.ipv4.tcp_fastopen=3              2>/dev/null

  # WLAN power save OFF during game (reduces latency)
  iwconfig wlan0 power off 2>/dev/null || true

  # --- Pin game process to big cores (CPU4-7) ---
  game_pid=$(pidof "$game" 2>/dev/null | awk '{print $1}')
  if [ -n "$game_pid" ]; then
    fog_pin_big_cores "$game_pid" -20
    log "Pinned PID $game_pid to CPU4-7, priority -20"
  fi

  echo "$game" > "$ACTIVE_LOG"
  log "=== GAME PROFILE ACTIVE for: $game ==="
}

###############################################################################
# PROFILE: NORMAL (Balanced)
###############################################################################
apply_normal_profile() {
  log "=== Returning to NORMAL balanced profile ==="

  # --- CPU: schedutil governor + open frequency range ---
  fog_cpu_unlock

  # Re-enable idle states
  fog_cpu_deep_idle 0

  fog_write "0" /proc/sys/kernel/sched_boost 2>/dev/null

  # --- GPU: auto TZ governor ---
  GPU_BASE="/sys/class/kgsl/kgsl-3d0"
  fog_write "0"   "$GPU_BASE/force_no_nap" 2>/dev/null
  fog_write "6"   "$GPU_BASE/min_pwrlevel" 2>/dev/null
  fog_write "0"   "$GPU_BASE/max_pwrlevel" 2>/dev/null

  # --- Memory: normal balanced ---
  sysctl -w vm.swappiness=60          2>/dev/null
  sysctl -w vm.vfs_cache_pressure=100 2>/dev/null
  sysctl -w vm.extra_free_kbytes=0    2>/dev/null
  sysctl -w vm.dirty_ratio=20         2>/dev/null
  sysctl -w vm.dirty_background_ratio=5 2>/dev/null

  # WLAN power save back on
  iwconfig wlan0 power on 2>/dev/null || true

  # Restore schedtune
  fog_write "0" /dev/stune/top-app/schedtune.boost 2>/dev/null

  rm -f "$ACTIVE_LOG"
  log "=== NORMAL PROFILE ACTIVE ==="
}

###############################################################################
# GET FOREGROUND APP
###############################################################################
get_foreground_app() {
  # Method 1: dumpsys activity
  pkg=$(dumpsys activity 2>/dev/null \
    | grep -m1 "mCurrentFocus\|mFocusedApp\|topResumedActivity" \
    | grep -oP '(?<=\{)[^/ ]+/[^}]+' | cut -d/ -f1 | head -1)
  [ -n "$pkg" ] && echo "$pkg" && return

  # Method 2: dumpsys window
  pkg=$(dumpsys window windows 2>/dev/null \
    | grep -m1 "mCurrentFocus\|Window #" \
    | grep -oP '[a-z][a-z0-9\.]+\.[a-zA-Z0-9\.]+' | head -1)
  [ -n "$pkg" ] && echo "$pkg" && return

  # Method 3: foreground process from proc
  for pid in /proc/[0-9]*/status; do
    if grep -q "foreground" "$pid" 2>/dev/null; then
      dir=$(dirname "$pid")
      comm=$(cat "$dir/cmdline" 2>/dev/null | tr '\0' '\n' | head -1)
      [ -n "$comm" ] && echo "$comm" && return
    fi
  done
  echo ""
}

###############################################################################
# IS_GAME: check if a package is in our game list
###############################################################################
is_game() { fog_is_game "$1"; }

###############################################################################
# MAIN MONITOR LOOP
###############################################################################
LAST_STATE="normal"
LAST_GAME=""
CHECK_INTERVAL=5  # seconds

# Skip the monitoring daemon loop when sourced for unit testing.
if [ "${FOGOS_LIB_ONLY:-0}" = "1" ]; then
  return 0 2>/dev/null || exit 0
fi

log "FogOS Game Detector started — monitoring every ${CHECK_INTERVAL}s"

while true; do
  CURRENT_PKG="$(get_foreground_app)"

  if is_game "$CURRENT_PKG"; then
    if [ "$LAST_STATE" != "game" ] || [ "$CURRENT_PKG" != "$LAST_GAME" ]; then
      apply_game_profile "$CURRENT_PKG"
      LAST_STATE="game"
      LAST_GAME="$CURRENT_PKG"
    else
      # Re-pin PID in case it changed (game restart / respawn)
      game_pid=$(pidof "$CURRENT_PKG" 2>/dev/null | awk '{print $1}')
      if [ -n "$game_pid" ]; then
        taskset -p 0xf0 "$game_pid" 2>/dev/null || true
        fog_write "$game_pid" /dev/cpuctl/top-app/tasks 2>/dev/null || true
      fi
    fi
  else
    if [ "$LAST_STATE" = "game" ]; then
      apply_normal_profile
      LAST_STATE="normal"
      LAST_GAME=""
    fi
  fi

  sleep "$CHECK_INTERVAL"
done
