#!/system/bin/sh
# FogOS runtime initializer. It keeps stock thermal and frequency safety limits.

TAG="FogOS"
LOG="/data/local/fogos_boot.log"

for FOG_LIB in \
    "${FOG_LIB:-}" \
    "$(dirname "${BASH_SOURCE:-$0}")/fogos_lib.sh" \
    /system/etc/fogos/fogos_lib.sh \
    /system/bin/fogos_lib.sh; do
    [ -n "$FOG_LIB" ] && [ -f "$FOG_LIB" ] && { . "$FOG_LIB"; break; }
done

if ! command -v fog_pin_big_cores >/dev/null 2>&1; then
    fog_pin_big_cores() {
        _pid="$1"
        taskset -p f0 "$_pid" 2>/dev/null
        renice -n -20 -p "$_pid" 2>/dev/null
    }
fi
if ! command -v fog_write >/dev/null 2>&1; then
    fog_write() { echo "$1" > "$2" 2>/dev/null; }
fi

log() {
    echo "[$TAG] $1" >> "$LOG" 2>/dev/null
    echo "[$TAG] $1"
}

optimize_game() {
    PKGNAME="$1"
    PID="$(pgrep -f "$PKGNAME" 2>/dev/null | head -1)"
    if [ -n "$PID" ]; then
        # Keep tuning bounded: performance-cluster affinity, a modest nice
        # value, and top-app placement only. Never use FIFO/RT priority.
        fog_pin_big_cores "$PID"
        fog_write_if "$PID" /dev/stune/top-app/tasks
        log "Optimized: $PKGNAME (PID $PID)"
    fi
}

if [ "${FOGOS_LIB_ONLY:-0}" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi

# Runtime tuning is deliberately limited to bounded task placement. It does not
# modify thermal zones, voltage tables, charging limits, or CPU/GPU frequency caps.
log "FogOS runtime helper installed; stock thermal protection remains enabled."
