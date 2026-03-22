#!/usr/bin/env bash

SYNC_DIR="ollama"

echo "\033[1;31mUpdating ollama (if needed)...\033[0m"

OLLAMA_INSTALLED=$(ollama --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+')
OLLAMA_LATEST=$(curl -s https://api.github.com/repos/ollama/ollama/releases/latest | grep -oP '"tag_name":\s*"v\K[^"]+')

if [ -z "$OLLAMA_INSTALLED" ]; then
  echo "Ollama not found, installing..."
  curl -fsSL https://ollama.com/install.sh | sh
elif [ "$OLLAMA_INSTALLED" = "$OLLAMA_LATEST" ]; then
  echo "Ollama is already up to date (v${OLLAMA_INSTALLED}), skipping."
else
  echo "Updating ollama: v${OLLAMA_INSTALLED} → v${OLLAMA_LATEST}"
  curl -fsSL https://ollama.com/install.sh | sh
fi

mkdir -p $SYNC_DIR
cp /etc/systemd/system/ollama.service $SYNC_DIR/
cp -r /etc/systemd/system/ollama.service.d/ $SYNC_DIR/
