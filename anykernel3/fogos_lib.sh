#!/system/bin/sh
# Shared FogOS helpers used by the AnyKernel runtime scripts.
# This file intentionally avoids voltage, clock-table, thermal, and AVB changes.

[ -n "${FOG_LIB_LOADED:-}" ] && return 0
FOG_LIB_LOADED=1

FOG_GAMES="com.pubg.imobile com.tencent.ig com.dts.freefireth com.dts.freefiremax"
# SM6375/Holi fogos: CPUs 4-7 are the performance cluster. Keep this
# affinity mask fixed and do not write frequency, voltage, or thermal nodes.
FOG_BIG_MASK="f0"
FOG_GAME_NICE="-10"

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
    _nice="${2:-$FOG_GAME_NICE}"
    [ "$_nice" = "-10" ] || _nice="$FOG_GAME_NICE"
    [ -n "$_pid" ] || return 1
    taskset -p "$FOG_BIG_MASK" "$_pid" 2>/dev/null
    renice -n "$_nice" -p "$_pid" 2>/dev/null
    fog_write "$_pid" /dev/cpuctl/top-app/tasks
    fog_write "$_pid" /dev/cpuset/top-app/tasks
    return 0
}
