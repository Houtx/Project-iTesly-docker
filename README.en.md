[中文](README.md) | [English](README.en.md)

# Project-iTesly One-Click Docker Deployment

> Foolproof Docker Compose deployment scripts for the **iTesly** mobile app (iOS / Android), pairing **TeslaMate** with the restricted **iTesly API** server.

---

## Features

- **Zero-config one-click wizard (`./install.sh`)**: Automatically generates strong random secrets, creates the restricted `teslamate_app` PostgreSQL role, starts all containers, and prints the exact **Server URL** and **API Token** to paste into your phone.
- **Two deployment modes**:
  1. **Fresh Install**: Deploys TeslaMate + PostgreSQL 18 + Grafana + Mosquitto + iTesly API in one command.
  2. **Attach to Existing TeslaMate**: Zero-downtime integration with your existing TeslaMate Compose directory without restarting TeslaMate or PostgreSQL.
- **Live OTA Update Alerts**: Automatically subscribes to TeslaMate's Mosquitto MQTT `update_available` / `update_version` topics so the iTesly home screen shows pending OTA badges.
- **Least-Privilege Security**: Mobile clients never store Tesla OAuth credentials or connect directly to PostgreSQL/MQTT.

---

## Quick Start

### 1. Clone & Run the Wizard

```bash
git clone https://github.com/Houtx/Project-iTesly-docker.git
cd Project-iTesly-docker
./install.sh
```

Non-interactive shortcuts:
- Fresh install (Official TeslaMate + Grafana): `./install.sh --official`
- Fresh install (China-optimized Chinese Grafana): `./install.sh --cn`
- Attach to an existing TeslaMate directory: `./install.sh --attach /path/to/teslamate`

### 2. Connect the iTesly Mobile App

Once `./install.sh` finishes, copy the printed **Server URL** (e.g. `http://192.168.1.10:8080` or your HTTPS reverse-proxy URL) and **API Token** (`ITESLY_API_TOKEN`) into the **iTesly** app onboarding screen (or **Settings → Self-Hosted Server**).

For fresh installs, open `http://<server-ip>:4000` once to sign in to TeslaMate with your Tesla account.

---

## License

Licensed under [GPL-3.0](LICENSE).
