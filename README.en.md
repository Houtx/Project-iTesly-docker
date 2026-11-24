[中文](README.md) | [English](README.en.md)

# Project-iTesly One-Click Docker Deployment

> Foolproof Docker Compose deployment scripts for the **iTesly** mobile app (iOS / Android), pairing **TeslaMate** with the restricted **iTesly API** server.

---

## Option 1: One-Command VPS Install + Auto Tunnel (For Beginners)

No `git` or Docker pre-installation required. Paste this single command into your Linux VPS / macOS terminal:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Houtx/Project-iTesly-docker/main/start.sh)
```

The interactive wizard will:
1. Install Docker automatically (on Linux) if missing.
2. Deploy **TeslaMate + PostgreSQL 18 + Grafana + Mosquitto + iTesly API** with auto-generated strong secrets and the least-privilege `teslamate_app` database role.
3. Optionally configure **Caddy automatic HTTPS** (recommended, with your own domain), or use **Cloudflare Quick Tunnel** (`https://xxx.trycloudflare.com`, zero domain needed for quick testing).
4. Print the exact **Server URL** and **API Token** to paste into the **iTesly** mobile app.

---

## Option 2: Attach to Existing TeslaMate / Advanced Setup

If you already run TeslaMate, attach `itesly-api` without restarting your existing stack:

```bash
git clone https://github.com/Houtx/Project-iTesly-docker.git
cd Project-iTesly-docker
./install.sh --attach /path/to/your/teslamate
```

Non-interactive flags for fresh installs:
- `./install.sh --official --tunnel` (Official TeslaMate + Cloudflare Quick Tunnel)
- `./install.sh --cn --domain itesly.example.com` (Chinese Grafana + Caddy HTTPS)

---

## Option 3: Let Your AI Agent Deploy It for You

Send this repository URL to your AI coding agent (Antigravity, Claude Code, Cursor, Codex, etc.) with your server SSH details and domain.

**Agent Instructions:**
1. Download the repo and run `install.sh` with **non-interactive flags** (never block on interactive `read` prompts):
   - Fresh install + domain HTTPS: `./install.sh --official --domain <domain>` (or `--cn --domain <domain>`)
   - Fresh install without domain: `./install.sh --official`
   - Attach to existing TeslaMate: `./install.sh --attach <teslamate_dir>`
   - Bind domain later: `./install.sh --bind-domain <domain>`
2. Verify `curl -fsS http://127.0.0.1:8080/app/api/v1/service-health` returns `{"status":"ok",...}` (and `https://<domain>/app/api/v1/service-health` if a domain was bound).
3. Return **only** the iTesly App **Server URL**, **`ITESLY_API_TOKEN`**, and the TeslaMate onboarding URL (`http://<ip>:4000`, reminding the user to generate tokens with Tesla Auth: https://github.com/adriankumpf/tesla_auth/releases). Do not print `DATABASE_PASS` or `ENCRYPTION_KEY`.

---

## Bind a Domain Later (Auto HTTPS)

If you deployed without a domain initially, point your domain's `A` record to your server IP, open ports `80` and `443`, and run:

```bash
cd ~/Project-iTesly-docker
./install.sh --bind-domain itesly.example.com
```

Caddy will automatically issue and renew your free Let's Encrypt TLS certificate without touching your existing database or API token.

---

## License

Licensed under [GPL-3.0](LICENSE).
