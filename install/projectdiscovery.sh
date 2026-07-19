#!/usr/bin/env bash
set -euo pipefail

GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m"

echo -e "${GREEN}==> Installing ProjectDiscovery tools...${NC}"

# Ensure Go binaries are on PATH
export PATH="$PATH:$(go env GOPATH)/bin"

TOOLS=(
  "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
  "github.com/projectdiscovery/httpx/cmd/httpx@latest"
  "github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
  "github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"
  "github.com/projectdiscovery/katana/cmd/katana@latest"
  "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
)

for tool in "${TOOLS[@]}"; do
    echo "[+] Installing $tool"
    go install "$tool"
done

echo
echo "========== VERIFY =========="

subfinder -version || true
httpx -version || true
dnsx -version || true
naabu -version || true
katana -version || true
nuclei -version || true

echo
echo -e "${GREEN}ProjectDiscovery installation complete.${NC}"
