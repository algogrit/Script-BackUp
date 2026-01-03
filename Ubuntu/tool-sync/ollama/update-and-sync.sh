#!/usr/bin/env bash

SYNC_DIR="ollama"

echo "\033[1;31mUpdating ollama...\033[0m"
curl -fsSL https://ollama.com/install.sh | sh

mkdir -p $SYNC_DIR
cp /etc/systemd/system/ollama.service $SYNC_DIR/
