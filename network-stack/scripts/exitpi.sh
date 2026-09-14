#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
COMPOSE_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="${EXITPI_WG_DIR:-/etc/wireguard}"

case "${1:-}" in
    off|stop|down)
        cd "$COMPOSE_DIR" && docker compose stop vpn tailscale-exit
        echo "VPN & Exit Node stopped."
        ;;
    status)
        cd "$COMPOSE_DIR" && docker compose ps
        echo -e "\n--- Public IP ---"
        docker exec vpn wget -qO- ifconfig.me 2>/dev/null || echo "VPN container is down."
        ;;
    "")
        echo "Usage: exitpi <country_code|off|status>"
        echo "Available locations:"
        ls "$CONFIG_DIR"/*.conf 2>/dev/null | xargs -n1 basename | sed 's/\.conf//'
        ;;
    *)
        TARGET="$1.conf"
        if [ -f "$CONFIG_DIR/$TARGET" ]; then
            cd "$CONFIG_DIR" && ln -sf "$1.conf" wg0.conf
            cd "$COMPOSE_DIR" && docker compose up -d --force-recreate vpn tailscale-exit
            echo "SUCCESS: Switched VPN to $1!"
        else
            echo "Error: Config '$1.conf' not found in $CONFIG_DIR"
            ls "$CONFIG_DIR"/*.conf 2>/dev/null | xargs -n1 basename | sed 's/\.conf//'
        fi
        ;;
esac
