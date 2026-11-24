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

## License

Licensed under [GPL-3.0](LICENSE).
