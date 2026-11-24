#!/usr/bin/env bash
# ==============================================================================
# Project-iTesly 一键远程引导脚本（无需提前安装 git）
# 用法：bash <(curl -fsSL https://raw.githubusercontent.com/Houtx/Project-iTesly-docker/main/start.sh)
# ==============================================================================
set -euo pipefail

REPO_TARBALL="https://github.com/Houtx/Project-iTesly-docker/archive/refs/heads/main.tar.gz"
TARGET_DIR="${ITESLY_INSTALL_DIR:-$HOME/Project-iTesly-docker}"

info()  { printf '\033[1;34m[iTesly]\033[0m %s\n' "$*"; }
fatal() { printf '\033[1;31m[错误]\033[0m %s\n' "$*" >&2; exit 1; }

if ! command -v curl >/dev/null 2>&1 || ! command -v tar >/dev/null 2>&1; then
  if [[ "$(id -u)" -eq 0 ]] && command -v apt-get >/dev/null 2>&1; then
    info "正在安装基础工具 (curl / tar)..."
    apt-get update -qq && apt-get install -y -qq curl tar ca-certificates
  else
    fatal "请先安装 curl 和 tar 后重试。"
  fi
fi

mkdir -p "$TARGET_DIR"
info "正在下载最新 Project-iTesly 部署脚本到 $TARGET_DIR ..."
curl -fsSL "$REPO_TARBALL" | tar -xz --strip-components=1 -C "$TARGET_DIR"
chmod +x "$TARGET_DIR/install.sh" "$TARGET_DIR/start.sh"

cd "$TARGET_DIR"
exec bash "$TARGET_DIR/install.sh" "$@"
