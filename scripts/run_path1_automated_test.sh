#!/usr/bin/env bash
set -euo pipefail

echo "=================================================================="
echo "  Path 1: Fully Automated One-Time Reboot Test"
echo "=================================================================="

GRUB_DEFAULT_FILE="/etc/default/grub"
GRUB_BACKUP="/etc/default/grub.bak_path1"
POSTMOUNT_SCRIPT="/usr/local/sbin/gpu-unlock-postmount.sh"

# Invariant: Ensure backup exists
if [ ! -f "$GRUB_BACKUP" ]; then
    echo "[1/4] Creating backup of /etc/default/grub..."
    sudo cp "$GRUB_DEFAULT_FILE" "$GRUB_BACKUP"
else
    echo "[1/4] Preserving existing /etc/default/grub backup..."
fi

# Arm token
echo "[2/4] Arming /var/lib/gpu_unlock_arm..."
sudo touch /var/lib/gpu_unlock_arm
sudo sync

# Configure GRUB for this single test
echo "[3/4] Configuring GRUB kernel arguments..."
EXTRA_ARGS="initcall_blacklist=simpledrm_platform_driver_init video=efifb:off video=vesafb:off pcie_aspm=off modprobe.blacklist=nvidia,nvidia_drm,nvidia_modeset"

# Update GRUB_CMDLINE_LINUX_DEFAULT with test args
sudo sed -i -E "s/quiet splash//g" "$GRUB_DEFAULT_FILE"
if ! grep -q "initcall_blacklist=" "$GRUB_DEFAULT_FILE"; then
    sudo sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 ${EXTRA_ARGS}\"/" "$GRUB_DEFAULT_FILE"
fi
sudo sed -i -E 's/  +/ /g' "$GRUB_DEFAULT_FILE"
sudo update-grub

# Ensure postmount script restores GRUB immediately upon boot
echo "[4/4] Updating /usr/local/sbin/gpu-unlock-postmount.sh with auto-GRUB restore..."
cat << 'EOF_SH' > /mnt/data/code/gpu-unlock/scripts/templates/gpu-unlock-postmount.sh
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
EOF_SH

sudo cp /mnt/data/code/gpu-unlock/scripts/templates/gpu-unlock-postmount.sh /usr/local/sbin/gpu-unlock-postmount.sh
sudo chmod +x /usr/local/sbin/gpu-unlock-postmount.sh

echo "=================================================================="
echo "  AUTOMATED TEST ARMED AND READY!"
echo ""
echo "  Safety Invariants:"
echo "  1. GRUB is configured to automatically restore itself to clean stock on boot."
echo "  2. The ARM file is deleted and synced BEFORE touching the GPU."
echo "  3. No manual GRUB key presses ('e') needed."
echo ""
echo "  To execute: sudo reboot"
echo "=================================================================="
