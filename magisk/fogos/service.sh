#!/system/bin/sh
# FogOS Magisk service.sh
# Runs at Magisk late_start service context (post-boot, after system is ready)
#
# IMPORTANT: Do NOT touch audio.* properties here — doing so after audioserver
# has started will crash the Dolby Atmos spatial audio stack. Profile changes
# are limited to CPU/GPU/scheduler/thermal paths only.

MODDIR="${0%/*}"
. "$MODDIR/config.sh"
. "$MODDIR/logger.sh"

# Wait for system to be fully booted before we do anything
# (avoids racing with audioserver / vendor services during init)
sleep 20

# Restore the last validated profile, or use the configured default.
initial_profile="$(cat "$FOGOS_PROFILE_FILE" 2>/dev/null | tr -d '[:space:]')"
case "$initial_profile" in
    balanced|performance|extreme_gaming) ;;
    *) initial_profile="$FOGOS_DEFAULT_PROFILE" ;;
esac
sh "$MODDIR/profile_manager.sh" "$initial_profile"
fogos_log "service.sh: initial profile=$initial_profile applied"

# Background game detection loop
(
    last_state=""
    while true; do
        # The signed FogOS app writes only a validated profile name to the
        # kernel device. This service, already running in the root module,
        # performs the actual sysfs/sysctl writes.
        requested="$(cat "$FOGOS_PROFILE_DEVICE" 2>/dev/null | tr -d '[:space:]')"
        current="$(cat "$FOGOS_PROFILE_FILE" 2>/dev/null | tr -d '[:space:]')"
        case "$requested" in
            balanced|performance|extreme_gaming)
                if [ "$requested" != "$current" ]; then
                    sh "$MODDIR/profile_manager.sh" "$requested"
                    fogos_log "app request: switched to $requested"
                fi
                ;;
        esac

        # Get the foreground package name
        fg="$(dumpsys activity activities 2>/dev/null \
              | sed -n 's/.*topResumedActivity.* \([^/ ]*\)\/.*/\1/p' \
              | head -1)"

        is_game=0
        for pkg in $FOGOS_GAME_PACKAGES; do
            [ "$fg" = "$pkg" ] && is_game=1 && break
        done

        if [ "$is_game" = "1" ] && [ "$last_state" != "game" ]; then
            echo "extreme_gaming" > "$FOGOS_PROFILE_FILE"
            sh "$MODDIR/profile_manager.sh" extreme_gaming
            fogos_log "game detected: $fg — switched to extreme_gaming"
            last_state="game"
        elif [ "$is_game" = "0" ] && [ "$last_state" = "game" ]; then
            echo "balanced" > "$FOGOS_PROFILE_FILE"
            sh "$MODDIR/profile_manager.sh" balanced
            fogos_log "game exited — switched to balanced"
            last_state="idle"
        fi

        sleep 10
    done
) &
