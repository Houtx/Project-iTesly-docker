[中文](README.md) | [English](README.en.md)

# Project-iTesly 一键部署脚本

> 专为 **iTesly** 手机 App（iOS / Android）打造的 **TeslaMate + 服务端** 傻瓜式 Docker 部署工具。
>
> **两种方案自由选择**：
> - **方案一（纯小白专用）**：刚买了一台空白服务器（VPS），只需粘贴 **1 条命令**，自动装好 Docker、部署全套服务、**一键公网打洞生成 `https://` 地址**并直接生成手机 App 所需的 **Token**。
> - **方案二（老用户 / 技术人员专用）**：已经装过 TeslaMate，零侵入一键接入现有数据库与 MQTT（不重启原有服务），或自行定制 Docker Compose。

---

## 开始前准备什么？

只需要一台 **24 小时开机的设备**（三选一）：
1. **云服务器（最省心，推荐纯小白）**：阿里云 / 腾讯云 / 海外 VPS 等，最便宜的 **2核2G（Linux Ubuntu / Debian）** 就完全够用。
2. **家用 NAS**：群晖 / 威联通 / 飞牛 fnOS / 绿联等（需支持 Docker）。
3. **常开电脑**：家里的 Mac mini / Linux 小主机。

> **如何打开服务器终端？**
> 云服务器购买后，在控制台点击 **「远程连接 / WebShell 登录」** 即可打开黑色命令行窗口；Mac 打开自带的「终端」，Windows 打开 PowerShell 输入 `ssh root@你的服务器IP`。

---

## 方案一：纯小白一键部署 + 一键打洞（推荐）

不需要懂 Docker，不需要提前装 `git`，在服务器终端里直接复制粘贴下面 **这一行命令** 回车即可：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Houtx/Project-iTesly-docker/main/start.sh)
```

脚本会用中文一步一步引导你（不知道怎么选时，**一路按回车默认即可**）：

1. **自动安装环境**：如果服务器还没装 Docker，脚本会自动帮你装好。
2. **选择方案与看板**：默认选择「方案一（全新部署）→ 中国大陆优化版（内置中文 Grafana 看板）」。
3. **选择公网 HTTPS 访问方式（推荐绑定自己的域名）**：
   - **选项 1：绑定自己的域名（强烈推荐，国内直连低延迟、永久稳定）**  
     买一个便宜的域名（几十元/年），在域名控制台把 A 记录解析到你的服务器公网 IP 后，在脚本里输入域名即可。脚本会自动通过 Caddy 申请并续期免费 HTTPS 证书，直接获得 `https://你的域名`。
   - **选项 2：暂不配置公网（内网直连 / Tailscale 免费组网）**  
     如果不想买域名，也可以在服务器和手机上同时安装免费的 **Tailscale** 组网（安全且不绕行海外），或者仅在家里 Wi-Fi 下使用内网 `IP:8080`。
   - **选项 3：Cloudflare 免费临时打洞（仅适合临时体验或海外 VPS）**  
     无需域名即可生成 `https://xxxx.trycloudflare.com`，但国内网络直连 Cloudflare 边缘节点延迟较高，不建议作为国内日常主力使用。

### 部署完成后，只需做最后两步：

脚本结束时，屏幕上会直接打印一个清晰的方框，包含你需要的所有地址和 Token：

1. **先激活数据采集（仅需一次）**：  
   用浏览器打开终端提示的 TeslaMate 网页地址 `http://你的服务器IP:4000`。  
   > **新手提示**：TeslaMate 首次登录不是直接输账号密码，而是要填 **Access Token** 和 **Refresh Token**。你可以在手机应用商店或 GitHub 下载开源工具 **Tesla Auth**，登录一次特斯拉账号后复制两个 Token 粘贴进去即可（全程安全不泄露密码）。

2. **连接手机端 iTesly App**：  
   打开手机上的 **iTesly** App，在引导页（或 **设置 → 自建服务配置**）直接复制填入终端最后输出的：
   - **服务地址**：例如 `https://xxxx.trycloudflare.com` 或 `https://你的域名`
   - **访问令牌**：终端生成的那一长串随机 `Token`

点击保存并连接，就能在手机上实时看到爱车状态、轨迹热力图与 OTA 新版本提醒了！

---

## 方案二：已有 TeslaMate / 技术人员接入

如果你已经在服务器上跑着 TeslaMate，或者习惯自己管理反代与 Compose 编排，可以用以下任意一种方式接入：

### 2.1 一键零侵入接入（推荐老用户）

在现有 TeslaMate 宿主机执行：

```bash
git clone https://github.com/Houtx/Project-iTesly-docker.git
cd Project-iTesly-docker
./install.sh --attach /你的/teslamate/目录
```

脚本会自动完成以下操作，且**不会重启或修改你原有的 TeslaMate、PostgreSQL 与 Grafana**：
1. 自动探测现有 `database` 容器名、Docker 网络名与 `mosquitto` 容器；
2. 在现有 `.env` 中安全生成 `ITESLY_DATABASE_PASS`、`ITESLY_API_TOKEN`、`ITESLY_PUBLISH_TOKEN`；
3. 自动执行 [`init_readonly.sql`](init_readonly.sql) 创建最小权限只读角色 `teslamate_app`；
4. 仅启动 `itesly-api`（`ghcr.io/houtx/itesly-api:latest`）并加入现有网络，同时自动连接 `mosquitto` 点亮车机 OTA 新版本提醒。

### 2.2 纯手动 Compose 部署

仓库内提供三套清晰模板，可按需自行编排：
- [`docker-compose.cn.yml`](docker-compose.cn.yml)：完整栈（TeslaMate + Postgres 18 + 中文 Grafana + Mosquitto + iTesly API）
- [`docker-compose.yml`](docker-compose.yml)：完整栈（TeslaMate + 官方 Grafana）
- [`docker-compose.attach.yml`](docker-compose.attach.yml)：仅 `itesly-api` 容器（连接外部已有 `teslamate` 网络）
- [`docker-compose.tunnel.yml`](docker-compose.tunnel.yml) / [`docker-compose.caddy.yml`](docker-compose.caddy.yml)：可叠加的公网打洞 / 自动 HTTPS 模块
- [`.env.example`](.env.example)：全部环境变量说明

非交互静默安装参数示例：
```bash
# 全新部署（中国优化版）+ Cloudflare 打洞
./install.sh --cn --tunnel

# 全新部署（中国优化版）+ 绑定自有域名
./install.sh --cn --domain itesly.example.com
```

---

## 后续补绑域名与自动申请 HTTPS 证书

如果首次部署时你先选择了「暂不配置公网」或「临时打洞」，之后新买了域名想换成永久 HTTPS 地址，**不需要重装，也不会丢失任何历史数据或 Token**，按以下 3 步操作即可：

1. **添加域名解析**：在域名服务商（阿里云 / 腾讯云 / Cloudflare 等）控制台添加一条 **`A` 记录**（例如主机记录填 `itesly`，记录值填你的服务器公网 IP）。
2. **放行端口**：在云服务器安全组 / 防火墙放行 **`80`** 和 **`443`** 端口（Caddy 申请免费 SSL 证书需要用到）。
3. **一键绑定并申请证书**：在服务器 `~/Project-iTesly-docker` 目录执行：

   ```bash
   cd ~/Project-iTesly-docker
   ./install.sh --bind-domain itesly.你的域名
   ```

   （也可以直接运行 `./install.sh` 后选择 **`3) 后续补绑/更换域名`** 按提示输入域名。）  
   脚本会自动生成配置并启动 Caddy，几秒内完成免费 Let's Encrypt HTTPS 证书申请（后续自动续期），然后在手机 App 里把服务地址改成 `https://itesly.你的域名` 即可（Token 保持不变）。

---

## 常用运维命令

安装目录默认位于 `~/Project-iTesly-docker`（进入该目录后执行）：

| 操作 | 命令 |
| :--- | :--- |
| 查看所有容器运行状态 | `docker compose ps` |
| 更新后端镜像到最新版 | `docker compose pull itesly-api && docker compose up -d itesly-api` |
| 查看 iTesly API 日志 | `docker compose logs -f itesly-api` |
| 查看临时打洞公网地址 | `docker compose logs cloudflared \| grep trycloudflare.com` |
| 忘记 Token？随时查看 | `grep ITESLY_API_TOKEN .env` |
| 检查后端健康状态 | `curl http://127.0.0.1:8080/app/api/v1/service-health` |

---

## 常见问题（FAQ）

1. **为什么我在家连 Wi-Fi 能用，出门开 5G 就连不上了？**  
   因为 `http://192.168.x.x:8080` 是家里局域网地址，离开家就访问不到；同时 iOS 系统出于安全要求，公网环境必须使用 `https://`。因此出门在车上使用，最推荐在安装时选择 **「选项 1：绑定自己的域名（Caddy 自动 HTTPS）」**，或者在服务器和手机上安装 **Tailscale** 免费组网（填写 Tailscale 分配的内网地址）。

2. **安全吗？你们的脚本会不会拿到我的特斯拉账号密码？**  
   **绝对不会**。所有数据全部保存在你自己的服务器里；iTesly 移动端和 `itesly-api` 后端全程不接触特斯拉账号密码，后端连接数据库使用的也是最低权限只读角色（[`init_readonly.sql`](init_readonly.sql) 仅开放全库 `SELECT` 与充电费用 `cost` 单列修改权限）。

3. **首页「系统信息」什么时候会显示新版本 OTA 提醒？**  
   只要启用了内置 `mosquitto`（默认已自动接入），当车辆收到官方 OTA 推送时，TeslaMate 会自动推送至 MQTT，App 首页会高亮显示 `新版本 x.y.z` 徽标。

4. **端口冲突（`8080` / `4000` / `3000` 被占用）怎么办？**  
   打开 `.env` 修改 `ITESLY_API_PORT`、`TESLAMATE_PORT` 或 `GRAFANA_PORT`，然后执行 `docker compose up -d` 即可生效。

---

## 开源协议

本部署脚本仓库基于 [GPL-3.0](LICENSE) 协议开源。
