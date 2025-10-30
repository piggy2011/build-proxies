#!/bin/bash
# ============================================================
# argosbx_refined_v1.3.sh
# RareCloud multi-protocol auto-config generator and service deployer
# Author: Customized for Connie
# ============================================================

# ---------- Color output ----------
Green="\033[32m"; Yellow="\033[33m"; Red="\033[31m"; Font="\033[0m"

echo -e "${Green}▶ Initializing RareCloud Proxy Environment...${Font}"

# ---------- Environment detection ----------
if [[ "$GITHUB_ACTIONS" == "true" ]]; then
  # Running in GitHub Actions environment
  if id runner &>/dev/null; then
    HOME="/home/runner"
  fi
  echo -e "${Yellow}Detected GitHub Actions environment. Using HOME=${HOME}${Font}"
fi

# ---------- Working directory ----------
WORKDIR="${HOME}/.agsbx"
mkdir -p "${WORKDIR}" "${WORKDIR}/systemd"
cd "${WORKDIR}" || exit 1

# ---------- Generate or reuse UUID ----------
UUID_FILE="${WORKDIR}/uuid.txt"
if [[ -f "${UUID_FILE}" && -s "${UUID_FILE}" ]]; then
  UUID=$(cat "${UUID_FILE}")
else
  UUID=$(cat /proc/sys/kernel/random/uuid)
  echo "${UUID}" > "${UUID_FILE}"
  echo -e "${Green}Generated new UUID: ${UUID}${Font}"
fi

# ---------- Generate or reuse Shadowsocks-2022 key ----------
SS_KEY_FILE="${WORKDIR}/ss2022.key"
if [[ -f "${SS_KEY_FILE}" && -s "${SS_KEY_FILE}" ]]; then
  SS_KEY=$(cat "${SS_KEY_FILE}")
else
  SS_KEY=$(openssl rand -base64 16)
  echo "${SS_KEY}" > "${SS_KEY_FILE}"
  echo -e "${Green}Generated new Shadowsocks key.${Font}"
fi

# ---------- Generate or reuse SOCKS5 credentials ----------
SOCKS5_CRED_FILE="${WORKDIR}/socks5_cred.txt"
if [[ -f "${SOCKS5_CRED_FILE}" && -s "${SOCKS5_CRED_FILE}" ]]; then
  SOCKS5_USER=$(awk -F: '{print $1}' "${SOCKS5_CRED_FILE}")
  SOCKS5_PASS=$(awk -F: '{print $2}' "${SOCKS5_CRED_FILE}")
else
  SOCKS5_USER="user$(head /dev/urandom | tr -dc 'a-z0-9' | head -c 5)"
  SOCKS5_PASS=$(head /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 10)
  echo "${SOCKS5_USER}:${SOCKS5_PASS}" > "${SOCKS5_CRED_FILE}"
  echo -e "${Green}Generated SOCKS5 credentials: ${SOCKS5_USER}:${SOCKS5_PASS}${Font}"
fi

# ---------- Address and name ----------
ADDR_V4="rarecloud.piggy2011.ip-ddns.com"
ADDR_V6="2a06:a880:3:42eb::1"
NAME="RareCloud"

# ---------- Port definitions ----------
declare -A PORTS=(
  [vless_tcp_reality]=10088
  [vless_xhttp_reality]=10188
  [vless_xhttp]=10288
  [vless_grpc_reality]=10388
  [ss2022]=10488
  [hy2]=10588
  [tuic]=10688
  [socks5]=10788
  [anytls]=10888
  [any_reality]=10988
  [vmess_ws_argo]=20088
)

# ---------- Argo parameters ----------
argo="y"
agn="rackcloud.piggy2011.ggff.net"
agk="eyJhIjoiMjlkNDVhNGNmMWNiZGEzYWQxODYyMDI1ZjRiMzZiNDgiLCJ0IjoiMjc2MzNiYjItYTM3ZC00MjY2LWIzZDItMzg1MzM0NWYxNGJiIiwicyI6IlptUm1NVEpqTWpVdE1EbG1aQzAwT1dNd0xXRm1NVFV0WmpCak5ERXpZVEJsTXprNSJ9"

# ---------- Generate Reality key pair if missing ----------
if [[ ! -f "${WORKDIR}/private.key" ]]; then
  openssl genpkey -algorithm X25519 -out "${WORKDIR}/private.key" >/dev/null 2>&1
  echo -e "${Green}Generated Reality private key.${Font}"
fi

# ---------- Generate sb.json ----------
echo -e "${Yellow}Generating sb.json ...${Font}"
cat > "${WORKDIR}/sb.json" <<EOF
{
  "inbounds": [
    {
      "type": "vless",
      "listen": "::",
      "listen_port": ${PORTS[vless_grpc_reality]},
      "users": [ { "uuid": "${UUID}", "flow": "xtls-rprx-vision" } ],
      "reality": {
        "enabled": true,
        "handshake": { "server": "www.bing.com", "server_port": 443 },
        "private_key": "auto",
        "short_id": "1234567890abcdef"
      },
      "transport": { "type": "grpc", "service_name": "grpc" }
    }
  ],
  "outbounds": [ { "type": "direct" }, { "type": "block" } ]
}
EOF

# ---------- Generate xr.json ----------
echo -e "${Yellow}Generating xr.json ...${Font}"
cat > "${WORKDIR}/xr.json" <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "port": ${PORTS[vmess_ws_argo]},
      "protocol": "vmess",
      "settings": {
        "clients": [ { "id": "${UUID}", "alterId": 0 } ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/argo" }
      }
    }
  ],
  "outbounds": [ { "protocol": "freedom" } ]
}
EOF

# ============================================================
# Generate subscription links (ArgoSB-compatible)
# ============================================================

LINK_FILE="${WORKDIR}/jh.txt"
> "${LINK_FILE}"

REALITY_INFO="${WORKDIR}/reality_info.txt"
if [[ -f "${REALITY_INFO}" && -s "${REALITY_INFO}" ]]; then
  PBK=$(awk -F= '/PBK/{print $2}' "${REALITY_INFO}")
  SID=$(awk -F= '/SID/{print $2}' "${REALITY_INFO}")
else
  PBK=$(head /dev/urandom | tr -dc 'A-Za-z0-9_-=' | head -c 43)
  SID=$(head /dev/urandom | tr -dc 'a-f0-9' | head -c 8)
  echo "PBK=${PBK}" > "${REALITY_INFO}"
  echo "SID=${SID}" >> "${REALITY_INFO}"
fi

SNI="www.yahoo.com"
FP="chrome"

gen_link() {
  local proto=$1 port=$2 addr=$3
  case "$proto" in
    vless_tcp_reality)
      echo "vless://${UUID}@${addr}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${SNI}&fp=${FP}&pbk=${PBK}&sid=${SID}&type=tcp&headerType=none#${NAME}-vless-tcp-reality-${addr}" ;;
    vless_xhttp_reality)
      echo "vless://${UUID}@${addr}:${port}?encryption=none&security=reality&sni=${SNI}&fp=${FP}&pbk=${PBK}&sid=${SID}&type=xhttp&path=${UUID}-xh&mode=auto#${NAME}-vless-xhttp-reality-${addr}" ;;
    vless_xhttp)
      echo "vless://${UUID}@${addr}:${port}?encryption=none&type=xhttp&path=${UUID}-xh&mode=auto#${NAME}-vless-xhttp-${addr}" ;;
    vless_grpc_reality)
      echo "vless://${UUID}@${addr}:${port}?encryption=none&security=reality&sni=${SNI}&fp=${FP}&pbk=${PBK}&sid=${SID}&type=grpc&serviceName=${UUID}-grpc#${NAME}-vless-grpc-reality-${addr}" ;;
    ss2022)
      local ssb64=$(echo -n "2022-blake3-aes-128-gcm:${SS_KEY}@${addr}:${port}" | base64 -w0)
      echo "ss://${ssb64}#${NAME}-ss2022-${addr}" ;;
    hy2)
      echo "hysteria2://${UUID}@${addr}:${port}?security=tls&alpn=h3&insecure=1&sni=www.bing.com#${NAME}-hy2-${addr}" ;;
    tuic)
      echo "tuic://${UUID}:${UUID}@${addr}:${port}?congestion_control=bbr&udp_relay_mode=native&alpn=h3&sni=www.bing.com&allow_insecure=1#${NAME}-tuic-${addr}" ;;
    socks5)
      echo "socks://${SOCKS5_USER}:${SOCKS5_PASS}@${addr}:${port}#${NAME}-socks5-${addr}" ;;
    anytls)
      echo "anytls://${UUID}@${addr}:${port}?alpn=h3#${NAME}-anytls-${addr}" ;;
    any_reality)
      echo "anytls://${UUID}@${addr}:${port}?security=reality&sni=${SNI}&pbk=${PBK}&sid=${SID}&fp=${FP}#${NAME}-any-reality-${addr}" ;;
    vmess_ws_argo)
      for p in 80 443; do
        local json="{\"v\":\"2\",\"ps\":\"${NAME}-vmess-ws-argo-${addr}-${p}\",\"add\":\"${agn}\",\"port\":\"${p}\",\"id\":\"${UUID}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${agn}\",\"path\":\"/${UUID}-vm?ed=2048\",\"tls\":\"$( [[ $p == 443 ]] && echo tls || echo none )\",\"sni\":\"${agn}\",\"alpn\":\"\"}"
        echo "vmess://$(echo -n "$json" | base64 -w0)"
      done ;;
  esac
}

for proto in "${!PORTS[@]}"; do
  for addr in "$ADDR_V4" "$ADDR_V6"; do
    gen_link "$proto" "${PORTS[$proto]}" "$addr" >> "${LINK_FILE}"
  done
done

# ============================================================
# Generate and start systemd services
# ============================================================

echo -e "${Yellow}Creating systemd services for sing-box and xray...${Font}"

# Sing-box service
cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
Description=Sing-box Service
After=network.target

[Service]
ExecStart=/usr/local/bin/sing-box run -c ${WORKDIR}/sb.json
Restart=always
RestartSec=3
User=root
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# Xray service
cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray-Core Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xray -config ${WORKDIR}/xr.json
Restart=always
RestartSec=3
User=root
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable sing-box xray >/dev/null 2>&1
systemctl restart sing-box xray >/dev/null 2>&1

echo -e "${Green}✔ sing-box and xray services deployed and started.${Font}"

# ---------- UFW Rules ----------
cat > "${WORKDIR}/ufw_rules.sh" <<'EOF'
#!/bin/bash
sudo ufw allow 10088/tcp comment "VLESS TCP Reality"
sudo ufw allow 10188/tcp comment "VLESS XHTTP Reality"
sudo ufw allow 10288/tcp comment "VLESS XHTTP"
sudo ufw allow 10388/tcp comment "VLESS gRPC Reality"
sudo ufw allow 10488/tcp comment "Shadowsocks 2022 TCP"
sudo ufw allow 10488/udp comment "Shadowsocks 2022 UDP"
sudo ufw allow 10588/udp comment "Hysteria2 UDP"
sudo ufw allow 10688/udp comment "TUIC UDP"
sudo ufw allow 10788/tcp comment "SOCKS5 TCP"
sudo ufw allow 10888/tcp comment "AnyTLS TCP"
sudo ufw allow 10988/tcp comment "AnyReality TCP"
sudo ufw allow 20088/tcp comment "VMess WS Argo Tunnel"
EOF
chmod +x "${WORKDIR}/ufw_rules.sh"

# ---------- Print subscription links ----------
echo -e "${Yellow}=========== Generated Subscription Links ===========${Font}"
cat "${LINK_FILE}"
echo -e "${Green}=====================================================${Font}"

echo -e "${Green}✔ All configuration, systemd services, and subscriptions are ready in ${WORKDIR}${Font}"
