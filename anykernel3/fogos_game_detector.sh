#!/system/bin/sh
# Conservative foreground-game detector for FogOS AnyKernel installations.
# It records supported games and avoids forcing clocks or disabling thermal limits.

TAG="FogOS-Game"
LOG="/data/local/fogos_game.log"
ACTIVE_LOG="/data/local/fogos_active_game.txt"

for FOG_LIB in \
    "${FOG_LIB:-}" \
    "$(dirname "${BASH_SOURCE:-$0}")/fogos_lib.sh" \
    /system/etc/fogos/fogos_lib.sh \
    /system/bin/fogos_lib.sh; do
    [ -n "$FOG_LIB" ] && [ -f "$FOG_LIB" ] && { . "$FOG_LIB"; break; }
done

# Fallback for test and recovery contexts where the shared library is absent.
if ! command -v fog_write >/dev/null 2>&1; then
    fog_write() { echo "$1" > "$2" 2>/dev/null; }
fi
if ! command -v fog_is_game >/dev/null 2>&1; then
    fog_is_game() {
        case "$1" in
            com.pubg.imobile|com.tencent.ig|com.dts.freefireth|com.dts.freefiremax) return 0 ;;
            *) return 1 ;;
        esac
    }
fi

log() {
    echo "[$TAG][$(date '+%H:%M:%S')] $1" >> "$LOG" 2>/dev/null
}

write() {
    fog_write "$@"
}

truncate_log() {
    [ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -gt 524288 ] && \
        tail -c 262144 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
}

get_foreground_app() {
    _pkg=$(dumpsys activity 2>/dev/null | \
        grep -m1 "mCurrentFocus\|mFocusedApp\|topResumedActivity" | \
        grep -oP '(?<=\{)[^/ ]+/[^}]+' | cut -d/ -f1 | head -1)
    [ -n "$_pkg" ] && { echo "$_pkg"; return; }

    _pkg=$(dumpsys window windows 2>/dev/null | \
        grep -m1 "mCurrentFocus\|Window #" | \
        grep -oP '[a-z][a-z0-9\.]+\.[a-zA-Z0-9\.]+' | head -1)
    [ -n "$_pkg" ] && { echo "$_pkg"; return; }
    echo ""
}

is_game() {
    fog_is_game "$1"
}

apply_game_profile() {
    _game="$1"
    echo "$_game" > "$ACTIVE_LOG" 2>/dev/null
    log "Game detected: $_game"
}

apply_normal_profile() {
    rm -f "$ACTIVE_LOG" 2>/dev/null
    log "No supported game is active"
}

if [ "${FOGOS_LIB_ONLY:-0}" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi

LAST_GAME=""
while true; do
    CURRENT_GAME="$(get_foreground_app)"
    if is_game "$CURRENT_GAME"; then
        [ "$CURRENT_GAME" = "$LAST_GAME" ] || apply_game_profile "$CURRENT_GAME"
        LAST_GAME="$CURRENT_GAME"
    elif [ -n "$LAST_GAME" ]; then
        apply_normal_profile
        LAST_GAME=""
    fi
    sleep 5
done
