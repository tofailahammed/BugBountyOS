#!/usr/bin/env bash

set -Eeuo pipefail

LOG_FILE="logs/install-javascript.log"

mkdir -p logs

exec > >(tee -a "$LOG_FILE") 2>&1

export PATH="$PATH:$(go env GOPATH)/bin"

echo "======================================="
echo " BugBountyOS JavaScript Installer"
echo "======================================="
echo
echo "===== Verification ====="

python3 /workspaces/BugBountyOS/tools/LinkFinder/linkfinder.py -h >/dev/null && echo "[OK] LinkFinder"

python3 /workspaces/BugBountyOS/tools/SecretFinder/SecretFinder.py -h >/dev/null && echo "[OK] SecretFinder"

command -v xnLinkFinder >/dev/null && echo "[OK] xnLinkFinder"
