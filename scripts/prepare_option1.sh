#!/usr/bin/env bash
set -euo pipefail

echo "=================================================================="
echo "  Option 1: Installing gpu-unlock for BIOS IGFX Boot Hand-off"
echo "=================================================================="

REPO_DIR="/mnt/data/code/gpu-unlock"
CACHE_ASSETS="/home/shahar/.cache/gpu-unlock/assets"
KVER="$(uname -r)"
TARGET_DIR="/lib/modules/${KVER}/kernel/drivers/gpu/drm"

# 1. Install firmware & DKMS module source
echo "[1/7] Installing firmware assets and DKMS module source..."
cd "$REPO_DIR"
make install-firmware ASSETS="$CACHE_ASSETS"
make install-dkms

# 2. Build DKMS module
echo "[2/7] Building DKMS module..."
dkms remove gpu-unlock/1.0.0 --all 2>/dev/null || true
dkms add gpu-unlock/1.0.0
dkms build gpu-unlock/1.0.0

# 3. Direct Native Kernel Tree Installation (fixes Dracut modprobe FATAL error)
echo "[3/7] Installing directly into primary kernel driver tree..."
mkdir -p "$TARGET_DIR"
if [ -f "/var/lib/dkms/gpu-unlock/1.0.0/${KVER}/x86_64/module/gpu_unlock.ko.zst" ]; then
    zstd -d -f "/var/lib/dkms/gpu-unlock/1.0.0/${KVER}/x86_64/module/gpu_unlock.ko.zst" -o "${TARGET_DIR}/gpu_unlock.ko"
elif [ -f "/var/lib/dkms/gpu-unlock/1.0.0/${KVER}/x86_64/module/gpu_unlock.ko" ]; then
    cp -f "/var/lib/dkms/gpu-unlock/1.0.0/${KVER}/x86_64/module/gpu_unlock.ko" "${TARGET_DIR}/gpu_unlock.ko"
elif [ -f "/var/lib/dkms/gpu-unlock/1.0.0/build/gpu_unlock.ko" ]; then
    cp -f "/var/lib/dkms/gpu-unlock/1.0.0/build/gpu_unlock.ko" "${TARGET_DIR}/gpu_unlock.ko"
fi

# 4. Update host kernel modules.dep
echo "[4/7] Updating host modules.dep..."
depmod -a "$KVER"
modinfo gpu_unlock > /dev/null

# 5. Configure Dracut drop-in
echo "[5/7] Configuring Dracut drop-in..."
mkdir -p /etc/dracut.conf.d
cat << 'EOF_CONF' > /etc/dracut.conf.d/gpu-unlock.conf
force_drivers+=" gpu_unlock "
install_items+=" /usr/lib/firmware/gpu-unlock/610.43.03/* "
EOF_CONF

# 6. Mask system sleep targets (prevents post-suspend hang)
echo "[6/7] Masking system sleep targets..."
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# 7. Configure GRUB for RTX 3090 target + nvidia-drm modesetting
echo "[7/7] Configuring GRUB kernel parameters..."
if ! grep -q "gpu_unlock.targets=" /etc/default/grub; then
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 gpu_unlock.targets=0000:01:00.0 nvidia-drm.modeset=1"/' /etc/default/grub
fi
sed -i -E 's/  +/ /g' /etc/default/grub

echo "Regenerating Dracut initramfs and updating GRUB..."
dracut -f
if command -v update-grub &>/dev/null; then
    update-grub
elif command -v grub-mkconfig &>/dev/null; then
    grub-mkconfig -o /boot/grub/grub.cfg
fi

echo "=================================================================="
echo "  Verifying initramfs payload:"
echo "=================================================================="
lsinitrd /boot/initrd.img-"$KVER" | grep -E "booter_load_ga102|gpu_unlock\.ko" || {
    echo "ERROR: Failed to find expected firmware or module in initramfs!"
    exit 1
}

echo "=================================================================="
echo "  Preparation SUCCESSFUL!"
echo "  Follow instructions to change BIOS setting to IGFX before reboot."
echo "=================================================================="
