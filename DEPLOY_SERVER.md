# Deploy To VPS (White IP)

This guide prepares the project for a server deployment with `VLESS + Reality` on port `443`.

## 1. Install Docker on server

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"
newgrp docker
```

## 2. Clone project

```bash
git clone https://github.com/yarodya1/telegram-vpn-bot.git
cd telegram-vpn-bot
```

## 3. Run deployment script

```bash
BOT_TOKEN='YOUR_BOT_TOKEN' \
ADMIN_ID='7878827152' \
SERVER_IP='77.95.201.3' \
./scripts/deploy_server.sh
```

What this script does:
- generates `.env` and `.env.marzban`,
- generates self-signed certs in `./certs`,
- generates a new Reality key pair and short id,
- rewrites `marzban/xray_config.json`,
- runs `docker compose up -d --build --force-recreate marzban vpn_bot`.

Optional:
- add `DEPLOY_NGINX=true` to also run nginx and expose panel at `https://<SERVER_IP>:8444/dashboard/`.

## 4. Open firewall ports

Allow:
- `443/tcp` (required for VLESS Reality)
- `80/tcp` (optional, only if nginx is enabled)
- `8444/tcp` (optional, only if nginx is enabled)

## 5. Check status

```bash
docker ps
docker logs --tail 100 free_vpn_bot
docker logs --tail 100 free_vpn_bot_marzban
```

## 6. Open Marzban panel

By default `8002` is bound to localhost for security.
Use SSH tunnel:

```bash
ssh -L 8002:127.0.0.1:8002 <user>@77.95.201.3
```

Then open:

`https://localhost:8002/dashboard/`

Default admin credentials:
- login: `admin`
- password: `admin`

Change credentials after first login.
