#!/usr/bin/env bash
set -euo pipefail

echo "=================================================================="
echo "  Deploying Path 1 Fail-Safe Post-Mount Service Files"
echo "=================================================================="

TEMPLATE_DIR="/mnt/data/code/gpu-unlock/scripts/templates"

# 1. Install executor script
echo "[1/3] Installing /usr/local/sbin/gpu-unlock-postmount.sh..."
sudo cp "${TEMPLATE_DIR}/gpu-unlock-postmount.sh" /usr/local/sbin/gpu-unlock-postmount.sh
sudo chmod +x /usr/local/sbin/gpu-unlock-postmount.sh

# 2. Install systemd unit
echo "[2/3] Installing /etc/systemd/system/gpu-unlock-postmount.service..."
sudo cp "${TEMPLATE_DIR}/gpu-unlock-postmount.service" /etc/systemd/system/gpu-unlock-postmount.service

# 3. Reload systemd daemon and enable unit
echo "[3/3] Enabling gpu-unlock-postmount.service..."
sudo systemctl daemon-reload
sudo systemctl enable gpu-unlock-postmount.service

echo "==> Service deployed in DISARMED state. System remains 100% normal."
