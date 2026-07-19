#!/usr/bin/env bash
set -euo pipefail

echo "======================================"
echo "   BugBountyOS Bootstrap Installer"
echo "======================================"

bash install/core.sh
bash install/projectdiscovery.sh
bash install/recon.sh

echo ""
echo "Core installation complete."

echo ""
echo "Next modules will be added gradually:"
echo " - ProjectDiscovery"
echo " - Recon"
echo " - Crawlers"
echo " - JS"
echo " - Secrets"
echo " - Vulnerability Tools"
echo " - BBOT"
echo " - reNgine"
