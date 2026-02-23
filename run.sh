#!/usr/bin/env bash
# Start the tunnel monitor. Config must exist (run setup.sh first to create it).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CONFIG_FILE="${1:-config.yml}"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Config not found. Run setup first to create config.yml:"
  echo "  bash setup.sh"
  exit 1
fi

exec bash "$SCRIPT_DIR/monitor-and-failover.sh" "$CONFIG_FILE"
