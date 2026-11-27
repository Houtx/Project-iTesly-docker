#!/usr/bin/env bash
# ==============================================================================
# Project-iTesly 一键部署与接入向导
#
# 方案一（纯小白 VPS 一键部署）：
#   ./install.sh                  # 交互式向导（自动装 Docker、生成密钥、可选绑定域名）
#   ./install.sh --cn --domain <域名>  # 非交互：中国大陆优化版 + 自动申请 HTTPS 证书
#   ./install.sh --cn --tunnel    # 非交互：中国大陆优化版 + Cloudflare 免费打洞
#   ./install.sh --official       # 非交互：国际官方版
#
# 方案二（已有 TeslaMate / 技术人员一键接入）：
#   ./install.sh --attach <目录>  # 零侵入接入现有 TeslaMate Compose 目录
#
# 后续补绑/更换域名（自动申请 Let's Encrypt HTTPS 证书）：
#   ./install.sh --bind-domain <域名>
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

MODE=""
EDITION="cn"
ACCESS_MODE=""
DOMAIN_NAME=""
TESLAMATE_DIR=""
NON_INTERACTIVE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cn)
      MODE="fresh"
      EDITION="cn"
      NON_INTERACTIVE=1
      shift
      ;;
    --official)
      MODE="fresh"
      EDITION="official"
      NON_INTERACTIVE=1
      shift
      ;;
    --tunnel)
      ACCESS_MODE="tunnel"
      shift
      ;;
    --domain)
      ACCESS_MODE="domain"
      DOMAIN_NAME="${2:-}"
      shift 2
      ;;
    --attach)
      MODE="attach"
      TESLAMATE_DIR="${2:-}"
      NON_INTERACTIVE=1
      shift 2
      ;;
    --bind-domain)
      MODE="bind-domain"
      DOMAIN_NAME="${2:-}"
      NON_INTERACTIVE=1
      shift 2
      ;;
    -h|--help)
      sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "未知参数: $1 (使用 --help 查看帮助)" >&2
      exit 1
      ;;
  esac
done

info()  { printf '\033[1;34m[iTesly]\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m[完成]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[提示]\033[0m %s\n' "$*"; }
fatal() { printf '\033[1;31m[错误]\033[0m %s\n' "$*" >&2; exit 1; }

ensure_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    if [[ "$(uname -s)" == "Linux" ]]; then
      if [[ "$NON_INTERACTIVE" -eq 0 ]]; then
        read -r -p "未检测到 Docker，是否自动一键安装 Docker？[Y/n] (默认 Y): " install_dk
        if [[ "${install_dk:-Y}" =~ ^[Nn]$ ]]; then
          fatal "请先安装 Docker 后再运行本脚本。"
        fi
      fi
      info "正在自动安装 Docker（Linux 官方脚本）..."
      if [[ "$(id -u)" -eq 0 ]]; then
        curl -fsSL https://get.docker.com | sh
        systemctl enable --now docker >/dev/null 2>&1 || service docker start >/dev/null 2>&1 || true
      elif command -v sudo >/dev/null 2>&1; then
        curl -fsSL https://get.docker.com | sudo sh
        sudo systemctl enable --now docker >/dev/null 2>&1 || true
      else
        fatal "需要 root 或 sudo 权限来自动安装 Docker。"
      fi
    else
      fatal "未检测到 Docker，请先安装 Docker Desktop（https://www.docker.com/）。"
    fi
  fi

  if ! docker compose version >/dev/null 2>&1; then
    fatal "未检测到 Docker Compose V2（docker compose），请升级 Docker 或安装 compose 插件。"
  fi
}

gen_hex() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
  else
    LC_ALL=C tr -dc '0-9a-f' </dev/urandom | head -c 64
  fi
}

read_env_val() {
  local file="$1" key="$2"
  [[ -f "$file" ]] || return 0
  sed -n "s/^${key}=//p" "$file" | head -n 1 | tr -d '\r'
}

upsert_env() {
  local file="$1" key="$2" val="$3"
  touch "$file"
  if grep -q "^${key}=" "$file"; then
    return 0
  fi
  printf '%s=%s\n' "$key" "$val" >> "$file"
}

set_env_kv() {
  local file="$1" key="$2" val="$3"
  touch "$file"
  if grep -q "^${key}=" "$file"; then
    sed -i.bak "s|^${key}=.*|${key}=${val}|" "$file" && rm -f "${file}.bak"
  else
    printf '%s=%s\n' "$key" "$val" >> "$file"
  fi
}

detect_public_ip() {
  curl -fsS --max-time 4 https://api.ipify.org 2>/dev/null \
    || curl -fsS --max-time 4 https://ifconfig.me 2>/dev/null \
    || true
}

detect_lan_ip() {
  local ip=""
  if command -v ipconfig >/dev/null 2>&1; then
    ip="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
  fi
  if [[ -z "$ip" ]] && command -v hostname >/dev/null 2>&1; then
    ip="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
  fi
  printf '%s' "$ip"
}

wait_api_health() {
  local port="$1"
  info "正在等待 iTesly API 启动并完成自检..."
  for _ in $(seq 1 30); do
    if curl -fsS "http://127.0.0.1:${port}/app/api/v1/service-health" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  warn "服务仍在启动中，可稍后执行 docker compose logs -f itesly-api 查看日志。"
}

wait_tunnel_url() {
  info "正在等待 Cloudflare 分配免费公网 HTTPS 地址（约 5~15 秒）..."
  local url=""
  for _ in $(seq 1 20); do
    url="$(docker compose logs cloudflared 2>&1 | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | head -n 1 || true)"
    if [[ -n "$url" ]]; then
      printf '%s' "$url"
      return 0
    fi
    sleep 2
  done
  printf ''
}

print_summary() {
  local api_url="$1" api_token="$2" show_teslamate="${3:-1}"
  local tm_port="$4" gf_port="$5" extra_note="${6:-}"
  local host_ip
  host_ip="$(detect_public_ip)"
  if [[ -z "$host_ip" ]]; then
    host_ip="$(detect_lan_ip)"
  fi
  host_ip="${host_ip:-<你的服务器IP>}"

  echo ""
  echo "======================================================================"
  echo "  Project-iTesly 部署成功！请打开手机 iTesly App 填入以下两项："
  echo "======================================================================"
  echo "  1. 服务地址： ${api_url}"
  echo "  2. 访问令牌： ${api_token}"
  if [[ -n "$extra_note" ]]; then
    echo "  说明：        ${extra_note}"
  fi
  echo "----------------------------------------------------------------------"
  if [[ "$show_teslamate" == "1" ]]; then
    echo "  【重要】首次使用请先授权 TeslaMate 开始同步爱车数据："
    echo "    网页地址： http://${host_ip}:${tm_port}"
    echo "    操作方式： 打开后使用 Tesla Auth (https://github.com/adriankumpf/tesla_auth/releases) 生成 Token 登录"
    echo "    Grafana 看板： http://${host_ip}:${gf_port}  (默认账号密码 admin/admin)"
    echo "----------------------------------------------------------------------"
  fi
  echo "  常用运维命令（在 $SCRIPT_DIR 目录执行）："
  echo "    查看运行状态： docker compose ps"
  echo "    查看实时日志： docker compose logs -f itesly-api"
  echo "    更新到最新版： docker compose pull && docker compose up -d"
  echo "======================================================================"
  echo ""
}

ensure_docker

if [[ -z "$MODE" && "$NON_INTERACTIVE" -eq 0 ]]; then
  echo ""
  echo "欢迎使用 Project-iTesly 一键部署向导"
  echo "--------------------------------------------------"
  echo "  1) 方案一：纯小白全新一键部署（新 VPS / NAS 从零装齐）"
  echo "  2) 方案二：已有 TeslaMate 一键接入（适合老用户 / 技术人员，不改动原服务）"
  echo "  3) 后续补绑/更换域名（已部署过，现在绑定域名并自动申请 HTTPS 证书）"
  echo "--------------------------------------------------"
  read -r -p "请选择操作 [1/2/3] (默认 1): " choice
  case "${choice:-1}" in
    2) MODE="attach" ;;
    3) MODE="bind-domain" ;;
    *) MODE="fresh" ;;
  esac
fi

# ==============================================================================
# 模式 3：为已部署的方案一环境补绑/更换域名（自动申请 HTTPS 证书）
# ==============================================================================
if [[ "$MODE" == "bind-domain" ]]; then
  env_file="$SCRIPT_DIR/.env"
  [[ -f "$env_file" ]] || fatal "未找到 $env_file，请先运行 ./install.sh 完成首次部署。"

  cur_compose="$(read_env_val "$env_file" COMPOSE_FILE)"
  if [[ "$cur_compose" == *"docker-compose.attach.yml"* ]]; then
    fatal "当前为「方案二：接入现有 TeslaMate」模式，请直接将你现有的 Nginx / Caddy 反向代理指向 127.0.0.1:8080。"
  fi

  base_compose="docker-compose.cn.yml"
  if [[ "$cur_compose" == *"docker-compose.yml"* ]] && [[ "$cur_compose" != *"docker-compose.cn.yml"* ]]; then
    base_compose="docker-compose.yml"
  fi

  if [[ -z "$DOMAIN_NAME" ]]; then
    echo ""
    echo "提示：请先在域名服务商处添加 A 记录，将该域名解析到当前服务器公网 IP，并放行 80 / 443 端口。"
    read -r -p "请输入要绑定的域名（如 itesly.example.com，不含 https://）: " DOMAIN_NAME
  fi
  DOMAIN_NAME="${DOMAIN_NAME#https://}"
  DOMAIN_NAME="${DOMAIN_NAME#http://}"
  DOMAIN_NAME="${DOMAIN_NAME%%/*}"
  [[ -n "$DOMAIN_NAME" ]] || fatal "域名不能为空。"

  if [[ "$cur_compose" == *"docker-compose.tunnel.yml"* ]]; then
    info "正在关闭之前的临时 Cloudflare 打洞容器..."
    docker compose rm -sf cloudflared >/dev/null 2>&1 || true
  fi

  cat > "$SCRIPT_DIR/Caddyfile" <<EOF
${DOMAIN_NAME} {
    reverse_proxy itesly-api:8080
}
EOF
  mkdir -p "$SCRIPT_DIR/data/caddy/data" "$SCRIPT_DIR/data/caddy/config"
  set_env_kv "$env_file" COMPOSE_FILE "${base_compose}:docker-compose.caddy.yml"

  info "正在启动 Caddy 并为 ${DOMAIN_NAME} 自动申请 HTTPS 证书..."
  docker compose up -d caddy

  api_token="$(read_env_val "$env_file" ITESLY_API_TOKEN)"
  tm_port="$(read_env_val "$env_file" TESLAMATE_PORT)"
  gf_port="$(read_env_val "$env_file" GRAFANA_PORT)"
  ok "域名绑定完成！以后数据与 Token 均保持不变。"
  print_summary "https://${DOMAIN_NAME}" "$api_token" 1 "${tm_port:-4000}" "${gf_port:-3000}" "证书由 Caddy 自动申请并续期；请确保 80/443 端口已放行"
  exit 0
fi

# ==============================================================================
# 方案一：纯小白全新一键部署 + 可选一键公网打洞
# ==============================================================================
if [[ "$MODE" == "fresh" ]]; then
  if [[ "$NON_INTERACTIVE" -eq 0 ]]; then
    echo ""
    echo "步骤 1/2：请选择镜像版本"
    echo "  1) 中国大陆优化版（推荐：预置中文 Grafana 看板 + 默认 Asia/Shanghai）"
    echo "  2) 国际官方版（TeslaMate + Grafana 官方原版）"
    read -r -p "请选择版本 [1/2] (默认 1): " ed_choice
    case "${ed_choice:-1}" in
      2) EDITION="official" ;;
      *) EDITION="cn" ;;
    esac
  fi

  if [[ -z "$ACCESS_MODE" ]]; then
    if [[ "$NON_INTERACTIVE" -eq 0 ]]; then
      echo ""
      echo "步骤 2/2：请选择公网访问方式（手机出门用 5G 也能安全连接）"
      echo "  1) 绑定自己的域名（强烈推荐：Caddy 自动申请免费 HTTPS，国内直连低延迟且永久稳定）"
      echo "  2) 暂不配置公网（仅用内网 IP:8080，或自行使用 Tailscale 免费组网 / 已有反代）"
      echo "  3) Cloudflare 免费临时打洞（无需域名体验用，国内访问延迟较高，仅适合临时测试/海外VPS）"
      read -r -p "请选择 [1/2/3] (默认 1): " acc_choice
      case "${acc_choice:-1}" in
        2) ACCESS_MODE="direct" ;;
        3) ACCESS_MODE="tunnel" ;;
        *) ACCESS_MODE="domain" ;;
      esac
    else
      ACCESS_MODE="direct"
    fi
  fi

  if [[ "$ACCESS_MODE" == "domain" && -z "$DOMAIN_NAME" ]]; then
    echo ""
    echo "提示：请先在域名服务商处添加 A 记录指向当前服务器公网 IP，并放行 80 和 443 端口。"
    echo "      （如还没有域名，推荐 腾讯云DNSPod / 阿里云万网 / Cloudflare / Namesilo，均支持国内支付）"
    read -r -p "请输入你的域名（如 itesly.example.com；若暂未准备域名直接回车将切换为方案2）: " DOMAIN_NAME
    DOMAIN_NAME="${DOMAIN_NAME#https://}"
    DOMAIN_NAME="${DOMAIN_NAME#http://}"
    DOMAIN_NAME="${DOMAIN_NAME%%/*}"
    if [[ -z "$DOMAIN_NAME" ]]; then
      warn "未填写域名，已自动切换为「2) 暂不配置公网」，后续随时可重新运行 ./install.sh 绑定域名。"
      ACCESS_MODE="direct"
    fi
  fi

  base_compose="docker-compose.yml"
  [[ "$EDITION" == "cn" ]] && base_compose="docker-compose.cn.yml"

  compose_files="$base_compose"
  if [[ "$ACCESS_MODE" == "tunnel" ]]; then
    compose_files="${base_compose}:docker-compose.tunnel.yml"
  elif [[ "$ACCESS_MODE" == "domain" ]]; then
    compose_files="${base_compose}:docker-compose.caddy.yml"
    cat > "$SCRIPT_DIR/Caddyfile" <<EOF
${DOMAIN_NAME} {
    reverse_proxy itesly-api:8080
}
EOF
    mkdir -p data/caddy/data data/caddy/config
  fi

  env_file="$SCRIPT_DIR/.env"
  if [[ ! -f "$env_file" ]]; then
    cp "$SCRIPT_DIR/.env.example" "$env_file"
  fi

  replace_placeholder_or_set() {
    local key="$1" val="$2"
    local cur
    cur="$(read_env_val "$env_file" "$key")"
    if [[ -z "$cur" || "$cur" == replace-with-* ]]; then
      set_env_kv "$env_file" "$key" "$val"
    fi
  }

  replace_placeholder_or_set ENCRYPTION_KEY "$(gen_hex)"
  replace_placeholder_or_set DATABASE_PASS "$(gen_hex)"
  replace_placeholder_or_set ITESLY_DATABASE_PASS "$(gen_hex)"
  replace_placeholder_or_set ITESLY_API_TOKEN "$(gen_hex)"
  replace_placeholder_or_set ITESLY_PUBLISH_TOKEN "$(gen_hex)"
  set_env_kv "$env_file" COMPOSE_FILE "$compose_files"
  chmod 600 "$env_file"

  mkdir -p import releases data/postgres data/grafana data/mosquitto/config data/mosquitto/data data/mosquitto/log

  info "正在拉取镜像并启动基础服务（数据库、TeslaMate、MQTT、Grafana）..."
  docker compose up -d database mosquitto teslamate grafana
  info "等待 PostgreSQL 就绪..."
  for _ in $(seq 1 30); do
    if docker compose exec -T database pg_isready -U teslamate -d teslamate >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done

  info "等待 TeslaMate 完成数据库初始化建表..."
  for _ in $(seq 1 60); do
    if [[ "$(docker compose exec -T database psql -U teslamate -d teslamate -tAc "SELECT to_regclass('public.charging_processes')" 2>/dev/null | tr -d '[:space:]')" == "charging_processes" ]]; then
      break
    fi
    sleep 2
  done

  itesly_db_pass="$(read_env_val "$env_file" ITESLY_DATABASE_PASS)"
  info "正在初始化只读数据库角色 teslamate_app..."
  docker compose exec -T database psql -U teslamate -d teslamate \
    -v ON_ERROR_STOP=1 -v app_password="$itesly_db_pass" < "$SCRIPT_DIR/init_readonly.sql" >/dev/null

  info "正在启动全部服务..."
  docker compose up -d

  api_port="$(read_env_val "$env_file" ITESLY_API_PORT)"
  api_port="${api_port:-8080}"
  tm_port="$(read_env_val "$env_file" TESLAMATE_PORT)"
  tm_port="${tm_port:-4000}"
  gf_port="$(read_env_val "$env_file" GRAFANA_PORT)"
  gf_port="${gf_port:-3000}"
  api_token="$(read_env_val "$env_file" ITESLY_API_TOKEN)"

  wait_api_health "$api_port"

  final_url=""
  extra_note=""
  if [[ "$ACCESS_MODE" == "tunnel" ]]; then
    final_url="$(wait_tunnel_url)"
    if [[ -z "$final_url" ]]; then
      final_url="请执行 docker compose logs cloudflared 查看 trycloudflare.com 地址"
    else
      extra_note="Cloudflare 临时免费打洞地址；若容器重启域名会变化（长期稳定建议绑定自有域名）"
    fi
  elif [[ "$ACCESS_MODE" == "domain" ]]; then
    final_url="https://${DOMAIN_NAME}"
    extra_note="请确保云服务器防火墙已放行 80 和 443 端口"
  else
    pub_ip="$(detect_public_ip)"
    lan_ip="$(detect_lan_ip)"
    shown_ip="${pub_ip:-${lan_ip:-<你的服务器IP>}}"
    final_url="http://${shown_ip}:${api_port}"
    extra_note="若公网使用请搭配 HTTPS 反代或 Tailscale 组网"
  fi

  ok "全新部署完成！"
  print_summary "$final_url" "$api_token" 1 "$tm_port" "$gf_port" "$extra_note"
  exit 0
fi

# ==============================================================================
# 方案二：已有 TeslaMate 一键接入（零侵入，不重启原有 TeslaMate 与数据库）
# ==============================================================================
if [[ -z "$TESLAMATE_DIR" && "$NON_INTERACTIVE" -eq 0 ]]; then
  read -r -p "请输入现有 TeslaMate 目录路径（包含 docker-compose.yml 和 .env）: " TESLAMATE_DIR
fi

[[ -n "$TESLAMATE_DIR" ]] || fatal "请提供现有 TeslaMate 目录路径。"
[[ -d "$TESLAMATE_DIR" ]] || fatal "目录不存在: $TESLAMATE_DIR"
TESLAMATE_DIR="$(cd "$TESLAMATE_DIR" && pwd)"

tm_env="$TESLAMATE_DIR/.env"
[[ -f "$tm_env" ]] || fatal "未在 $TESLAMATE_DIR 找到 .env 文件。"

db_container="$(cd "$TESLAMATE_DIR" && docker compose ps -q database 2>/dev/null | head -n 1 || true)"
if [[ -n "$db_container" ]]; then
  db_container="$(docker inspect -f '{{.Name}}' "$db_container" | sed 's|^/||')"
else
  read -r -p "未能自动识别数据库容器名，请输入 PostgreSQL 容器名 (默认 teslamate-database-1): " db_container
  db_container="${db_container:-teslamate-database-1}"
fi

docker inspect "$db_container" >/dev/null 2>&1 || fatal "找不到运行中的数据库容器: $db_container"

tm_network="$(docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$db_container" | awk '{print $1}')"
[[ -n "$tm_network" ]] || fatal "无法探测数据库容器 $db_container 所属 Docker 网络。"

upsert_env "$tm_env" ITESLY_DATABASE_PASS "$(gen_hex)"
upsert_env "$tm_env" ITESLY_API_TOKEN "$(gen_hex)"
upsert_env "$tm_env" ITESLY_PUBLISH_TOKEN "$(gen_hex)"
chmod 600 "$tm_env"

itesly_db_pass="$(read_env_val "$tm_env" ITESLY_DATABASE_PASS)"
api_token="$(read_env_val "$tm_env" ITESLY_API_TOKEN)"
db_user="$(read_env_val "$tm_env" DATABASE_USER)"
db_user="${db_user:-teslamate}"
db_name="$(read_env_val "$tm_env" DATABASE_NAME)"
db_name="${db_name:-teslamate}"

info "正在向已有数据库 ($db_container) 创建只读角色 teslamate_app..."
docker exec -i "$db_container" psql -U "$db_user" -d "$db_name" \
  -v ON_ERROR_STOP=1 -v app_password="$itesly_db_pass" < "$SCRIPT_DIR/init_readonly.sql" >/dev/null

mqtt_host="mosquitto"
if ! docker network inspect "$tm_network" --format '{{range .Containers}}{{.Name}} {{end}}' | grep -q "mosquitto"; then
  mqtt_host=""
  warn "未在网络 $tm_network 中检测到 mosquitto 容器，OTA 新版本提醒功能将暂不启用。"
fi

local_env="$SCRIPT_DIR/.env"
cat > "$local_env" <<EOF
COMPOSE_FILE=docker-compose.attach.yml
ITESLY_DB_HOST=database
ITESLY_DB_PORT=5432
ITESLY_DB_NAME=$db_name
ITESLY_DATABASE_PASS=$itesly_db_pass
ITESLY_API_TOKEN=$api_token
ITESLY_PUBLISH_TOKEN=$(read_env_val "$tm_env" ITESLY_PUBLISH_TOKEN)
ITESLY_API_PORT=8080
HOST_BIND=0.0.0.0
TZ=Asia/Shanghai
TESLAMATE_DOCKER_NETWORK=$tm_network
ITESLY_MQTT_HOST=$mqtt_host
ITESLY_MQTT_PORT=1883
EOF
chmod 600 "$local_env"
mkdir -p "$SCRIPT_DIR/releases"

info "正在启动 itesly-api 并接入现有网络 ($tm_network)..."
docker compose up -d

wait_api_health 8080
pub_ip="$(detect_public_ip)"
lan_ip="$(detect_lan_ip)"
shown_ip="${pub_ip:-${lan_ip:-<你的服务器IP>}}"
ok "已成功接入现有 TeslaMate！"
print_summary "http://${shown_ip}:8080" "$api_token" 0 4000 3000 "如需公网 HTTPS，请将现有反代（Nginx/Caddy/Cloudflare）指向 127.0.0.1:8080"
