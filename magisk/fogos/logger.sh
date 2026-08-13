#!/system/bin/sh
fogos_log() {
  mkdir -p "${FOGOS_LOG_DIR:-/data/local/fogos}" 2>/dev/null
  echo "[FogOS][$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "${FOGOS_LOG_FILE:-/data/local/fogos/fogos.log}" 2>/dev/null
}
