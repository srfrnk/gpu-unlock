#!/usr/bin/env bash
set -euo pipefail

echo "=================================================================="
echo "  gpu-unlock: Emergency Reversal & System Restoration Script"
echo "=================================================================="

KVER="$(uname -r)"

# 1. Restore GRUB configuration and parameters
if [ -f /etc/default/grub ]; then
    echo "[1/7] Cleaning gpu_unlock parameters and restoring quiet splash in /etc/default/grub..."
    sed -i -E 's/gpu_unlock\.[a-zA-Z0-9_]+=[^ "]+//g' /etc/default/grub
    sed -i -E 's/nvidia-drm\.modeset=[0-1]//g' /etc/default/grub
    sed -i -E 's/nomodeset//g' /etc/default/grub
    sed -i -E 's/plymouth\.enable=0//g' /etc/default/grub
    # Ensure quiet splash is restored if missing
    if ! grep -q "quiet splash" /etc/default/grub; then
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash /' /etc/default/grub
    fi
    sed -i -E 's/  +/ /g' /etc/default/grub
    if command -v update-grub &>/dev/null; then
        update-grub
    elif command -v grub-mkconfig &>/dev/null; then
        grub-mkconfig -o /boot/grub/grub.cfg
    fi
fi

# 2. Remove module from in-tree kernel paths and DKMS
echo "[2/7] Removing module from kernel tree and DKMS..."
rm -f "/lib/modules/${KVER}/kernel/drivers/gpu/drm/gpu_unlock.ko"
rm -f "/lib/modules/${KVER}/kernel/drivers/gpu/drm/gpu_unlock.ko.zst"
rm -f "/lib/modules/${KVER}/updates/dkms/gpu_unlock.ko"
rm -f "/lib/modules/${KVER}/updates/dkms/gpu_unlock.ko.zst"

if command -v dkms &>/dev/null; then
    dkms remove gpu-unlock/1.0.0 --all 2>/dev/null || true
fi

# 3. Clean drop-ins from all initramfs configurations
echo "[3/7] Cleaning dracut and initramfs drop-in configuration files..."
rm -f /etc/dracut.conf.d/gpu-unlock.conf
rm -f /usr/lib/dracut/dracut.conf.d/gpu-unlock.conf
rm -f /etc/initramfs-tools/conf.d/gpu-unlock.conf
rm -f /usr/share/initramfs-tools/modules.d/gpu-unlock.conf
rm -f /etc/mkinitcpio.conf.d/gpu-unlock.conf
rm -f /etc/mkinitcpio.conf.d/zz-gpu-unlock.conf
rm -rf /usr/lib/firmware/gpu-unlock
rm -rf /usr/src/gpu-unlock-1.0.0

# 4. Refresh modules.dep
echo "[4/7] Updating depmod..."
depmod -a "$KVER"

# 5. Unmask sleep targets
echo "[5/7] Unmasking system sleep targets..."
systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target 2>/dev/null || true

# 6. Rebuild initramfs with dracut
echo "[6/7] Rebuilding initramfs..."
if command -v dracut &>/dev/null; then
    dracut -f
elif command -v update-initramfs &>/dev/null; then
    update-initramfs -u
elif command -v mkinitcpio &>/dev/null; then
    mkinitcpio -P
fi

# 7. Final GRUB verification
echo "[7/7] Verifying GRUB configuration..."
if command -v update-grub &>/dev/null; then
    update-grub
fi

echo "=================================================================="
echo "  gpu-unlock reversal complete! System restored to factory state."
echo "=================================================================="
