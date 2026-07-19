#!/usr/bin/env bash

set -Eeuo pipefail

LOG_FILE="logs/install-bbot.log"

mkdir -p logs

exec > >(tee -a "$LOG_FILE") 2>&1

echo "================================="
echo "Installing BBOT"
echo "================================="
sudo apt update

sudo apt install -y python3-pip git
bbot --version
