#!/usr/bin/env bash
set -euo pipefail

# Ensure script is run with root privileges
if [[ $EUID -ne 0 ]]; then
   echo "[ERROR] This script must be run as root (use sudo)."
   exit 1
fi

REPO_DIR="/mnt/data/code/gpu-unlock"
SERVICE_SRC="${REPO_DIR}/scripts/templates/gpu-safe-tuning.service"
SERVICE_DST="/etc/systemd/system/gpu-safe-tuning.service"

echo "=== Installing GPU Safe Silicon Tuning Service ==="

if [[ ! -f "$SERVICE_SRC" ]]; then
    echo "[ERROR] Source service template not found at $SERVICE_SRC"
    exit 1
fi

cp "$SERVICE_SRC" "$SERVICE_DST"
chmod 644 "$SERVICE_DST"

systemctl daemon-reload
systemctl enable gpu-safe-tuning.service

echo "[SUCCESS] gpu-safe-tuning.service installed and enabled."
echo "The safe power (366W), core lock (1800-1950MHz), and memory lock (9751MHz) will apply on boot."
echo "To test immediately: sudo systemctl start gpu-safe-tuning.service"
echo "To disable: sudo systemctl disable --now gpu-safe-tuning.service && sudo ${REPO_DIR}/scripts/reset_safe_tuning.sh"
