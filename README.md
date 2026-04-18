# Windrose dedicated server on Linux via Docker

Runs the Windows version of the Windrose Dedicated Server inside Wine in a Docker container.
Works on any Linux VPS without a GPU — display is emulated via `xvfb-run`.

## Files

- `Dockerfile` — installs Wine staging and SteamCMD.
- `entrypoint.sh` — updates the game via SteamCMD on startup, initializes the Wine prefix, and launches the server.
- `docker-compose.yml` — network (`host`), volumes, and environment variables.
- `.env.example` — settings template; copy to `.env` and edit before running.

## Quick start (VPS)

1. Copy the environment template:

   ```bash
   cp .env.example .env
   ```

2. Set the server's public IP in `.env`:

   ```
   SERVER_ARGS=-log -P2pProxyAddress=1.2.3.4
   ```

   Without this, the game's P2PGate relay (ICE/STUN) cannot connect back to the server and players will be disconnected.

3. Build and start:

   ```bash
   make up-build
   ```

4. Follow logs:

   ```bash
   make logs-f
   ```

   The server is ready when `InviteCode = ...` appears in the logs.

## Environment variables (`.env`)

| Variable | Default | Description |
|---|---|---|
| `APP_ID` | `4129620` | Steam App ID for Windrose DS |
| `SERVER_EXE` | `R5/Binaries/Win64/WindroseServer-Win64-Shipping.exe` | Path to the binary inside `INSTALL_DIR` |
| `SERVER_ARGS` | `-log -P2pProxyAddress=YOUR_PUBLIC_IP` | Launch arguments. **Required:** replace with your actual public IP |
| `SKIP_UPDATE` | `0` | Set to `1` to skip SteamCMD (for debugging). Keep `0` in production |
| `AUTO_RECREATE_PREFIX` | `1` | Recreate the Wine prefix automatically if initialization fails |
| `WINEBOOT_TIMEOUT_SECS` | `180` | Timeout for Wine prefix initialization |
| `WINEPREFIX` | `/home/steam/windrose/pfx` | Path to the Wine prefix inside the container |
| `WINEDEBUG` | `-all` | Suppress verbose Wine debug output |
| `TZ` | `Europe/Kyiv` | Container timezone |

## Makefile

```bash
make help       # list all available targets
make up-build   # build image and start
make logs-f     # follow container logs
make restart    # restart (applies game updates)
make down       # stop and remove container
make down-v     # same as down, plus remove named volumes
make ps         # service status
make sh         # open a shell inside the container
```

## Networking

Compose uses `network_mode: host` — the container shares the host network stack directly.
This is required: the game uses ICE/STUN through a proprietary P2PGate relay (`18.198.170.147:3478`),
which establishes a return connection to the address specified in `P2pProxyAddress`.

> **WSL2 is not suitable for production** — double NAT prevents P2PGate from reaching the container (error 10054).
> Use a VPS with a public IP assigned directly to a network interface.

## Volumes (data)

- `./data` → `/home/steam/windrose` — game files (4+ GB after download), Wine prefix, `Saved/` with configs and saves.
- `./logs` → `/home/steam/logs` — entrypoint and wineboot logs.

Data persists across `docker compose down`. To fully reset:

```bash
docker compose down
sudo rm -rf data/ logs/
```

## First launch

The first start takes a while:
1. SteamCMD downloads ~4 GB of game files.
2. Wine initializes the prefix (~1–3 min).
3. UE5 loads assets.

The server is ready when `InviteCode = <code>` appears in the logs.

## Troubleshooting

```bash
# Container logs
make logs-f

# Wine prefix initialization
tail -f logs/wineboot.log

# Entrypoint
tail -f logs/entrypoint.log

# Restart without update (fast)
SKIP_UPDATE=1 docker compose up -d
```
