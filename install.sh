#!/usr/bin/env bash
# Install and run backhul-swap from GitHub (main branch).
# Usage: curl -sSL https://raw.githubusercontent.com/hosseinpv1379/backhul-swap/main/install.sh | bash

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/hosseinpv1379/backhul-swap/main"
INSTALL_DIR="${INSTALL_DIR:-$HOME/backhul-swap}"

echo "backhul-swap: Installing to $INSTALL_DIR (from branch main) ..."
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

echo "Done. Starting run.sh ..."
echo "---"
exec bash "$INSTALL_DIR/run.sh" "$@"
