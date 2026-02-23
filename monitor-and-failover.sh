#!/usr/bin/env bash
# Multi-service ping monitor.
# On ping failure, swaps profile (bip<->tcp) in config and restarts the service.
# Supports multiple services running in parallel background loops.
# Intended to run continuously (e.g. under systemd, screen, or nohup).

set -euo pipefail

# ─── Color helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()  { echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')]${RESET} $*"; }
warn() { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARN${RESET} $*" >&2; }
err()  { echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR${RESET} $*" >&2; }

# ─── Config file ──────────────────────────────────────────────────────────────
CONFIG_FILE="${1:-config.yml}"
if [[ ! -f "$CONFIG_FILE" ]]; then
  err "Config file not found: $CONFIG_FILE"
  echo "Usage: $0 [path/to/config.yml]"
  echo "       Run setup.sh first to generate config.yml"
  exit 1
fi

# Read a plain key: value from YAML (no yq required)
get_yml() {
  local key="$1"
  grep -E "^\s*${key}\s*:" "$CONFIG_FILE" \
    | sed -E "s/^[^:]+:[[:space:]]*[\"']?([^\"'#]*)[\"']?.*/\1/" \
    | sed 's/[[:space:]]*$//' \
    | head -1
}

# ─── Global config ────────────────────────────────────────────────────────────
COOLDOWN_SECONDS=$(get_yml "cooldown_seconds")
COOLDOWN_SECONDS="${COOLDOWN_SECONDS:-600}"

SERVICES_COUNT=$(get_yml "services_count")
if [[ -z "$SERVICES_COUNT" ]] || ! [[ "$SERVICES_COUNT" =~ ^[0-9]+$ ]] || (( SERVICES_COUNT < 1 )); then
  err "services_count is missing or invalid in $CONFIG_FILE"
  exit 1
fi

# ─── Swap profiles in a toml file (bip <-> tcp) ───────────────────────────────
swap_profiles() {
  local filename="$1"
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' \
      -e 's/profile = "bip"/profile = "__TMP__"/' \
      -e 's/profile = "tcp"/profile = "bip"/' \
      -e 's/profile = "__TMP__"/profile = "tcp"/' \
      "$filename"
  else
    sed -i.bak \
      -e 's/profile = "bip"/profile = "__TMP__"/' \
      -e 's/profile = "tcp"/profile = "bip"/' \
      -e 's/profile = "__TMP__"/profile = "tcp"/' \
      "$filename"
  fi
}

# ─── Restart a systemd (or sysv) service ─────────────────────────────────────
restart_service() {
  local service_name="$1"
  if command -v systemctl &>/dev/null; then
    sudo systemctl restart "$service_name" || true
  elif command -v service &>/dev/null; then
    sudo service "$service_name" restart || true
  else
    warn "systemctl/service not found — restart $service_name manually."
  fi
}

# ─── Per-service monitor loop (runs in background subshell) ──────────────────
monitor_service() {
  local svc_name="$1"
  local service_name="$2"
  local filename="$3"
  local ping_ip="$4"
  local role="$5"
  local cooldown="$6"
  local last_swap_time=0

  log "${BOLD}[$svc_name]${RESET} Monitor started | ping=${ping_ip} | role=${role} | cooldown=${cooldown}s"

  while true; do
    if ping -c 1 -W 3 "$ping_ip" &>/dev/null; then
      # Ping OK — print a dot as heartbeat
      printf "${GREEN}.${RESET}"
    else
      echo ""
      local now
      now=$(date +%s)
      local elapsed=$(( now - last_swap_time ))

      if (( elapsed < cooldown )); then
        local remaining=$(( cooldown - elapsed ))
        log "${YELLOW}[$svc_name]${RESET} Ping ${ping_ip} failed. Cooldown active (${remaining}s left), skipping swap."
      else
        last_swap_time=$now
        log "${RED}[$svc_name]${RESET} Ping ${ping_ip} failed. Swapping bip<->tcp and restarting ${service_name}..."

        if [[ ! -f "$filename" ]]; then
          err "[$svc_name] Config file not found: $filename — skipping swap."
        else
          swap_profiles "$filename"
          log "[$svc_name] File updated: $filename"
          restart_service "$service_name"
          log "${GREEN}[$svc_name]${RESET} Service restarted. Resuming monitor..."
        fi
      fi
    fi
    sleep 5
  done
}

# ─── Banner ───────────────────────────────────────────────────────────────────
echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════╗"
echo "║       Multi-Service Tunnel Monitor               ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${RESET}"
log "Config: ${CONFIG_FILE} | Services: ${SERVICES_COUNT} | Global cooldown: ${COOLDOWN_SECONDS}s"
echo ""

# ─── Validate and launch a background monitor per service ────────────────────
PIDS=()

cleanup() {
  echo ""
  log "Shutting down all monitors..."
  for pid in "${PIDS[@]}"; do
    kill "$pid" 2>/dev/null || true
  done
  exit 0
}
trap cleanup SIGINT SIGTERM

for i in $(seq 1 "$SERVICES_COUNT"); do
  svc_name=$(get_yml    "service_${i}_name")
  service_name=$(get_yml "service_${i}_service_name")
  filename=$(get_yml    "service_${i}_filename")
  ping_ip=$(get_yml     "service_${i}_ping_ip")
  role=$(get_yml        "service_${i}_role")
  role="${role:-primary}"

  # Validate required fields
  local_err=0
  for field in svc_name service_name filename ping_ip; do
    eval "val=\$$field"
    if [[ -z "$val" ]]; then
      err "service_${i}_${field} is missing in $CONFIG_FILE"
      local_err=1
    fi
  done
  (( local_err )) && exit 1

  log "Launching monitor for service $i: ${svc_name} (${service_name})"
  monitor_service "$svc_name" "$service_name" "$filename" "$ping_ip" "$role" "$COOLDOWN_SECONDS" &
  PIDS+=($!)
done

echo ""
log "All ${SERVICES_COUNT} monitors running in background. Press Ctrl+C to stop all."
echo ""

# Wait for all background monitors
wait
