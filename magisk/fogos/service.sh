#!/system/bin/sh
MODDIR=${0%/*}
sleep 20
sh "$MODDIR/profile_manager.sh"
(
  last=""
  while true; do
    fg="$(dumpsys activity activities 2>/dev/null | sed -n 's/.*topResumedActivity.* \([^/ ]*\)\/.*/\1/p' | head -1)"
    game=0
    . "$MODDIR/config.sh"
    for pkg in $FOGOS_GAME_PACKAGES; do [ "$fg" = "$pkg" ] && game=1; done
    if [ "$game" = 1 ] && [ "$last" != game ]; then echo extreme_gaming > "$FOGOS_PROFILE_FILE"; sh "$MODDIR/profile_manager.sh" extreme_gaming; last=game; fi
    if [ "$game" = 0 ] && [ "$last" = game ]; then echo balanced > "$FOGOS_PROFILE_FILE"; sh "$MODDIR/profile_manager.sh" balanced; last=normal; fi
    sleep 10
  done
) &
