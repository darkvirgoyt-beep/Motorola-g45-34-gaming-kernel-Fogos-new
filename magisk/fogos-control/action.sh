#!/system/bin/sh

PROFILE_DEV=/dev/fogos_profile
STATE_DIR=/data/adb/fogos-control
STATE_FILE=$STATE_DIR/profile

case "$1" in
    get)
        [ -r "$PROFILE_DEV" ] || exit 2
        tr -d '\r\n' < "$PROFILE_DEV"
        ;;
    set)
        case "$2" in
            balanced|performance|extreme_gaming) ;;
            *) echo "invalid profile" >&2; exit 2 ;;
        esac
        [ -w "$PROFILE_DEV" ] || { echo "FogOS profile device unavailable" >&2; exit 3; }
        printf '%s\n' "$2" > "$PROFILE_DEV" || exit 4
        mkdir -p "$STATE_DIR"
        printf '%s\n' "$2" > "$STATE_FILE"
        chmod 0644 "$STATE_FILE"
        ;;
    *)
        echo "usage: action.sh {get|set} [balanced|performance|extreme_gaming]" >&2
        exit 2
        ;;
esac
