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

GAMES="com.pubg.imobile com.tencent.ig com.dts.freefireth"

log() { echo "[$TAG][$(date '+%H:%M:%S')] $1" >> "$LOG" 2>/dev/null; }
write() { echo "$1" > "$2" 2>/dev/null; }

# Truncate log if too large
[ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -gt 524288 ] && \
  tail -c 262144 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"

###############################################################################
# PROFILE: GAME (Performance)
###############################################################################
apply_game_profile() {
  local game="$1"
  log "=== GAME START: $game ==="

  # --- CPU: Performance + lock big cores ---
  for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    write "performance" "$gov"
  done
  for pol in /sys/devices/system/cpu/cpufreq/policy*; do
    max=$(cat "$pol/cpuinfo_max_freq" 2>/dev/null)
    [ -n "$max" ] && write "$max" "$pol/scaling_max_freq"
    [ -n "$max" ] && write "$max" "$pol/scaling_min_freq"
  done

  # Disable deep idle on big cores (CPU4-7) for minimal wake latency
  for cpu in 4 5 6 7; do
    for s in /sys/devices/system/cpu/cpu${cpu}/cpuidle/state*/disable; do
      depth=$(dirname "$s" | grep -o '[0-9]*$')
      [ -n "$depth" ] && [ "$depth" -ge 2 ] && write "1" "$s"
    done
  done

  # WALT: force max boost
  write "2" /proc/sys/kernel/sched_boost 2>/dev/null
  write "1024" /proc/sys/kernel/sched_util_clamp_min 2>/dev/null

  # uclamp: boost foreground
  write "100" /dev/stune/top-app/schedtune.boost 2>/dev/null
  write "1"   /dev/stune/top-app/schedtune.prefer_idle 2>/dev/null

  # Input boost: big cores on every touch
  write "1" /sys/module/cpu_boost/parameters/input_boost_enabled 2>/dev/null
  write "0:0 1:0 2:0 3:0 4:9999999 5:9999999 6:9999999 7:9999999" \
        /sys/module/cpu_boost/parameters/input_boost_freq 2>/dev/null
  write "2000" /sys/module/cpu_boost/parameters/input_boost_ms 2>/dev/null

  # --- GPU: Lock to max ---
  GPU_BASE="/sys/class/kgsl/kgsl-3d0"
  max_gpu=$(cat "$GPU_BASE/devfreq/max_freq" 2>/dev/null || \
            cat "$GPU_BASE/gpuclk" 2>/dev/null)
  [ -n "$max_gpu" ] && write "$max_gpu" "$GPU_BASE/devfreq/min_freq"
  write "0"  "$GPU_BASE/max_pwrlevel" 2>/dev/null
  write "0"  "$GPU_BASE/min_pwrlevel" 2>/dev/null
  write "1"  "$GPU_BASE/force_no_nap" 2>/dev/null

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
    taskset -p 0xf0 "$game_pid" 2>/dev/null
    renice -n -20 -p "$game_pid" 2>/dev/null
    # Add to top-app cgroup
    write "$game_pid" /dev/cpuctl/top-app/tasks 2>/dev/null
    write "$game_pid" /dev/cpuset/top-app/tasks 2>/dev/null
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

  # --- CPU: schedutil governor ---
  for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    write "schedutil" "$gov"
  done
  for pol in /sys/devices/system/cpu/cpufreq/policy*; do
    min=$(cat "$pol/cpuinfo_min_freq" 2>/dev/null)
    max=$(cat "$pol/cpuinfo_max_freq" 2>/dev/null)
    [ -n "$min" ] && write "$min" "$pol/scaling_min_freq"
    [ -n "$max" ] && write "$max" "$pol/scaling_max_freq"
  done

  # Re-enable idle states
  for cpu in 4 5 6 7; do
    for s in /sys/devices/system/cpu/cpu${cpu}/cpuidle/state*/disable; do
      write "0" "$s"
    done
  done

  write "0" /proc/sys/kernel/sched_boost 2>/dev/null

  # --- GPU: auto TZ governor ---
  GPU_BASE="/sys/class/kgsl/kgsl-3d0"
  write "0"   "$GPU_BASE/force_no_nap" 2>/dev/null
  write "6"   "$GPU_BASE/min_pwrlevel" 2>/dev/null
  write "0"   "$GPU_BASE/max_pwrlevel" 2>/dev/null

  # --- Memory: normal balanced ---
  sysctl -w vm.swappiness=60          2>/dev/null
  sysctl -w vm.vfs_cache_pressure=100 2>/dev/null
  sysctl -w vm.extra_free_kbytes=0    2>/dev/null
  sysctl -w vm.dirty_ratio=20         2>/dev/null
  sysctl -w vm.dirty_background_ratio=5 2>/dev/null

  # WLAN power save back on
  iwconfig wlan0 power on 2>/dev/null || true

  # Restore schedtune
  write "0" /dev/stune/top-app/schedtune.boost 2>/dev/null

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
is_game() {
  local pkg="$1"
  for game in $GAMES; do
    [ "$pkg" = "$game" ] && return 0
  done
  return 1
}

###############################################################################
# MAIN MONITOR LOOP
###############################################################################
LAST_STATE="normal"
LAST_GAME=""
CHECK_INTERVAL=5  # seconds

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
        write "$game_pid" /dev/cpuctl/top-app/tasks 2>/dev/null || true
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
