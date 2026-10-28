# Homelab set up

Docker Compose stacks for a Raspberry Pi 5 home server. Each stack is its own Compose project with its own network, so one can be redeployed (or break) without touching the others.

Services bounded to a single address (in this case PI\_HOST which is the Pi's Tailscale IP), so nothing is exposed on the uplink network. Adguard resolves \*.pi services to the DNS, which Caddy routes to respective services.

## Stacks

| Stack | Services | Purpose |
|---|---|---|
| `dns-stack` | AdGuard Home | DNS filtering, local `*.pi` rewrites |
| `reverse-proxy-stack` | Caddy | Hostname routing, HTTPS via Caddy's internal CA |
| `storage-stack` | File Browser, Samba | Web and SMB access to the storage root |
| `media-stack` | Navidrome | Music streaming |
| `vault-stack` | Vaultwarden | Password manager |
| `management-stack` | Portainer | Container dashboard |
| `network-stack` | Gluetun, Tailscale | Optional Tailscale exit node (see below) |

## Setup

1. Clone the repo and create a `.env` at its root (see [Secrets](#secrets) for the variables).
2. Symlink it into each stack so plain `docker compose` picks it up:

   ```bash
   for d in */; do [ -f "$d/docker-compose.yml" ] && ln -sf ../.env "$d/.env"; done
   ```

3. Start each stack with `docker compose up -d` from its folder. Bring up `dns-stack` first, then `reverse-proxy-stack`.

## Secrets

All secrets and host-specific values live in one gitignored `.env` at the repo root. Runtime state (`*-data/`, `*-conf/`, `*-config/`, `*-work/`) is gitignored too. The variables:

| Variable | Used by | Notes |
|---|---|---|
| `PI_HOST` | all stacks | Address services bind to and Caddy proxies to (the Pi's Tailscale IP) |
| `SAMBA_ADMIN_PASS`, `SAMBA_FAMILY_PASS` | `storage-stack` | Samba user passwords |
| `VW_ADMIN_TOKEN` | `vault-stack` | Argon2 hash from `docker run --rm -it vaultwarden/server /vaultwarden hash`; wrap in single quotes since it contains `$` |
| `VW_SIGNUPS_ALLOWED` | `vault-stack` | `true` until your own account exists, then `false` |
| `EXITPI_WG_DIR` | `exitpi` | Optional; defaults to `/etc/wireguard` |

## HTTPS

Caddy issues certificates from its own internal CA (`tls internal`). Trust `reverse-proxy-stack/caddy-data/pki/authorities/local/root.crt` once per device to avoid browser warnings. Vaultwarden's clients require HTTPS, so this is needed there.

## Exit node (`network-stack`)

`exitpi` switches how the Pi acts as a Tailscale exit node:

```bash
exitpi <country>   # exit via ProtonVPN (Gluetun), using /etc/wireguard/<country>.conf
exitpi on          # exit directly through the Pi's own connection, no VPN
exitpi off         # stop the exit node
exitpi status      # show containers and current public IP
```

`network-stack/scripts/exitpi.sh` is symlinked to `/usr/local/bin/exitpi`. WireGuard configs are the unmodified files downloaded from Proton, placed in `/etc/wireguard/` (outside this repo). Gluetun's firewall acts as the kill switch when tunnelled.

## Notes

- The Pi also runs a Wi-Fi hotspot (NetworkManager shared mode) for devices that can't use Tailscale. It is host config, not part of this repo.
- Portainer mounts the Docker socket, so keep it reachable only over the tailnet.
