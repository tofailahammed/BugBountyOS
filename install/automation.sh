#!/usr/bin/env bash

set -Eeuo pipefail

echo "Updating apt..."

sudo apt update

echo "Updating Python..."

python3 -m pip install --upgrade pip

echo "Updating Go tools..."

go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest

go install github.com/projectdiscovery/httpx/cmd/httpx@latest

go install github.com/projectdiscovery/katana/cmd/katana@latest

go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest

echo "Updating Nuclei Templates..."

nuclei -update-templates || true

echo "Done."
