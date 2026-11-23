[中文](README.md) | [English](README.en.md)

# Project-iTesly 一键部署脚本

> 专为 **iTesly** 移动端（iOS / Android）打造的 **TeslaMate + iTesly API** 傻瓜式 Docker Compose 一键部署仓库。
>
> 无需懂代码、无需手动配数据库权限、无需修改配置文件，**两条命令即可完成全部服务端搭建并直接在终端生成 App 连接信息**。

---

## 为什么选择本部署方案？

- **真正一键开箱即用**：自动生成全部随机强密码、自动初始化 PostgreSQL 只读权限角色 `teslamate_app`、自动拉起所有容器并打印手机端所需地址与 Token。
- **支持两种人群**：
  1. **从未装过 TeslaMate 的新用户**：一键装齐 TeslaMate + PostgreSQL + Grafana + Mosquitto + iTesly API。
  2. **已经装好 TeslaMate 的老用户**：零侵入接入现有 TeslaMate 网络与数据库，**不重启、不修改原有 TeslaMate**。
- **开箱支持车机 OTA 推送提醒**：内置连接 Mosquitto MQTT，iTesly App 首页「系统信息」可直接亮起「新版本推送」与「OTA 升级中」状态徽标。
- **安全隔离**：iTesly 移动端全程不接触你的 Tesla 账号与车控权限，后端仅使用只读数据库角色（仅额外允许记录充电电费）。
- **双版本可选**：提供**中国大陆优化版**（预置中文 Grafana 仪表盘 + 默认 `Asia/Shanghai` 时区）与**国际官方版**。

---

## 一分钟极速部署（小白推荐）

### 前提条件
一台安装好 **Docker** 与 **Docker Compose** 的设备即可（Linux 云服务器、群晖 Synology、威联通 QNAP、飞牛 fnOS、绿联 NAS 或 Mac 均可）。

> 若是全新 Linux 服务器还没装 Docker，先运行：
> ```bash
> curl -fsSL https://get.docker.com | sh
> ```

### 第一步：下载部署脚本并运行向导

```bash
git clone https://github.com/Houtx/Project-iTesly-docker.git
cd Project-iTesly-docker
./install.sh
```

按屏幕提示输入数字选择即可（一路回车默认选择 **全新部署 → 中国大陆优化版**）：

- **模式 1（全新部署）**：适合还没装过 TeslaMate 的用户。脚本会自动拉取镜像、生成随机密码、初始化只读数据库并启动全部服务。
- **模式 2（接入现有 TeslaMate）**：适合已经跑着 TeslaMate 的老用户。输入你原来的 TeslaMate 目录路径，脚本会自动探测数据库容器、网络和 Mosquitto，一键启动 `itesly-api`。

> **非交互静默命令**（可选）：
> - 全新部署中国大陆优化版：`./install.sh --cn`
> - 全新部署国际官方版：`./install.sh --official`
> - 接入已有 TeslaMate 目录：`./install.sh --attach /你的/teslamate/目录`

### 第二步：查看终端输出的连接信息

部署完成后，终端会直接打印类似如下信息：

```text
======================================================================
  Project-iTesly 后端部署成功！请打开手机 iTesly App 按下方信息填写：
======================================================================
  1. 服务地址（局域网）： http://192.168.1.10:8080
     （如配置了 HTTPS 域名反代，请改为 https://你的域名）
  2. 访问令牌（Token）： <自动生成的 64 位随机令牌>
----------------------------------------------------------------------
  TeslaMate 网页后台：   http://192.168.1.10:4000
  （首次使用请先打开上方地址，登录一次 Tesla 账号以开始同步车辆数据）
  Grafana 数据看板：     http://192.168.1.10:3000  (默认账号密码 admin/admin)
======================================================================
```

### 第三步：连接手机端 iTesly App

1. **全新部署用户**：先在电脑/手机浏览器打开 `http://<你的服务器IP>:4000`，使用 Tesla 账号完成一次授权登录（之后 TeslaMate 会自动在后台记录行车与充电数据）。
2. 打开手机上的 **iTesly** App（首次进入在引导页，或已进入演示模式后前往 **「设置 → 自建服务配置」**）：
   - **服务地址**：填入 `http://<你的服务器IP>:8080`（如已配置公网 HTTPS 反代，则填 `https://你的域名`）
   - **访问令牌**：复制粘贴终端打印的 `ITESLY_API_TOKEN`
3. 点击保存并连接，即可看到自己的爱车数据！

---

## 公网远程访问建议（出门也能看车）

- **家庭局域网 / 组网用户（最简单）**：使用 Tailscale / ZeroTier / WireGuard 异地组网，App 始终填写内网/组网 IP `http://100.x.x.x:8080` 即可，无需域名和公网 IP，安全且零成本。
- **有域名/云服务器用户（HTTPS 反代）**：建议使用 Caddy、Nginx 或 Cloudflare Tunnel 将公网 `https://itesly.你的域名` 反向代理到本机 `http://127.0.0.1:8080`。
  - Caddy 极简示例（自动申请 HTTPS 证书）：
    ```caddyfile
    itesly.example.com {
        reverse_proxy 127.0.0.1:8080
    }
    ```

---

## 常用运维命令

| 操作 | 命令 |
| :--- | :--- |
| 查看所有容器运行状态 | `docker compose ps`（中国优化版加 `-f docker-compose.cn.yml`） |
| 更新后端到最新版本 | `docker compose pull itesly-api && docker compose up -d itesly-api` |
| 查看 iTesly API 运行日志 | `docker compose logs -f itesly-api` |
| 忘记 Token？随时查看 | `grep ITESLY_API_TOKEN .env` |
| 检查后端健康状态 | `curl http://127.0.0.1:8080/app/api/v1/service-health` |

---

## 常见问题（FAQ）

1. **App 提示「无法连接服务器」怎么办？**
   - 检查手机和服务器是否在同一局域网，或服务器防火墙 / 云厂商安全组是否放行了 `8080` 端口。
   - iOS 首次连接局域网 HTTP 地址时，请在系统弹窗中点击**「允许访问本地网络」**。
   - 若通过公网域名访问，请使用 `https://`（iOS/Android 默认限制公网明文 HTTP）。

2. **已有 TeslaMate 用户接入后，会不会影响原来的数据和 Grafana？**
   - 不会。脚本仅向现有数据库新增一个最小权限的 `teslamate_app` 只读账号，并独立启动 `itesly-api` 容器加入同一网络，**不会重启或修改你原有的 TeslaMate、PostgreSQL 与 Grafana**。

3. **首页「系统信息」什么时候会显示新版本 OTA 提醒？**
   - 只要部署时启用了内置 `mosquitto`（默认已开启），当你的车辆收到官方 OTA 推送时，TeslaMate 会将 `update_available` 与 `update_version` 写入 MQTT，iTesly API 自动读取并在 App 首页高亮显示 `新版本 x.y.z`。

4. **端口 `8080` / `4000` / `3000` 被占用了怎么办？**
   - 修改当前目录 `.env` 文件里的 `ITESLY_API_PORT`、`TESLAMATE_PORT`、`GRAFANA_PORT`，然后重新执行 `docker compose up -d` 即可。

---

## 开源协议

本部署脚本仓库基于 [GPL-3.0](LICENSE) 协议开源。
