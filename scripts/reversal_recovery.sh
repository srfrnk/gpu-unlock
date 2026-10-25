#!/usr/bin/env bash
set -euo pipefail

echo "=================================================================="
echo "  gpu-unlock: Emergency Reversal & System Restoration Script"
echo "=================================================================="

# 1. Remove kernel parameters from GRUB
if [ -f /etc/default/grub ]; then
    echo "[1/5] Removing gpu_unlock parameters from /etc/default/grub..."
    sed -i -E 's/gpu_unlock\.[a-zA-Z0-9_]+=[^ "]+//g' /etc/default/grub
    # Clean up double spaces that might remain
    sed -i -E 's/  +/ /g' /etc/default/grub
    if command -v update-grub &>/dev/null; then
        update-grub
    elif command -v grub-mkconfig &>/dev/null; then
        grub-mkconfig -o /boot/grub/grub.cfg
    fi
fi

# 2. Purge DKMS module and firmware files
echo "[2/5] Purging DKMS module and packages..."
if command -v dkms &>/dev/null; then
    dkms remove gpu-unlock/1.0.0 --all 2>/dev/null || true
fi

if command -v apt-get &>/dev/null; then
    apt-get purge -y gpu-unlock-dkms gpu-unlock-firmware 2>/dev/null || true
elif command -v pacman &>/dev/null; then
    pacman -Rns --noconfirm gpu-unlock 2>/dev/null || true
elif command -v dnf &>/dev/null; then
    dnf remove -y gpu-unlock-dkms gpu-unlock-firmware 2>/dev/null || true
fi

# 3. Clean drop-ins from initramfs configurations
echo "[3/5] Cleaning initramfs drop-in configuration files..."
rm -f /etc/dracut.conf.d/gpu-unlock.conf
rm -f /etc/initramfs-tools/conf.d/gpu-unlock.conf
rm -f /etc/mkinitcpio.conf.d/gpu-unlock.conf
rm -rf /usr/lib/firmware/gpu-unlock
rm -rf /usr/src/gpu-unlock-1.0.0

# 4. Unmask sleep targets
echo "[4/5] Unmasking system sleep targets..."
systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target 2>/dev/null || true

# 5. Rebuild initramfs to ensure module is completely evicted
echo "[5/5] Rebuilding initramfs..."
if command -v update-initramfs &>/dev/null; then
    update-initramfs -u
elif command -v dracut &>/dev/null; then
    dracut -f
elif command -v mkinitcpio &>/dev/null; then
    mkinitcpio -P
fi

echo "=================================================================="
echo "  gpu-unlock reversal complete! Please reboot the host."
echo "=================================================================="
