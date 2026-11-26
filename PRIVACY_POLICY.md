# Privacy Policy for iTesly

**Effective Date:** November 26, 2026  
**Developer:** TianZX Ltd.  
**Contact Email:** support@haoyunqiankun.com  
**Application:** iTesly (`io.itesly.app`)  
**Self-Hosting Repository:** https://github.com/Houtx/Project-iTesly-docker

## 1. Overview
iTesly is a native companion application designed exclusively to connect to **your own self-hosted iTesly API proxy & TeslaMate instance**. We respect your privacy and built iTesly under a strict local-first, zero-tracking architecture.

## 2. Information We Do Not Collect
TianZX Ltd. does **not** operate central telemetry servers for iTesly, and we do **not** collect, sell, rent, or access your:
- Tesla account credentials or OAuth tokens (iTesly never connects directly to Tesla servers or prompts for your Tesla login).
- Vehicle location, driving routes, charging history, battery telemetry, or VIN/personal identifiers from your self-hosted database.
- Advertising IDs, behavioral analytics, or third-party tracking SDK profiles (iTesly contains **zero ads** and **zero third-party analytics SDKs**).

## 3. Data Stored Locally on Your Device
To operate the app, the following preferences and credentials are stored strictly **on your device**:
- **Self-Hosted Server URL & Access Token:** Encrypted locally inside **Android Keystore (AES-256-GCM)** and transmitted solely to the server endpoint you configure.
- **Google Play Purchase Token:** Verified via Google Play Billing and cached encrypted locally to preserve offline access to Self-Hosted Server Mode.
- **App Preferences:** Selected UI theme (Liquid Glass), map engine/style, coordinate conversion mode (`AUTO` / `WGS-84` / `GCJ-02`), language, and display units.

## 4. Third-Party Services Used Only for Rendering & Billing
- **Google Play Billing:** One-time lifetime unlock purchases (`$12.99 USD` or localized currency) are processed securely by Google Play. We never see or store your payment card details.
- **Map Tile Providers:** Depending on your selected map style, the app fetches public map tiles from OpenStreetMap / Carto (or AMap tiles if enabled in direct non-Play builds). No personal vehicle identity is sent in tile requests—only viewport tile coordinates.
- **Optional Vehicle Studio Images:** Vehicle appearance previews may fetch static studio render assets directly from Tesla's public configurator CDN using generic model/paint/wheel codes without any VIN or user identifier.
- **Optional External Navigation:** If you tap Navigate, coordinates are passed to your chosen installed navigation app (Google Maps, Waze, etc.).

## 5. Demo Mode
Demo Mode operates 100% locally using synthetic sample data without network calls or account login.

## 6. Data Deletion & Retention
Because TianZX Ltd. does not collect or store your personal or vehicle telemetry on any developer-controlled server, you have complete control over your data:
- Tap **Disconnect / Switch Server** in Settings to immediately wipe your saved server URL and encrypted API token from Android Keystore.
- Uninstall the app or clear app storage to delete all locally cached preferences and map tiles.
- Manage your self-hosted telemetry database directly on your own Docker server.

## 7. Children's Privacy
iTesly is intended for general audiences aged 18+ (vehicle owners/operators) and is not directed to children under 13.

## 8. Contact Us
If you have any questions about this Privacy Policy, support inquiries, or self-hosting assistance, please contact:  
- **Email:** support@haoyunqiankun.com  
- **GitHub:** https://github.com/Houtx/Project-iTesly-docker
