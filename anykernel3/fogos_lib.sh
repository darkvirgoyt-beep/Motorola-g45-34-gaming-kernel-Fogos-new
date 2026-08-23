#!/system/bin/sh
# Shared FogOS helpers used by the AnyKernel runtime scripts.
# This file intentionally avoids voltage, clock-table, thermal, and AVB changes.

[ -n "${FOG_LIB_LOADED:-}" ] && return 0
FOG_LIB_LOADED=1

FOG_GAMES="com.pubg.imobile com.tencent.ig com.dts.freefireth com.dts.freefiremax"
FOG_BIG_MASK="f0"

fog_write() {
    echo "$1" > "$2" 2>/dev/null
}

fog_write_if() {
    [ -e "$2" ] && fog_write "$1" "$2"
}

fog_is_game() {
    for _game in $FOG_GAMES; do
        [ "$1" = "$_game" ] && return 0
    done
    return 1
}

fog_pin_big_cores() {
    _pid="$1"
    _nice="${2:--20}"
    [ -n "$_pid" ] || return 1
    taskset -p "$FOG_BIG_MASK" "$_pid" 2>/dev/null
    renice -n "$_nice" -p "$_pid" 2>/dev/null
    fog_write "$_pid" /dev/cpuctl/top-app/tasks
    fog_write "$_pid" /dev/cpuset/top-app/tasks
    return 0
}
