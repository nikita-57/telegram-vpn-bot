#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_cmd docker
require_cmd openssl
require_cmd awk

BOT_TOKEN="${BOT_TOKEN:-}"
ADMIN_ID="${ADMIN_ID:-}"
SERVER_IP="${SERVER_IP:-}"
DOMAIN="${DOMAIN:-$SERVER_IP}"
SERVER_URL="${SERVER_URL:-/}"
USE_WEBHOOK="${USE_WEBHOOK:-False}"
MARZ_HAS_CERTIFICATE="${MARZ_HAS_CERTIFICATE:-False}"

MARZBAN_SUDO_USERNAME="${MARZBAN_SUDO_USERNAME:-admin}"
MARZBAN_SUDO_PASSWORD="${MARZBAN_SUDO_PASSWORD:-admin}"

REALITY_DEST="${REALITY_DEST:-www.cloudflare.com:443}"
REALITY_SERVER_NAME="${REALITY_SERVER_NAME:-www.cloudflare.com}"
REALITY_SPIDER_X="${REALITY_SPIDER_X:-/}"

if [[ -z "$BOT_TOKEN" ]]; then
  echo "BOT_TOKEN is required" >&2
  exit 1
fi

if [[ -z "$ADMIN_ID" ]]; then
  echo "ADMIN_ID is required" >&2
  exit 1
fi

if [[ -z "$SERVER_IP" ]]; then
  echo "SERVER_IP is required" >&2
  exit 1
fi

CERT_DIR="${CERT_DIR:-$PROJECT_ROOT/certs}"
CERT_FULLCHAIN_PATH="${CERT_FULLCHAIN_PATH:-$CERT_DIR/fullchain.pem}"
CERT_KEY_PATH="${CERT_KEY_PATH:-$CERT_DIR/privkey.pem}"

mkdir -p "$CERT_DIR"

if [[ ! -f "$CERT_FULLCHAIN_PATH" || ! -f "$CERT_KEY_PATH" ]]; then
  echo "Generating self-signed certificate in $CERT_DIR"
  openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$CERT_KEY_PATH" \
    -out "$CERT_FULLCHAIN_PATH" \
    -days 365 \
    -subj "/CN=$DOMAIN"
fi

REALITY_PRIVATE_KEY="${REALITY_PRIVATE_KEY:-}"
REALITY_PUBLIC_KEY="${REALITY_PUBLIC_KEY:-}"

if [[ -z "$REALITY_PRIVATE_KEY" || -z "$REALITY_PUBLIC_KEY" ]]; then
  echo "Generating Reality key pair"
  KEY_OUTPUT="$(docker run --rm --entrypoint xray gozargah/marzban:v0.8.4 x25519)"
  REALITY_PRIVATE_KEY="$(printf '%s\n' "$KEY_OUTPUT" | awk '/Private key:/ {print $3}')"
  REALITY_PUBLIC_KEY="$(printf '%s\n' "$KEY_OUTPUT" | awk '/Public key:/ {print $3}')"
fi

if [[ -z "$REALITY_PRIVATE_KEY" || -z "$REALITY_PUBLIC_KEY" ]]; then
  echo "Failed to generate Reality key pair" >&2
  exit 1
fi

REALITY_SHORT_ID="${REALITY_SHORT_ID:-$(openssl rand -hex 8)}"

cat > "$PROJECT_ROOT/.env" <<EOF
BOT_TOKEN='${BOT_TOKEN}'
BOT_IP=127.0.0.1
SERVER_URL='${SERVER_URL}'
DOMAIN='${DOMAIN}'
USE_WEBHOOK=${USE_WEBHOOK}
ADMIN=${ADMIN_ID}
MARZ_HAS_CERTIFICATE=${MARZ_HAS_CERTIFICATE}
CERT_FULLCHAIN_PATH='${CERT_FULLCHAIN_PATH}'
CERT_KEY_PATH='${CERT_KEY_PATH}'
EOF

cat > "$PROJECT_ROOT/.env.marzban" <<EOF
SUDO_USERNAME=${MARZBAN_SUDO_USERNAME}
SUDO_PASSWORD=${MARZBAN_SUDO_PASSWORD}
UVICORN_SSL_CERTFILE=/etc/marzban/certs/fullchain.pem
UVICORN_SSL_KEYFILE=/etc/marzban/certs/privkey.pem
UVICORN_SSL_CA_TYPE=private
EOF

cat > "$PROJECT_ROOT/marzban/xray_config.json" <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "routing": {
    "rules": [
      {
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "BLOCK",
        "type": "field"
      }
    ]
  },
  "inbounds": [
    {
      "tag": "VLESS TCP REALITY",
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "${REALITY_DEST}",
          "serverNames": [
            "${REALITY_SERVER_NAME}"
          ],
          "privateKey": "${REALITY_PRIVATE_KEY}",
          "publicKey": "${REALITY_PUBLIC_KEY}",
          "shortIds": [
            "${REALITY_SHORT_ID}"
          ],
          "SpiderX": "${REALITY_SPIDER_X}"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "DIRECT"
    },
    {
      "protocol": "blackhole",
      "tag": "BLOCK"
    }
  ]
}
EOF

SERVICES=(marzban vpn_bot)
if [[ "${DEPLOY_NGINX:-false}" == "true" ]]; then
  SERVICES+=(nginx)
fi

echo "Starting services: ${SERVICES[*]}"
docker compose up -d --build --force-recreate "${SERVICES[@]}"

echo
echo "Deployment completed"
echo "Server IP: $SERVER_IP"
echo "Reality port: 443/tcp"
echo "Reality public key: $REALITY_PUBLIC_KEY"
echo "Reality short id: $REALITY_SHORT_ID"
echo
echo "Container status:"
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
echo
echo "Marzban panel (SSH tunnel): ssh -L 8002:127.0.0.1:8002 <user>@${SERVER_IP}"
if [[ "${DEPLOY_NGINX:-false}" == "true" ]]; then
  echo "Marzban panel (public): https://${SERVER_IP}:8444/dashboard/"
fi
