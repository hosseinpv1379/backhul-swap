#!/usr/bin/env bash
# One entry point: if no config, run setup wizard then start monitor. Otherwise start monitor.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CONFIG_FILE="${1:-config.yml}"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "No config yet. Running setup (questions → config.yml) ..."
  bash "$SCRIPT_DIR/setup.sh"
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Setup did not create config. Exiting."
    exit 1
  fi
  echo ""
  echo "Starting monitor..."
  echo "---"
fi

exec bash "$SCRIPT_DIR/monitor-and-failover.sh" "$CONFIG_FILE"
