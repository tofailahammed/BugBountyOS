#!/usr/bin/env bash

TOOLS=(
subfinder
httpx
dnsx
naabu
katana
nuclei
assetfinder
waybackurls
gau
hakrawler
ffuf
)

echo "========== Tool Verification =========="

for tool in "${TOOLS[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        printf "[OK]   %s\n" "$tool"
    else
        printf "[FAIL] %s\n" "$tool"
    fi
done
