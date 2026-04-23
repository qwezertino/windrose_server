#!/usr/bin/env bash
set -euo pipefail

STEAMCMD="/home/steam/steamcmd/steamcmd.sh"
INSTALL_DIR="${INSTALL_DIR:-/home/steam/windrose}"
APP_ID="${APP_ID:-4129620}"
SERVER_EXE="${SERVER_EXE:-R5/Binaries/Win64/WindroseServer-Win64-Shipping.exe}"
SERVER_ARGS="${SERVER_ARGS:-}"
SKIP_UPDATE="${SKIP_UPDATE:-0}"
STEAM_USERNAME="${STEAM_USERNAME:-}"
STEAM_PASSWORD="${STEAM_PASSWORD:-}"
STEAM_GUARD_CODE="${STEAM_GUARD_CODE:-}"
STEAMCMD_TIMEOUT_SECS="${STEAMCMD_TIMEOUT_SECS:-300}"
AUTO_RECREATE_PREFIX="${AUTO_RECREATE_PREFIX:-1}"
WINEBOOT_LOG_DIR="/home/steam/logs"
WINEBOOT_LOG_FILE="${WINEBOOT_LOG_DIR}/wineboot.log"
WINEBOOT_TIMEOUT_SECS="${WINEBOOT_TIMEOUT_SECS:-180}"
ENTRYPOINT_LOG_FILE="${WINEBOOT_LOG_DIR}/entrypoint.log"

# RocksDB tmpfs settings
ROCKSDB_TMPFS="${ROCKSDB_TMPFS:-0}"
ROCKSDB_BACKUP_INTERVAL="${ROCKSDB_BACKUP_INTERVAL:-300}"
ROCKSDB_DIR="$INSTALL_DIR/R5/Saved/SaveProfiles/Default/RocksDB"
ROCKSDB_RAM="/tmpfs/rocksdb"
ROCKSDB_BACKUP="/home/steam/rocksdb-backup"

# Avoid GUI installers (Mono/Gecko) blocking startup in headless containers.
export WINEDLLOVERRIDES="mscoree,mshtml="

mkdir -p "$INSTALL_DIR"
mkdir -p "$WINEPREFIX"
mkdir -p "$WINEBOOT_LOG_DIR"

# Mirror entrypoint output to Docker logs and a persistent host-mounted file.
exec > >(tee -a "$ENTRYPOINT_LOG_FILE") 2>&1

# ── RocksDB tmpfs helpers ──────────────────────────────────────────────────────
setup_rocksdb_tmpfs() {
  echo "--- Setting up RocksDB on tmpfs ---"
  mkdir -p "$ROCKSDB_RAM" "$ROCKSDB_BACKUP"

  # If RocksDB dir is a real directory (not symlink), move data to backup first
  if [[ -d "$ROCKSDB_DIR" && ! -L "$ROCKSDB_DIR" ]]; then
    echo "Moving existing RocksDB data to backup..."
    rsync -a --delete "$ROCKSDB_DIR/" "$ROCKSDB_BACKUP/"
    rm -rf "$ROCKSDB_DIR"
  fi

  # Restore backup to tmpfs (RAM)
  if [[ -d "$ROCKSDB_BACKUP" ]] && ls -A "$ROCKSDB_BACKUP" &>/dev/null; then
    echo "Restoring RocksDB from backup to tmpfs..."
    rsync -a "$ROCKSDB_BACKUP/" "$ROCKSDB_RAM/"
    echo "Restored $(du -sh "$ROCKSDB_RAM" | cut -f1) to tmpfs"
  fi

  # Create parent dirs and symlink
  mkdir -p "$(dirname "$ROCKSDB_DIR")"
  ln -sfn "$ROCKSDB_RAM" "$ROCKSDB_DIR"
  echo "RocksDB symlinked: $ROCKSDB_DIR -> $ROCKSDB_RAM"
}

backup_rocksdb() {
  if [[ -d "$ROCKSDB_RAM" ]] && ls -A "$ROCKSDB_RAM" &>/dev/null; then
    rsync -a --delete "$ROCKSDB_RAM/" "$ROCKSDB_BACKUP/"
    echo "[$(date +%H:%M:%S)] RocksDB backed up ($(du -sh "$ROCKSDB_BACKUP" | cut -f1))"
  fi
}

rocksdb_backup_loop() {
  while true; do
    sleep "$ROCKSDB_BACKUP_INTERVAL"
    backup_rocksdb
  done
}

# ── Graceful shutdown ──────────────────────────────────────────────────────────
WINE_PID=""
BACKUP_PID=""

cleanup() {
  echo "--- Graceful shutdown ---"

  # Stop wine server
  if [[ -n "$WINE_PID" ]] && kill -0 "$WINE_PID" 2>/dev/null; then
    echo "Stopping Wine process (PID $WINE_PID)..."
    kill -TERM "$WINE_PID"
    wait "$WINE_PID" 2>/dev/null || true
  fi

  # Final RocksDB backup
  if [[ "$ROCKSDB_TMPFS" == "1" ]]; then
    echo "Final RocksDB backup..."
    backup_rocksdb
  fi

  # Kill background jobs
  kill "$BACKUP_PID" 2>/dev/null || true
  echo "Shutdown complete."
  exit 0
}

trap cleanup SIGTERM SIGINT

if [[ ! -x "$STEAMCMD" ]]; then
  echo "SteamCMD not found or not executable: ${STEAMCMD}"
  exit 1
fi

run_steamcmd_update_anonymous() {
  timeout "${STEAMCMD_TIMEOUT_SECS}" "$STEAMCMD" +@sSteamCmdForcePlatformType windows \
    +force_install_dir "$INSTALL_DIR" \
    +login anonymous \
    +app_update "$APP_ID" validate \
    +quit
}

run_steamcmd_update_auth() {
  if [[ -n "$STEAM_GUARD_CODE" ]]; then
    timeout "${STEAMCMD_TIMEOUT_SECS}" "$STEAMCMD" +@sSteamCmdForcePlatformType windows \
      +force_install_dir "$INSTALL_DIR" \
      +login "$STEAM_USERNAME" "$STEAM_PASSWORD" \
      +set_steam_guard_code "$STEAM_GUARD_CODE" \
      +app_update "$APP_ID" validate \
      +quit
  else
    timeout "${STEAMCMD_TIMEOUT_SECS}" "$STEAMCMD" +@sSteamCmdForcePlatformType windows \
      +force_install_dir "$INSTALL_DIR" \
      +login "$STEAM_USERNAME" "$STEAM_PASSWORD" \
      +app_update "$APP_ID" validate \
      +quit
  fi
}

if [[ "$SKIP_UPDATE" != "1" ]]; then
  echo "--- Starting SteamCMD update for app ${APP_ID} ---"
  if run_steamcmd_update_anonymous; then
    echo "SteamCMD update succeeded with anonymous login."
  else
    rc=$?
    if [[ "$rc" -eq 124 ]]; then
      echo "Anonymous SteamCMD update timed out after ${STEAMCMD_TIMEOUT_SECS}s."
    else
      echo "Anonymous SteamCMD update failed for app ${APP_ID} (exit code ${rc})."
    fi
    if [[ -n "$STEAM_USERNAME" && -n "$STEAM_PASSWORD" ]]; then
      echo "Retrying SteamCMD update with Steam account credentials..."
      if run_steamcmd_update_auth; then
        echo "SteamCMD update succeeded with account credentials."
      else
        rc=$?
        if [[ "$rc" -eq 124 ]]; then
          echo "SteamCMD update with account credentials timed out after ${STEAMCMD_TIMEOUT_SECS}s."
        else
          echo "SteamCMD update with account credentials failed (exit code ${rc})."
        fi
        exit 1
      fi
    else
      echo "Set STEAM_USERNAME and STEAM_PASSWORD in environment to update non-anonymous app access."
      exit 1
    fi
  fi
else
  echo "--- SKIP_UPDATE=1, skipping SteamCMD update ---"
fi

echo "--- Initializing Wine prefix ---"

init_wine_prefix() {
  timeout "${WINEBOOT_TIMEOUT_SECS}" wineboot --init >>"$WINEBOOT_LOG_FILE" 2>&1
}

if ! init_wine_prefix; then
  echo "Wine prefix init failed. See ${WINEBOOT_LOG_FILE}"
  if [[ "$AUTO_RECREATE_PREFIX" == "1" ]]; then
    BROKEN_PREFIX="${WINEPREFIX}.broken.$(date +%s)"
    echo "Backing up broken prefix to: ${BROKEN_PREFIX}"
    mv "$WINEPREFIX" "$BROKEN_PREFIX"
    mkdir -p "$WINEPREFIX"
    echo "Retrying Wine prefix init from clean state..."
    init_wine_prefix
  else
    echo "AUTO_RECREATE_PREFIX=0, not recreating prefix"
    exit 1
  fi
fi

echo "--- Starting Windrose server ---"
cd "$INSTALL_DIR"

# Add -log if no explicit args
if [[ -z "$SERVER_ARGS" ]]; then
  SERVER_ARGS="-log"
fi

if [[ ! -f "$SERVER_EXE" ]]; then
  echo "Server executable not found: ${INSTALL_DIR}/${SERVER_EXE}"
  echo "Check APP_ID/SERVER_EXE and SteamCMD download logs."
  exit 1
fi

if [[ -n "$SERVER_ARGS" ]]; then
  # shellcheck disable=SC2206
  ARGS=( $SERVER_ARGS )
else
  ARGS=()
fi

# Set up RocksDB tmpfs if enabled
if [[ "$ROCKSDB_TMPFS" == "1" ]]; then
  setup_rocksdb_tmpfs
  rocksdb_backup_loop &
  BACKUP_PID=$!
  echo "RocksDB backup loop started (every ${ROCKSDB_BACKUP_INTERVAL}s, PID $BACKUP_PID)"
fi

echo "Launcher: ${SERVER_EXE} ${SERVER_ARGS}"

case "${SERVER_EXE,,}" in
  *.bat|*.cmd)
    nice -n -10 xvfb-run -a -s "-screen 0 1024x768x24" wine cmd /c "$SERVER_EXE" "${ARGS[@]}" &
    WINE_PID=$!
    ;;
  *)
    nice -n -10 xvfb-run -a -s "-screen 0 1024x768x24" wine "$SERVER_EXE" "${ARGS[@]}" &
    WINE_PID=$!
    ;;
esac

echo "Wine started (PID $WINE_PID)"
wait "$WINE_PID" 2>/dev/null || true
rc=$?
echo "Server process exited with code ${rc}"

# Final backup on normal exit (not signal)
if [[ "$ROCKSDB_TMPFS" == "1" ]]; then
  echo "Final RocksDB backup..."
  backup_rocksdb
fi

kill "$BACKUP_PID" 2>/dev/null || true
exit "$rc"
