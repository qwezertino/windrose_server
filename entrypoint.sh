#!/usr/bin/env bash
set -euo pipefail

STEAMCMD="/home/steam/steamcmd/steamcmd.sh"
INSTALL_DIR="${INSTALL_DIR:-/home/steam/windrose}"
APP_ID="${APP_ID:-4129620}"
SERVER_EXE="${SERVER_EXE:-WindroseServer.exe}"
SERVER_ARGS="${SERVER_ARGS:-}"
SKIP_UPDATE="${SKIP_UPDATE:-0}"

mkdir -p "$INSTALL_DIR"
mkdir -p "$WINEPREFIX"

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
# Use Xvfb to satisfy software expecting a graphical environment.
xvfb-run -a wineboot -u

echo "--- Starting Windrose server ---"
cd "$INSTALL_DIR"

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

exec xvfb-run -a wine "$SERVER_EXE" "${ARGS[@]}"
