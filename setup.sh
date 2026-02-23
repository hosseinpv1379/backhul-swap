#!/usr/bin/env bash
# Interactive setup wizard for multi-service tunnel monitor.
# Asks all configuration questions and writes config.yml.

set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'

# ─── Helpers ──────────────────────────────────────────────────────────────────
title()   { echo -e "\n${BOLD}${CYAN}$*${RESET}"; }
section() { echo -e "\n${BOLD}${BLUE}── $* ──${RESET}"; }
ok()      { echo -e "${GREEN}✔${RESET} $*"; }
info()    { echo -e "${CYAN}ℹ${RESET}  $*"; }
warn()    { echo -e "${YELLOW}⚠${RESET}  $*"; }
err()     { echo -e "${RED}✘ ERROR:${RESET} $*" >&2; }

# Ask with optional default value
# Usage: ask "Question" [default] → result stored in REPLY
ask() {
  local prompt="$1"
  local default="${2:-}"
  if [[ -n "$default" ]]; then
    echo -ne "${BOLD}  ${prompt}${RESET} ${YELLOW}[${default}]${RESET}: "
  else
    echo -ne "${BOLD}  ${prompt}${RESET}: "
  fi
  read -r REPLY
  if [[ -z "$REPLY" ]] && [[ -n "$default" ]]; then
    REPLY="$default"
  fi
}

# Ask a yes/no question, return 0 for yes, 1 for no
ask_yn() {
  local prompt="$1"
  local default="${2:-y}"
  while true; do
    if [[ "$default" == "y" ]]; then
      echo -ne "${BOLD}  ${prompt}${RESET} ${YELLOW}[Y/n]${RESET}: "
    else
      echo -ne "${BOLD}  ${prompt}${RESET} ${YELLOW}[y/N]${RESET}: "
    fi
    read -r ans
    ans="${ans:-$default}"
    case "${ans,,}" in
      y|yes) return 0 ;;
      n|no)  return 1 ;;
      *)     warn "Please answer y or n." ;;
    esac
  done
}

# Validate IP address format
validate_ip() {
  local ip="$1"
  if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    return 0
  fi
  return 1
}

# Folder where backhaul toml configs live (user copies paths from here)
BACKHAUL_CORE_DIR="/root/backhaul-core"

# List systemd services whose name contains "backhaul" so user can copy
list_backhaul_services() {
  echo -e "  ${BOLD}Backhaul-related systemd services:${RESET}"
  if command -v systemctl &>/dev/null; then
    local list
    list=$(systemctl list-unit-files --type=service --no-pager --no-legend 2>/dev/null | awk '{print $1}' | grep -i backhaul || true)
    if [[ -n "$list" ]]; then
      echo "$list" | head -50 | while read -r s; do echo "    $s"; done
    else
      echo "    (none found; list-unit-files or grep backhaul)"
    fi
  else
    echo "    (systemctl not available)"
  fi
  echo ""
}

# List toml files in BACKHAUL_CORE_DIR so user can copy path
list_toml_configs() {
  if [[ ! -d "$BACKHAUL_CORE_DIR" ]]; then
    warn "Folder $BACKHAUL_CORE_DIR does not exist. Enter path manually."
    return
  fi
  echo -e "  ${BOLD}Toml configs in ${BACKHAUL_CORE_DIR}:${RESET}"
  local list
  list=$(ls -1 "$BACKHAUL_CORE_DIR"/*.toml 2>/dev/null || true)
  if [[ -n "$list" ]]; then
    echo "$list" | head -50 | while read -r f; do echo "    $f"; done
  else
    echo "    (no .toml files found)"
  fi
  echo ""
}

# ─── Banner ───────────────────────────────────────────────────────────────────
clear
echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║     Multi-Service Tunnel Monitor — Setup Wizard          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${RESET}"
info "This wizard will create your config.yml for monitor-and-failover.sh"
info "Press Enter to accept the default value shown in [brackets]."
echo ""

OUTPUT_FILE="config.yml"

# ─── Backup existing config ───────────────────────────────────────────────────
if [[ -f "$OUTPUT_FILE" ]]; then
  backup="${OUTPUT_FILE}.bak.$(date +%Y%m%d%H%M%S)"
  cp "$OUTPUT_FILE" "$backup"
  warn "Existing config.yml backed up to: $backup"
fi

# ─── Global settings ─────────────────────────────────────────────────────────
section "Global Settings"

while true; do
  ask "Cooldown seconds (min wait between swaps to avoid flip-flop)" "600"
  cooldown="$REPLY"
  if [[ "$cooldown" =~ ^[0-9]+$ ]] && (( cooldown >= 0 )); then
    break
  fi
  err "Cooldown must be a non-negative integer."
done
ok "Cooldown: ${cooldown}s"

# ─── Number of services ───────────────────────────────────────────────────────
section "Services"
info "Each service = one tunnel pair (Iran server ↔ Foreign server)."
echo ""
echo -e "  ${BOLD}On this system (copy names/paths when asked):${RESET}"
echo ""
list_backhaul_services
list_toml_configs

while true; do
  ask "How many services do you want to monitor?" "1"
  count="$REPLY"
  if [[ "$count" =~ ^[0-9]+$ ]] && (( count >= 1 )); then
    break
  fi
  err "Must be a positive integer."
done
ok "Services count: $count"

# ─── Collect per-service details ─────────────────────────────────────────────
declare -a svc_names=()
declare -a svc_service_names=()
declare -a svc_filenames=()
declare -a svc_ping_ips=()
declare -a svc_roles=()

for (( i=1; i<=count; i++ )); do
  section "Service $i of $count"

  # ── Nickname ──────────────────────────────────────────────────────────────
  while true; do
    ask "Short name / nickname for this service (no spaces, e.g. kharej80)" "service${i}"
    name="$REPLY"
    if [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
      break
    fi
    err "Name must contain only letters, digits, underscores, or dashes."
  done

  # ── Systemd service name (show backhaul services on system) ───────────────
  list_backhaul_services
  ask "Systemd service name to restart (copy from list above)" "backhaul-${name}.service"
  service_name="$REPLY"

  # ── Config file path (from /root/backhaul-core/) ───────────────────────────
  list_toml_configs
  ask "Path to .toml config (copy from list above, or enter path)" "${BACKHAUL_CORE_DIR}/${name}.toml"
  filename="$REPLY"

  # ── Ping IP ───────────────────────────────────────────────────────────────
  while true; do
    ask "IP address to ping (usually the tunnel peer IP, e.g. 10.10.10.1)"
    ping_ip="$REPLY"
    if validate_ip "$ping_ip"; then
      break
    fi
    err "Invalid IP address format: $ping_ip"
  done

  # ── Role ──────────────────────────────────────────────────────────────────
  while true; do
    ask "Role for this service (primary / secondary — for logging only)" "primary"
    role="${REPLY,,}"
    if [[ "$role" == "primary" ]] || [[ "$role" == "secondary" ]]; then
      break
    fi
    err "Role must be 'primary' or 'secondary'."
  done

  svc_names+=("$name")
  svc_service_names+=("$service_name")
  svc_filenames+=("$filename")
  svc_ping_ips+=("$ping_ip")
  svc_roles+=("$role")

  ok "Service $i configured: name=$name | ping=$ping_ip | role=$role"
done

# ─── Summary ─────────────────────────────────────────────────────────────────
section "Configuration Summary"
echo ""
printf "  ${BOLD}%-4s %-16s %-36s %-16s %-14s %s${RESET}\n" \
       "#" "Name" "Service" "Ping IP" "Role" "File"
printf "  %s\n" "$(printf '─%.0s' {1..90})"
for (( i=0; i<count; i++ )); do
  printf "  %-4s %-16s %-36s %-16s %-14s %s\n" \
    "$((i+1))" \
    "${svc_names[$i]}" \
    "${svc_service_names[$i]}" \
    "${svc_ping_ips[$i]}" \
    "${svc_roles[$i]}" \
    "${svc_filenames[$i]}"
done
echo ""
info "Global cooldown: ${cooldown}s"
echo ""

if ! ask_yn "Save configuration to ${OUTPUT_FILE}?"; then
  warn "Aborted. No file written."
  exit 0
fi

# ─── Write config.yml ─────────────────────────────────────────────────────────
{
  cat <<HEADER
# =====================================================
#  Multi-Service Tunnel Monitor - Configuration File
#  Generated by setup.sh on $(date '+%Y-%m-%d %H:%M:%S')
# =====================================================

# Global cooldown: seconds to wait after a swap before allowing another swap
cooldown_seconds: ${cooldown}

# Total number of services to monitor
services_count: ${count}

HEADER

  for (( i=0; i<count; i++ )); do
    num=$((i+1))
    cat <<SVC
# -------------------------------------------------------
# Service ${num}: ${svc_names[$i]}
# -------------------------------------------------------
service_${num}_name: "${svc_names[$i]}"
service_${num}_service_name: "${svc_service_names[$i]}"
service_${num}_filename: "${svc_filenames[$i]}"
service_${num}_ping_ip: "${svc_ping_ips[$i]}"
service_${num}_role: "${svc_roles[$i]}"

SVC
  done
} > "$OUTPUT_FILE"

ok "Configuration saved to: $(realpath "$OUTPUT_FILE")"

# ─── Optional: set up systemd unit for the monitor itself ────────────────────
echo ""
if ask_yn "Do you want to install a systemd service for monitor-and-failover.sh itself?"; then
  UNIT_NAME="tunnel-monitor.service"
  SCRIPT_PATH="$(realpath "$(dirname "$0")/monitor-and-failover.sh")"
  CONFIG_PATH="$(realpath "$OUTPUT_FILE")"

  section "Creating systemd unit: $UNIT_NAME"

  cat > /tmp/"$UNIT_NAME" <<UNIT
[Unit]
Description=Multi-Service Tunnel Monitor (profile swap failover)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/bash ${SCRIPT_PATH} ${CONFIG_PATH}
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNIT

  if sudo mv /tmp/"$UNIT_NAME" /etc/systemd/system/"$UNIT_NAME"; then
    sudo systemctl daemon-reload
    if ask_yn "Enable $UNIT_NAME to start on boot?"; then
      sudo systemctl enable "$UNIT_NAME"
      ok "Service enabled."
    fi
    if ask_yn "Start $UNIT_NAME now?"; then
      sudo systemctl start "$UNIT_NAME"
      ok "Service started."
      info "Check status with: sudo systemctl status $UNIT_NAME"
      info "Watch logs with:   sudo journalctl -fu $UNIT_NAME"
    fi
  else
    warn "Could not write to /etc/systemd/system/. Run as root or install manually."
    info "Unit file is at: /tmp/$UNIT_NAME"
  fi
fi

# ─── Final instructions ───────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}══════════════════════════════════════════${RESET}"
echo -e "${BOLD}${GREEN}  Setup complete!${RESET}"
echo -e "${BOLD}${GREEN}══════════════════════════════════════════${RESET}"
echo ""
info "To run the monitor manually:"
echo -e "    ${BOLD}bash monitor-and-failover.sh${RESET}"
echo ""
info "To run with a custom config:"
echo -e "    ${BOLD}bash monitor-and-failover.sh /path/to/config.yml${RESET}"
echo ""
info "To add more services later, re-run this wizard or edit ${OUTPUT_FILE} directly."
echo ""
