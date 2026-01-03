#!/usr/bin/env bash

sudo useradd -r -s /bin/false -U -m -d /usr/share/ollama ollama
sudo usermod -a -G ollama $(whoami)

echo '
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
ExecStart=/usr/bin/ollama serve
User=ollama
Group=ollama
Restart=always
RestartSec=3
Environment="PATH=$PATH"

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/ollama.service
# cp ollama/ollama.service /etc/systemd/system/ollama.service

sudo systemctl daemon-reload
sudo systemctl enable ollama
