#!/usr/bin/env bash

set -Eeuo pipefail

echo "Cleaning temporary files..."

rm -rf tmp/*

echo "Cleaning logs older than 30 days..."

find logs -type f -mtime +30 -delete || true

echo "Done."
