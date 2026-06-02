#!/usr/bin/env bash
set -euo pipefail

APP_NAME="firewall-wiki-community"
INSTALL_DIR="/opt/${APP_NAME}"
CONFIG_PATH="${INSTALL_DIR}/config.cfg"
SERVICE_PATH="/etc/systemd/system/${APP_NAME}.service"

REPO_RAW="${REPO_RAW:-https://raw.githubusercontent.com/firewall-wiki/community/main}"
CONFIG_URL="${CONFIG_URL:-}"

IFACE="${IFACE:-eth0}"

need_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: run as root"
    exit 1
  fi
}

detect_pkg_manager() {
  if command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  elif command -v yum >/dev/null 2>&1; then
    echo "yum"
  elif command -v apt-get >/dev/null 2>&1; then
    echo "apt"
  else
    echo "unknown"
  fi
}

install_deps() {
  local pm
  pm="$(detect_pkg_manager)"

  case "$pm" in
    dnf)
      dnf install -y iproute bpftool bash coreutils systemd curl ca-certificates
      ;;
    yum)
      yum install -y iproute bpftool bash coreutils systemd curl ca-certificates
      ;;
    apt)
      apt-get update
      apt-get install -y iproute2 bpftool bash coreutils systemd curl ca-certificates
      ;;
    *)
      echo "WARN: unknown package manager, dependency install skipped"
      ;;
  esac
}

check_kernel() {
  local major
  major="$(uname -r | cut -d. -f1)"

  if [ "$major" -lt 5 ] || [ "$major" -gt 6 ]; then
    echo "ERROR: Linux kernel 5.x or 6.x is required"
    echo "Current kernel: $(uname -r)"
    exit 1
  fi
}

check_iface() {
  if ! ip link show "$IFACE" >/dev/null 2>&1; then
    echo "ERROR: interface not found: $IFACE"
    echo "Available interfaces:"
    ip -o link show | awk -F': ' '{print " - " $2}'
    exit 1
  fi
}

download_file() {
  local url="$1"
  local dst="$2"

  echo "Downloading: $url"
  curl -fsSL "$url" -o "$dst"
}

install_files() {
  mkdir -p "$INSTALL_DIR"

  download_file "${REPO_RAW}/release/firewall.wiki" "$INSTALL_DIR/firewall.wiki"
  download_file "${REPO_RAW}/release/libfirewall_core.so" "$INSTALL_DIR/libfirewall_core.so"
  download_file "${REPO_RAW}/release/origin.o" "$INSTALL_DIR/origin.o"

  chmod +x "$INSTALL_DIR/firewall.wiki"
  chmod 644 "$INSTALL_DIR/libfirewall_core.so" "$INSTALL_DIR/origin.o"
}

set_cfg_value() {
  local key="$1"
  local value="$2"

  if grep -q "^${key}=" "$CONFIG_PATH"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$CONFIG_PATH"
  else
    printf "\n%s=%s\n" "$key" "$value" >> "$CONFIG_PATH"
  fi
}

install_config() {
  mkdir -p "$INSTALL_DIR"

  if [ -n "$CONFIG_URL" ]; then
    download_file "$CONFIG_URL" "$CONFIG_PATH"
  else
    download_file "${REPO_RAW}/config.example.cfg" "$CONFIG_PATH"
  fi

  set_cfg_value "iface" "$IFACE"

  if [ -n "${ORIGIN_PORT:-}" ]; then
    set_cfg_value "origin_port" "$ORIGIN_PORT"
  fi
}

write_service() {
  cat > "$SERVICE_PATH" <<SERVICEEOF
[Unit]
Description=Firewall.wiki Community Origin Protection
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}
Environment=ORIGIN_IFACE=${IFACE}
Environment=ORIGIN_CONFIG=${CONFIG_PATH}
ExecStart=${INSTALL_DIR}/firewall.wiki -iface ${IFACE} -config ${CONFIG_PATH}
Restart=always
RestartSec=2
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
SERVICEEOF
}

write_uninstall() {
  cat > "${INSTALL_DIR}/uninstall.sh" <<UNINSTALLEOF
#!/usr/bin/env bash
set -euo pipefail

systemctl stop ${APP_NAME} 2>/dev/null || true
systemctl disable ${APP_NAME} 2>/dev/null || true
rm -f ${SERVICE_PATH}
systemctl daemon-reload

tc qdisc del dev ${IFACE} clsact 2>/dev/null || true

rm -rf ${INSTALL_DIR}

echo "Firewall.wiki Community removed"
UNINSTALLEOF

  chmod +x "${INSTALL_DIR}/uninstall.sh"
}

main() {
  need_root
  check_kernel
  install_deps
  check_iface
  install_files
  install_config
  write_service
  write_uninstall

  systemctl daemon-reload
  systemctl enable "$APP_NAME"
  systemctl restart "$APP_NAME"

  echo
  echo "Firewall.wiki Community installed"
  echo "Interface: ${IFACE}"
  echo "Config: ${CONFIG_PATH}"
  echo
  echo "Recommended deployment:"
  echo "  Visitor -> Cloudflare -> Origin"
  echo
  echo "Status:"
  echo "  systemctl status ${APP_NAME}"
  echo
  echo "Logs:"
  echo "  journalctl -u ${APP_NAME} -f"
}

main "$@"
