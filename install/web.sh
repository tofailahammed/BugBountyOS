#!/usr/bin/env bash

set -Eeuo pipefail

LOG_FILE="logs/install-web.log"

mkdir -p logs

exec > >(tee -a "$LOG_FILE") 2>&1

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
NC="\033[0m"

echo
echo "========================================"
echo " BugBountyOS - Web Discovery Installer"
echo "========================================"
echo
export PATH="$PATH:$(go env GOPATH)/bin"

echo -e "${GREEN}Checking Go...${NC}"

go version
echo
echo "Installing Katana..."
go install github.com/projectdiscovery/katana/cmd/katana@latest

echo
echo "Installing gau..."
go install github.com/lc/gau/v2/cmd/gau@latest

echo
echo "Installing waybackurls..."
go install github.com/tomnomnom/waybackurls@latest

echo
echo "Installing hakrawler..."
go install github.com/hakluke/hakrawler@latest

echo
echo "Installing gospider..."
go install github.com/jaeles-project/gospider@latest

echo
echo "Installing ffuf..."
go install github.com/ffuf/ffuf/v2@latest
echo
echo "Installing ParamSpider..."

python3 -m pip install --upgrade pip

python3 -m pip install paramspider

echo
echo "Installing Arjun..."

python3 -m pip install arjun

echo
echo "Installing dirsearch..."

python3 -m pip install dirsearch
echo
echo "Skipping feroxbuster for now (will install in a dedicated module)."
echo
echo "Skipping gowitness (Phase 10.2)"
echo
echo "========== VERIFY =========="

for tool in \
katana \
gau \
waybackurls \
hakrawler \
gospider \
ffuf \
arjun
do
    if command -v "$tool" >/dev/null 2>&1
    then
        echo "[OK] $tool"
    else
        echo "[FAIL] $tool"
    fi
done

echo
echo "Web Discovery Installation Finished."
