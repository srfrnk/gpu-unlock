#!/usr/bin/env bash
set -euo pipefail

echo "=================================================================="
echo "  Deploying Path 1 Fail-Safe Post-Mount Service & Kernel Assets"
echo "=================================================================="

TEMPLATE_DIR="/mnt/data/code/gpu-unlock/scripts/templates"
MODULE_SRC="/mnt/data/code/gpu-unlock/kernel/gpu_unlock/gpu_unlock.ko"
KVER="$(uname -r)"
TARGET_MOD_DIR="/lib/modules/${KVER}/kernel/drivers/gpu/drm"
FIRMWARE_SRC="/home/shahar/.cache/gpu-unlock/assets"
TARGET_FW_DIR="/usr/lib/firmware/gpu-unlock/610.43.03"

# 1. Install kernel module binary (without initramfs inclusion)
echo "[1/5] Installing gpu_unlock.ko to ${TARGET_MOD_DIR}..."
sudo mkdir -p "$TARGET_MOD_DIR"
sudo cp "$MODULE_SRC" "${TARGET_MOD_DIR}/gpu_unlock.ko"
sudo depmod -a "$KVER"

# 2. Install firmware assets to system firmware path
echo "[2/5] Installing firmware assets to ${TARGET_FW_DIR}..."
sudo mkdir -p "$TARGET_FW_DIR"
sudo cp "${FIRMWARE_SRC}/booter_load_ga102.bin" "${TARGET_FW_DIR}/"
sudo cp "${FIRMWARE_SRC}/gsp_boot_desc_ga102.bin" "${TARGET_FW_DIR}/"
sudo cp "${FIRMWARE_SRC}/gsp_boot_ga102.bin" "${TARGET_FW_DIR}/"
sudo cp "${FIRMWARE_SRC}/gsp_ga10x.bin" "${TARGET_FW_DIR}/"
sudo cp "${FIRMWARE_SRC}/v67-ga102-610.43.03.bin" "${TARGET_FW_DIR}/"

# 3. Install executor script
echo "[3/5] Installing /usr/local/sbin/gpu-unlock-postmount.sh..."
sudo cp "${TEMPLATE_DIR}/gpu-unlock-postmount.sh" /usr/local/sbin/gpu-unlock-postmount.sh
sudo chmod +x /usr/local/sbin/gpu-unlock-postmount.sh

# 4. Install systemd unit
echo "[4/5] Installing /etc/systemd/system/gpu-unlock-postmount.service..."
sudo cp "${TEMPLATE_DIR}/gpu-unlock-postmount.service" /etc/systemd/system/gpu-unlock-postmount.service

# 5. Reload systemd daemon and enable unit
echo "[5/5] Enabling gpu-unlock-postmount.service..."
sudo systemctl daemon-reload
sudo systemctl enable gpu-unlock-postmount.service

echo "==> Path 1 assets & service deployed in DISARMED state. System remains 100% normal."
