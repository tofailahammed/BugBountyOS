#!/usr/bin/env bash
set -euo pipefail

echo "[+] Updating packages..."

sudo apt update

sudo apt install -y \
git curl wget unzip zip \
build-essential \
jq tree tmux parallel \
ripgrep fd-find \
python3 python3-pip python3-venv \
nmap dnsutils whois \
vim nano

echo "[+] Core packages installed."
