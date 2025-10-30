#!/usr/bin/env bash
# ===============================================================
# build-proxies.sh
# 安全版 sing-box 与 Xray-core 一键编译脚本（无后门操作）
# - 仅构建与安装二进制，不修改系统服务、不改防火墙
# - 兼容 Ubuntu 20.04/22.04/24.04 x86_64
# - 作者：Connie 定制版
# ===============================================================

set -euo pipefail

# ======== 配置区 ========
WORKDIR="${HOME}/build-proxies"
SINGBOX_REPO="https://github.com/SagerNet/sing-box.git"
SINGBOX_TAG="v1.12.12"
XRAY_REPO="https://github.com/XTLS/Xray-core.git"
XRAY_TAG="v25.10.15"
GO_VERSION="1.23.1"   # 兼容 sing-box 和 xray-core
INSTALL_PREFIX="/usr/local/bin"
# ========================

echo "🚀 开始编译 sing-box 与 xray-core..."
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# ---------- 安装依赖 ----------
if command -v apt >/dev/null 2>&1; then
  echo "🔧 安装系统依赖..."
  sudo apt update -y
  sudo apt install -y build-essential git wget curl ca-certificates
fi

# ---------- 安装或更新 Go ----------
if ! command -v go >/dev/null 2>&1 || [[ "$(go version 2>/dev/null)" != *"go${GO_VERSION}"* ]]; then
  echo "⬇️  安装 Go ${GO_VERSION}..."
  wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go${GO_VERSION}.tar.gz
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf /tmp/go${GO_VERSION}.tar.gz
  rm /tmp/go${GO_VERSION}.tar.gz
  export PATH="/usr/local/go/bin:${PATH}"
fi
echo "✅ 当前 Go 版本：$(go version)"

# ===============================================================
# 1️⃣ 编译 sing-box
# ===============================================================
echo "🏗️  开始编译 sing-box (${SINGBOX_TAG})..."
cd "$WORKDIR"
if [[ -d sing-box ]]; then
  cd sing-box
  git fetch --all --tags
else
  git clone "$SINGBOX_REPO"
  cd sing-box
fi

git checkout "$SINGBOX_TAG"

# 官方 Makefile 优先
if make -n >/dev/null 2>&1; then
  make
else
  go build -o sing-box ./cmd/sing-box
fi

echo "✅ sing-box 编译完成：$(pwd)/sing-box"

# ===============================================================
# 2️⃣ 编译 Xray-core
# ===============================================================
echo "🏗️  开始编译 Xray-core (${XRAY_TAG})..."
cd "$WORKDIR"
if [[ -d Xray-core ]]; then
  cd Xray-core
  git fetch --all --tags
else
  git clone "$XRAY_REPO"
  cd Xray-core
fi

git checkout "$XRAY_TAG"

CGO_ENABLED=0 go build -o xray -trimpath \
  -ldflags="-X github.com/xtls/xray-core/core.build=manual -s -w -buildid=" ./main

echo "✅ Xray-core 编译完成：$(pwd)/xray"

# ===============================================================
# 3️⃣ 安装二进制
# ===============================================================
echo "📦 安装到 ${INSTALL_PREFIX}（需要sudo权限）..."
sudo cp -v "$WORKDIR"/sing-box/sing-box "$INSTALL_PREFIX"/
sudo cp -v "$WORKDIR"/Xray-core/xray "$INSTALL_PREFIX"/
sudo chmod 0755 "$INSTALL_PREFIX"/sing-box "$INSTALL_PREFIX"/xray

# 打印文件大小以确认
echo "✅ sing-box installed:"
ls -lh "$INSTALL_PREFIX"/sing-box
echo "✅ xray installed:"
ls -lh "$INSTALL_PREFIX"/xray

echo
echo "🎉 全部完成！二进制文件已安装："
echo "---------------------------------------------------------------"
echo "🟩 $(command -v sing-box)"
sing-box version || sing-box -v
echo "---------------------------------------------------------------"
echo "🟦 $(command -v xray)"
xray -version
echo "---------------------------------------------------------------"
echo "✅ 安装目录: ${INSTALL_PREFIX}"
echo "⚠️  注意：本脚本不会自动启用 systemd 服务，也不会修改防火墙。"
echo "    请手动配置配置文件 (/etc/sing-box/sb.json 或 /etc/xray/config.json)"
echo "---------------------------------------------------------------"
