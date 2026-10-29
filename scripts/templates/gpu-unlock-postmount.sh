#!/usr/bin/env bash
# /usr/local/sbin/gpu-unlock-postmount.sh
# Controlled fail-safe post-mount executor for gpu_unlock.ko
set -euo pipefail

LOG="/var/log/gpu_unlock_postmount.log"
ARM_FILE="/var/lib/gpu_unlock_arm"

exec > "$LOG" 2>&1
echo "=== Boot Timestamp: $(date -Iseconds) ==="

# Check if armed
if [[ ! -f "$ARM_FILE" ]]; then
    echo "Disarmed state detected (ARM file not present)."
    echo "Loading standard unmodified NVIDIA driver stack..."
    modprobe nvidia_drm modeset=1 fbdev=1 || true
    echo "Standard driver loaded. Exiting."
    exit 0
fi

# FAIL-SAFE INVARIANT:
# Delete the arming file and commit filesystem metadata to NVMe BEFORE touching hardware.
# If pcie_flr() freezes the bus, the next boot is guaranteed to find no ARM file.
echo "ARMED RUN DETECTED. Executing immediate disarm and sync..."
rm -f "$ARM_FILE"
sync

echo "Capturing pre-unlock dmesg..."
dmesg > /var/log/dmesg_pre_unlock.log
sync

echo "Attempting modprobe gpu_unlock targets=0000:01:00.0 ..."
set +e
modprobe gpu_unlock targets=0000:01:00.0
RET=$?
set -e

echo "modprobe gpu_unlock returned code: $RET"
dmesg | grep -iE "gpu_unlock|nvrm|pci" >> "$LOG" || true
sync

echo "Initializing display via nvidia-drm..."
modprobe nvidia_drm modeset=1 fbdev=1 || true
sync

echo "Post-mount unlock execution sequence finished."
