#!/usr/bin/env bash

set -e

sudo apt update

sudo apt install -y \
curl \
wget \
git \
jq \
ripgrep \
fd-find \
parallel \
tmux \
tree \
python3-pip

echo "Core installation completed."
