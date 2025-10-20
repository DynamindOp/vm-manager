#!/bin/bash
set -euo pipefail
clear

# 🔷 Blue header lines
header=(
"-----------------------------------------------------------"
"        VM Manager By DynamindGaming (Debian)"
"-----------------------------------------------------------"
)

# 🟢 Menu options (fixed numbering)
menu=(
"1  : Jishnu Pterodactyl Panel"
"2  : Python 24/7 Code"
"3  : Firewall Protection"
"4  : IPv4 Allocation (Pterodactyl)"
"5  : CloudFlare Tunnel Setup"
"6  : Neofetch Installer"
"7  : IDX 24/7 by GamerBoy_L"
"8  : VM Manager HopingBoyz"
"9  : PLAYIT plugin"
"10 : SSHX.io setup"
"11 : Tailscale setup"
"12 : DDoS Protection"
"0  : Exit"
)

# Colors
PURPLE="\e[35m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
RESET="\e[0m"

# 🔹 Function to show UI with animation
show_ui() {
  clear
  for line in "${header[@]}"; do
    echo -e "\e[38;5;208;1m$line\e[0m"
    sleep 0.08
  done
  echo ""
  for option in "${menu[@]}"; do
    echo -e "${PURPLE}$option${RESET}"
    sleep 0.05
  done
  echo ""
}

# 🔹 Safe command runner with error handling (runs functions/commands)
run_command() {
  # $1 is the command string or function name to eval
  if ! eval "$1"; then
    echo -e "${PURPLE}An Unexpected Error Occured While Starting The Manager${RESET}"
  fi
  echo -e "\n${PURPLE}Press Enter To Return To Menu${RESET}"
  read -r
}

# ============================
# Functions for each option
# ============================

# 1) Jishnu Pterodactyl Panel
jishnu_panel() {
  # this may show its own menu/submenu; keep interactive
  bash <(curl -s https://ptero.jishnu.fun) || return 1
  return 0
}

# 2) Python 24/7 Code
python_runner() {
  python3 <(curl -s https://raw.githubusercontent.com/JishnuTheGamer/24-7/refs/heads/main/24) || return 1
  return 0
}

# 3) Firewall Protection (UFW) - allows Minecraft default port 25565 and typical panel ports
firewall_protection() {
  apt update -y || true
  apt install -y ufw >/dev/null 2>&1 || return 1
  ufw allow 22/tcp
  ufw allow 80/tcp
  ufw allow 443/tcp
  ufw allow 25565/tcp
  # allow common pterodactyl allocation range if desired
  ufw allow 19100:19200/tcp
  ufw --force enable
  echo -e "${GREEN}✅ UFW enabled and common ports allowed.${RESET}"
  return 0
}

# 4) IPv4 Allocation (creates alias and persists for Debian)
ipv4_allocation() {
  echo -e "${YELLOW}Note: run this on the node host. Make sure the IP you assign is routed/owned by your VPS provider.${RESET}"
  echo ""
  echo "Detected network interfaces:"
  ip -o link show | awk -F': ' '{print " - " $2}'
  echo ""
  read -rp "Enter the physical interface to attach alias to (e.g. eth0): " IFACE
  if [[ -z "$IFACE" ]]; then
    echo -e "${PURPLE}An Unexpected Error Occured While Starting The Manager${RESET}"
    return 1
  fi

  read -rp "Enter the IPv4 you want to allocate (e.g. 203.0.113.5): " NEW_IP
  if [[ -z "$NEW_IP" ]]; then
    echo -e "${PURPLE}An Unexpected Error Occured While Starting The Manager${RESET}"
    return 1
  fi

  read -rp "Enter CIDR prefix (e.g. 24) [24]: " PREFIX
  PREFIX=${PREFIX:-24}

  # create alias immediately
  sudo ip addr add "${NEW_IP}/${PREFIX}" dev "${IFACE}" label "${IFACE}:1" || {
    echo -e "${PURPLE}Failed to add IP alias. Check that IP is valid and interface exists.${RESET}"
    return 1
  }

  # persist configuration: create a simple interfaces.d file (Debian)
  mkdir -p /etc/network/interfaces.d
  ALIAS_FILE="/etc/network/interfaces.d/${IFACE}:1.cfg"
  cat > "${ALIAS_FILE}" <<EOF
auto ${IFACE}:1
iface ${IFACE}:1 inet static
    address ${NEW_IP}
    netmask $(python3 - <<PY
p=${PREFIX}
mask = [(0xffffffff << (32 - p)) & 0xffffffff]
print("{}.{}.{}.{}".format((mask:=((0xffffffff << (32 - p)) & 0xffffffff))>>24 & 0xff, (mask>>16)&0xff, (mask>>8)&0xff, mask&0xff))
PY
)
EOF

  # If the above python approach fails for netmask, fallback to 255.255.255.0
  if [[ $? -ne 0 ]]; then
    cat > "${ALIAS_FILE}" <<EOF
auto ${IFACE}:1
iface ${IFACE}:1 inet static
    address ${NEW_IP}
    netmask 255.255.255.0
EOF
  fi

  echo -e "${GREEN}✅ Alias ${IFACE}:1 with ${NEW_IP}/${PREFIX} created and persisted at ${ALIAS_FILE}.${RESET}"
  echo -e "${YELLOW}Now you can add ${NEW_IP} as an allocation in Pterodactyl (Panel → Nodes → Add Allocation).${RESET}"

  return 0
}

# 5) Cloudflared Tunnel Setup
cloudflared_setup() {
  # install cloudflared from package repo if not present
  if ! command -v cloudflared >/dev/null 2>&1; then
    curl -fsSL https://pkg.cloudflare.com/gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list >/dev/null
    apt update && apt install -y cloudflared || return 1
  fi

  cloudflared tunnel login || return 1
  read -rp "Enter tunnel name (e.g. vm-tunnel): " TUNNEL_NAME
  [[ -n "$TUNNEL_NAME" ]] || { echo -e "${PURPLE}Tunnel name required.${RESET}"; return 1; }

  cloudflared tunnel create "$TUNNEL_NAME" || return 1

  mkdir -p /etc/cloudflared
  TID=$(cloudflared tunnel list | awk -v tn="$TUNNEL_NAME" '$0 ~ tn {print $1; exit}')
  if [[ -z "$TID" ]]; then
    echo -e "${PURPLE}Failed to find tunnel ID.${RESET}"
    return 1
  fi

  cat > /etc/cloudflared/config.yml <<EOF
tunnel: ${TID}
credentials-file: /root/.cloudflared/${TID}.json
ingress:
  - hostname: ${TUNNEL_NAME}.trycloudflare.com
    service: http://localhost:25565
  - service: http_status:404
EOF

  # Install systemd service (cloudflared provides 'service install', but ensure fallback)
  if ! cloudflared service install >/dev/null 2>&1; then
    cat >/etc/systemd/system/cloudflared.service <<EOF
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
ExecStart=$(command -v cloudflared) tunnel --config /etc/cloudflared/config.yml run
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now cloudflared || true
  fi

  echo -e "${GREEN}✅ Cloudflared tunnel ${TUNNEL_NAME} created and started.${RESET}"
  return 0
}

# 6) Neofetch
neofetch_install() {
  apt update -y || true
  apt install -y neofetch || return 1
  echo -e "${GREEN}✅ neofetch installed.${RESET}"
  return 0
}

# 7) IDX 24/7 by GamerBoy_L
idx_installer() {
  bash <(curl -s https://raw.githubusercontent.com/rredefined/Vm-Manager/main/neverOFF) || return 1
  return 0
}

# 8) HopingBoyz VM Manager
hopingboyz_manager() {
  bash <(curl -s https://vps1.jishnu.fun) || return 1
  return 0
}

# 9) PLAYIT plugin
playit_plugin() {
  bash <(curl -fsSL https://raw.githubusercontent.com/hopingboyz/playit/main/playit.sh) || return 1
  return 0
}

# 10) SSHX.io setup
sshx_setup() {
  curl -sSf https://sshx.io/get | sh || return 1
  return 0
}

# 11) Tailscale setup
tailscale_setup() {
  curl -fsSL https://tailscale.com/install.sh | sh || return 1
  return 0
}

# 12) DDoS Protection (installs iptables, optional remote script)
ddos_protection() {
  apt update -y || true
  apt install -y iptables || return 1
  # Example basic rule: allow SSH (keep you from locking out)
  iptables -A INPUT -p tcp --dport 22 -j ACCEPT || true
  echo -e "${GREEN}✅ iptables installed and basic SSH rule added.${RESET}"

  read -rp "Run remote DDoS script? (paste URL, leave empty to skip): " DDOS_URL
  if [[ -n "$DDOS_URL" ]]; then
    # run remote script
    if ! curl -s "$DDOS_URL" | bash; then
      echo -e "${PURPLE}An Unexpected Error Occured While Starting The Manager${RESET}"
      return 1
    fi
    echo -e "${GREEN}✅ Remote DDoS script executed.${RESET}"
  fi

  return 0
}

# ============================
# Main loop
# ============================
while true; do
  show_ui
  read -rp $'\e[36mEnter your choice: \e[0m' choice
  clear
  case "$choice" in
    1) run_command "jishnu_panel" ;;
    2) run_command "python_runner" ;;
    3) run_command "firewall_protection" ;;
    4) run_command "ipv4_allocation" ;;
    5) run_command "cloudflared_setup" ;;
    6) run_command "neofetch_install" ;;
    7) run_command "idx_installer" ;;
    8) run_command "hopingboyz_manager" ;;
    9) run_command "playit_plugin" ;;
    10) run_command "sshx_setup" ;;
    11) run_command "tailscale_setup" ;;
    12) run_command "ddos_protection" ;;
    0)
      echo -e "${PURPLE}Exiting Manager...${RESET}"
      exit 0
      ;;
    *)
      # invalid input — show purple error then return to menu
      echo -e "${PURPLE}An Unexpected Error Occured While Starting The Manager${RESET}"
      sleep 1.2
      ;;
  esac
done
