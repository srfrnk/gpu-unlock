#!/usr/bin/env bash
set -euo pipefail

LOG="/var/log/gpu_unlock_postmount.log"
ARM_FILE="/var/lib/gpu_unlock_arm"
GRUB_BACKUP="/etc/default/grub.bak_path1"
GRUB_DEFAULT="/etc/default/grub"

exec > "$LOG" 2>&1
echo "=== Boot Timestamp: $(date -Iseconds) ==="

# RESTORE INVARIANT:
# Automatically restore /etc/default/grub immediately on boot so subsequent boots are 100% normal stock.
if [ -f "$GRUB_BACKUP" ]; then
    echo "Restoring clean /etc/default/grub from backup..."
    cp "$GRUB_BACKUP" "$GRUB_DEFAULT"
    update-grub || true
    rm -f "$GRUB_BACKUP"
    sync
fi

# Check if armed
if [[ ! -f "$ARM_FILE" ]]; then
    echo "Disarmed state detected (ARM file not present)."
    echo "Loading standard unmodified NVIDIA driver stack..."
    modprobe nvidia_drm modeset=1 fbdev=1 || true
    exit 0
fi

# FAIL-SAFE INVARIANT:
# Delete the arming file and commit filesystem metadata to NVMe BEFORE touching hardware.
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
