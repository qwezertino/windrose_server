# Windrose dedicated server on Linux via Docker

This setup runs the Windows version of the Windrose dedicated server inside Wine in a Docker container.

## Files

- `Dockerfile` installs Wine staging and SteamCMD.
- `entrypoint.sh` updates the game on startup and launches the server.
- `docker-compose.yml` defines ports, volumes, and environment variables.
- `.env.example` contains tunable runtime settings.

## Quick start

1. Copy environment template:

   ```bash
   cp .env.example .env
   ```

2. Build and run:

   ```bash
   docker compose up -d --build
   ```

3. Follow logs:

   ```bash
   docker logs -f windrose_server
   ```

## Volumes

- `./data` maps to `/home/steam/windrose` and stores game files plus Wine prefix.
- `./logs` maps to `/home/steam/logs` for your custom logs if needed.
- This means server config and world saves remain on host across container recreation.

## Useful commands

Restart with auto-update:

```bash
docker compose restart
```

Run without update (debugging):

```bash
SKIP_UPDATE=1 docker compose up -d
```

Stop and remove container:

```bash
docker compose down
```

## Ports

According to the official Windrose dedicated guide, there is no fixed public port list.
The server uses dynamic NAT punch-through (ICE/STUN), typically relying on UPnP.

For this reason, `docker-compose.yml` uses `network_mode: host` on Linux instead of static `ports:` mappings.

If clients on the same LAN still cannot connect, the official guide includes a Docker bridge NAT workaround using:

- iptables no-MASQUERADE rule on the host
- a route to the Docker subnet on LAN clients

Host networking usually avoids that LAN issue by bypassing Docker bridge NAT.

## Persistence and docker compose down

`docker compose down` removes containers and the compose network, but it does not delete host bind mounts.

In this project:

- `./data` persists server files, `ServerDescription.json`, world data under `R5/Saved/...`, and Wine prefix
- `./logs` persists logs

So your progress and settings survive `docker compose down`.

## Notes

- First launch can take a long time because Wine and game assets are initialized.
- If Steam app id or executable name changes, update `.env`.
- If Wine errors on startup, check container logs and verify host supports running Docker with required kernel features.
