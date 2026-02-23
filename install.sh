#!/usr/bin/env bash
# Download backhul-swap and run setup wizard (create config only). Does not start the monitor.
# Usage: curl -sSL https://raw.githubusercontent.com/hosseinpv1379/backhul-swap/master/install.sh | bash

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/hosseinpv1379/backhul-swap/master"
INSTALL_DIR="${INSTALL_DIR:-$HOME/backhul-swap}"

echo "backhul-swap: Installing to $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

for f in run.sh setup.sh monitor-and-failover.sh; do
  echo "  Downloading $f ..."
  if command -v curl &>/dev/null; then
    curl -sSL "$REPO_RAW/$f" -o "$f"
  elif command -v wget &>/dev/null; then
    wget -q "$REPO_RAW/$f" -O "$f"
  else
    echo "Error: need curl or wget to download." >&2
    exit 1
  fi
  chmod +x "$f"
done

echo "Done. Starting (first time: questions → config → monitor)..."
echo "---"
exec bash "$INSTALL_DIR/run.sh"
