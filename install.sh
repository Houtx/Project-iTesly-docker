#!/usr/bin/env bash
# ==============================================================================
# Project-iTesly 一键部署 / 接入向导（适用于 Linux / macOS / 群晖 / 威联通 NAS）
#
# 用法：
#   ./install.sh                  # 交互式傻瓜向导
#   ./install.sh --cn             # 非交互：直接全新部署（中国大陆优化版）
#   ./install.sh --official       # 非交互：直接全新部署（国际官方版）
#   ./install.sh --attach <目录>  # 非交互：接入已有 TeslaMate 目录
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

MODE=""
EDITION="cn"
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
    --attach)
      MODE="attach"
      TESLAMATE_DIR="${2:-}"
      NON_INTERACTIVE=1
      shift 2
      ;;
    -h|--help)
      sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
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

if ! command -v docker >/dev/null 2>&1; then
  fatal "未检测到 Docker，请先安装 Docker（Linux 可执行 curl -fsSL https://get.docker.com | sh）。"
fi

if ! docker compose version >/dev/null 2>&1; then
  fatal "未检测到 Docker Compose V2（docker compose），请升级 Docker 或安装 compose 插件。"
fi

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

detect_lan_ip() {
  local ip=""
  if command -v ipconfig >/dev/null 2>&1; then
    ip="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
  fi
  if [[ -z "$ip" ]] && command -v hostname >/dev/null 2>&1; then
    ip="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
  fi
  if [[ -z "$ip" ]]; then
    ip="<你的服务器IP>"
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

print_summary() {
  local api_port="$1" api_token="$2" show_teslamate="${3:-1}"
  local tm_port="$4" gf_port="$5"
  local lan_ip
  lan_ip="$(detect_lan_ip)"

  echo ""
  echo "======================================================================"
  echo "  Project-iTesly 后端部署成功！请打开手机 iTesly App 按下方信息填写："
  echo "======================================================================"
  echo "  1. 服务地址（局域网）： http://${lan_ip}:${api_port}"
  echo "     （如配置了 HTTPS 域名反代，请改为 https://你的域名）"
  echo "  2. 访问令牌（Token）： ${api_token}"
  echo "----------------------------------------------------------------------"
  if [[ "$show_teslamate" == "1" ]]; then
    echo "  TeslaMate 网页后台：   http://${lan_ip}:${tm_port}"
    echo "  （首次使用请先打开上方地址，登录一次 Tesla 账号以开始同步车辆数据）"
    echo "  Grafana 数据看板：     http://${lan_ip}:${gf_port}  (默认账号密码 admin/admin)"
    echo "----------------------------------------------------------------------"
  fi
  echo "  常用命令："
  echo "    查看状态： docker compose ps"
  echo "    更新镜像： docker compose pull && docker compose up -d"
  echo "======================================================================"
  echo ""
}

if [[ -z "$MODE" && "$NON_INTERACTIVE" -eq 0 ]]; then
  echo ""
  echo "欢迎使用 Project-iTesly 一键部署向导"
  echo "--------------------------------------------------"
  echo "  1) 全新部署（我还没有安装过 TeslaMate，帮我一键装齐）"
  echo "  2) 接入现有（我已经装好 TeslaMate，只需接入 iTesly 手机端后端）"
  echo "--------------------------------------------------"
  read -r -p "请选择模式 [1/2] (默认 1): " choice
  case "${choice:-1}" in
    2) MODE="attach" ;;
    *) MODE="fresh" ;;
  esac
fi

if [[ "$MODE" == "fresh" ]]; then
  if [[ "$NON_INTERACTIVE" -eq 0 ]]; then
    echo ""
    echo "请选择镜像版本："
    echo "  1) 中国大陆优化版（推荐：预置中文 Grafana 看板 + 默认 Asia/Shanghai）"
    echo "  2) 国际官方版（TeslaMate + Grafana 官方原版）"
    read -r -p "请选择版本 [1/2] (默认 1): " ed_choice
    case "${ed_choice:-1}" in
      2) EDITION="official" ;;
      *) EDITION="cn" ;;
    esac
  fi

  compose_file="docker-compose.yml"
  [[ "$EDITION" == "cn" ]] && compose_file="docker-compose.cn.yml"

  env_file="$SCRIPT_DIR/.env"
  if [[ ! -f "$env_file" ]]; then
    cp "$SCRIPT_DIR/.env.example" "$env_file"
  fi

  # 自动替换占位符或补全随机强密钥
  replace_placeholder_or_set() {
    local key="$1" val="$2"
    local cur
    cur="$(read_env_val "$env_file" "$key")"
    if [[ -z "$cur" || "$cur" == replace-with-* ]]; then
      if grep -q "^${key}=" "$env_file"; then
        sed -i.bak "s|^${key}=.*|${key}=${val}|" "$env_file" && rm -f "${env_file}.bak"
      else
        printf '%s=%s\n' "$key" "$val" >> "$env_file"
      fi
    fi
  }

  replace_placeholder_or_set ENCRYPTION_KEY "$(gen_hex)"
  replace_placeholder_or_set DATABASE_PASS "$(gen_hex)"
  replace_placeholder_or_set ITESLY_DATABASE_PASS "$(gen_hex)"
  replace_placeholder_or_set ITESLY_API_TOKEN "$(gen_hex)"
  replace_placeholder_or_set ITESLY_PUBLISH_TOKEN "$(gen_hex)"
  chmod 600 "$env_file"

  mkdir -p import releases data/postgres data/grafana data/mosquitto/config data/mosquitto/data data/mosquitto/log

  info "正在使用 $compose_file 拉取并启动数据库..."
  docker compose -f "$compose_file" up -d database
  info "等待 PostgreSQL 就绪..."
  for _ in $(seq 1 30); do
    if docker compose -f "$compose_file" exec -T database pg_isready -U teslamate -d teslamate >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done

  itesly_db_pass="$(read_env_val "$env_file" ITESLY_DATABASE_PASS)"
  info "正在初始化只读数据库角色 teslamate_app..."
  docker compose -f "$compose_file" exec -T database psql -U teslamate -d teslamate \
    -v ON_ERROR_STOP=1 -v app_password="$itesly_db_pass" < "$SCRIPT_DIR/init_readonly.sql" >/dev/null

  info "正在启动全部服务（TeslaMate + Grafana + Mosquitto + iTesly API）..."
  docker compose -f "$compose_file" up -d

  api_port="$(read_env_val "$env_file" ITESLY_API_PORT)"
  api_port="${api_port:-8080}"
  tm_port="$(read_env_val "$env_file" TESLAMATE_PORT)"
  tm_port="${tm_port:-4000}"
  gf_port="$(read_env_val "$env_file" GRAFANA_PORT)"
  gf_port="${gf_port:-3000}"
  api_token="$(read_env_val "$env_file" ITESLY_API_TOKEN)"

  wait_api_health "$api_port"
  ok "全新部署完成！"
  print_summary "$api_port" "$api_token" 1 "$tm_port" "$gf_port"
  exit 0
fi

# ==============================================================================
# 模式 2：接入已有 TeslaMate 栈（零侵入，不重启原有 TeslaMate 与数据库）
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
docker compose -f "$SCRIPT_DIR/docker-compose.attach.yml" up -d

wait_api_health 8080
ok "已成功接入现有 TeslaMate！"
print_summary 8080 "$api_token" 0 4000 3000
