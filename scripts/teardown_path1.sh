#!/usr/bin/env bash
set -euo pipefail

echo "=================================================================="
echo "  Tearing Down Path 1 Service & Restoring Clean State"
echo "=================================================================="

echo "[1/4] Disabling systemd unit..."
sudo systemctl disable gpu-unlock-postmount.service 2>/dev/null || true

echo "[2/4] Removing service and script files..."
sudo rm -f /etc/systemd/system/gpu-unlock-postmount.service
sudo rm -f /usr/local/sbin/gpu-unlock-postmount.sh
sudo rm -f /var/lib/gpu_unlock_arm

echo "[3/4] Reloading systemd..."
sudo systemctl daemon-reload

echo "[4/4] Preserving logs for inspection..."
if [ -f "/var/log/gpu_unlock_postmount.log" ]; then
    echo "Logs remain archived at /var/log/gpu_unlock_postmount.log"
fi

echo "==> Path 1 completely removed from system."
