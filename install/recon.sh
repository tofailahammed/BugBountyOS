#!/usr/bin/env bash
set -euo pipefail

echo "=================================="
echo " Installing Recon Tools"
echo "=================================="

export PATH=$PATH:$(go env GOPATH)/bin

echo "[1/8] Installing Amass..."

go install github.com/owasp-amass/amass/v4/...@master

echo "[2/8] Installing Assetfinder..."

go install github.com/tomnomnom/assetfinder@latest

echo "[3/8] Installing Waybackurls..."

go install github.com/tomnomnom/waybackurls@latest

echo "[4/8] Installing gau..."

go install github.com/lc/gau/v2/cmd/gau@latest

echo "[5/8] Installing Hakrawler..."

go install github.com/hakluke/hakrawler@latest

echo "[6/8] Installing FFUF..."

go install github.com/ffuf/ffuf/v2@latest

echo

echo "Recon Installation Completed."
