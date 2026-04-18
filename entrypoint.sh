#!/usr/bin/env bash
set -euo pipefail

STEAMCMD="/home/steam/steamcmd/steamcmd.sh"
INSTALL_DIR="${INSTALL_DIR:-/home/steam/windrose}"
APP_ID="${APP_ID:-4129620}"
SERVER_EXE="${SERVER_EXE:-R5/Binaries/Win64/WindroseServer-Win64-Shipping.exe}"
SERVER_ARGS="${SERVER_ARGS:-}"
SKIP_UPDATE="${SKIP_UPDATE:-0}"
AUTO_RECREATE_PREFIX="${AUTO_RECREATE_PREFIX:-1}"
WINEBOOT_LOG_DIR="/home/steam/logs"
WINEBOOT_LOG_FILE="${WINEBOOT_LOG_DIR}/wineboot.log"
WINEBOOT_TIMEOUT_SECS="${WINEBOOT_TIMEOUT_SECS:-180}"
ENTRYPOINT_LOG_FILE="${WINEBOOT_LOG_DIR}/entrypoint.log"

# Avoid GUI installers (Mono/Gecko) blocking startup in headless containers.
export WINEDLLOVERRIDES="mscoree,mshtml="

mkdir -p "$INSTALL_DIR"
mkdir -p "$WINEPREFIX"
mkdir -p "$WINEBOOT_LOG_DIR"

# Mirror entrypoint output to Docker logs and a persistent host-mounted file.
exec > >(tee -a "$ENTRYPOINT_LOG_FILE") 2>&1

if [[ ! -x "$STEAMCMD" ]]; then
  echo "SteamCMD not found or not executable: ${STEAMCMD}"
  exit 1
fi

if [[ "$SKIP_UPDATE" != "1" ]]; then
  echo "--- Starting SteamCMD update for app ${APP_ID} ---"
  "$STEAMCMD" +@sSteamCmdForcePlatformType windows \
    +force_install_dir "$INSTALL_DIR" \
    +login anonymous \
    +app_update "$APP_ID" validate \
    +quit
else
  echo "--- SKIP_UPDATE=1, skipping SteamCMD update ---"
fi

echo "--- Initializing Wine prefix ---"

init_wine_prefix() {
  # Use Xvfb to satisfy software expecting a graphical environment.
  timeout "${WINEBOOT_TIMEOUT_SECS}" xvfb-run -a wineboot --init >>"$WINEBOOT_LOG_FILE" 2>&1
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

echo "Launcher: ${SERVER_EXE} ${SERVER_ARGS}"

case "${SERVER_EXE,,}" in
  *.bat|*.cmd)
    set +e
    ionice -c 1 -n 0 nice -n -10 xvfb-run -a wine cmd /c "$SERVER_EXE" "${ARGS[@]}"
    rc=$?
    set -e
    echo "Server process exited with code ${rc}"
    exit "$rc"
    ;;
  *)
    set +e
    ionice -c 1 -n 0 nice -n -10 xvfb-run -a wine "$SERVER_EXE" "${ARGS[@]}"
    rc=$?
    set -e
    echo "Server process exited with code ${rc}"
    exit "$rc"
    ;;
esac
