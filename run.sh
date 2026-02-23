#!/usr/bin/env bash
# Single entry point: run setup if needed, then start the tunnel monitor.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CONFIG_FILE="${1:-config.yml}"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Config not found. Running setup wizard..."
  bash "$SCRIPT_DIR/setup.sh"
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Setup did not create config. Exiting."
  exit 1
fi

exec bash "$SCRIPT_DIR/monitor-and-failover.sh" "$CONFIG_FILE"
