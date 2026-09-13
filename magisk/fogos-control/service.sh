#!/system/bin/sh

MODDIR=${0%/*}
PROFILE_DEV=/dev/fogos_profile
STATE_DIR=/data/adb/fogos-control
STATE_FILE=$STATE_DIR/profile

mkdir -p "$STATE_DIR"
chmod 0755 "$STATE_DIR"

# Wait briefly for the built-in misc device to appear after boot.
for _ in $(seq 1 30); do
    [ -e "$PROFILE_DEV" ] && break
    sleep 1
done

# Performance is the shipped default unless the user selected another profile.
profile=performance
[ -r "$STATE_FILE" ] && profile=$(tr -d '\r\n ' < "$STATE_FILE")
case "$profile" in
    balanced|performance|extreme_gaming) ;;
    *) profile=performance ;;
esac

if [ -w "$PROFILE_DEV" ]; then
    printf '%s\n' "$profile" > "$PROFILE_DEV"
    printf '%s\n' "$profile" > "$STATE_FILE"
    chmod 0644 "$STATE_FILE"
fi
