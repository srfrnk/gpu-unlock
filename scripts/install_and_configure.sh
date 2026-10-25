#!/usr/bin/env bash
set -euo pipefail

echo "=================================================================="
echo "  gpu-unlock: Automated Installation & Dracut Setup Script"
echo "=================================================================="

REPO_DIR="/mnt/data/code/gpu-unlock"
CACHE_ASSETS="/home/shahar/.cache/gpu-unlock/assets"

# 1. Install firmware & DKMS module
echo "[1/6] Installing firmware assets and DKMS module..."
cd "$REPO_DIR"
make install-firmware ASSETS="$CACHE_ASSETS"
make install-dkms

# 2. Register, build, and install DKMS module
echo "[2/6] Registering and building DKMS module..."
dkms remove gpu-unlock/1.0.0 --all 2>/dev/null || true
dkms add gpu-unlock/1.0.0
dkms build gpu-unlock/1.0.0
dkms install gpu-unlock/1.0.0

# 3. Configure Dracut with the exact recursive firmware path
echo "[3/6] Configuring Dracut drop-in with recursive firmware path..."
mkdir -p /etc/dracut.conf.d
cat << 'EOF' > /etc/dracut.conf.d/gpu-unlock.conf
force_drivers+=" gpu_unlock "
install_items+=" /usr/lib/firmware/gpu-unlock/610.43.03/* "
EOF

# 4. Mask system sleep targets (prevents post-suspend hang)
echo "[4/6] Masking system sleep targets..."
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# 5. Add kernel parameters to /etc/default/grub (if not already present)
echo "[5/6] Configuring kernel command line in /etc/default/grub..."
if ! grep -q "gpu_unlock.targets=" /etc/default/grub; then
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 gpu_unlock.targets=0000:01:00.0 nvidia-drm.modeset=1"/' /etc/default/grub
fi

# 6. Rebuild initramfs with dracut and update GRUB
echo "[6/6] Generating initramfs with dracut and updating GRUB..."
dracut -f
if command -v update-grub &>/dev/null; then
    update-grub
elif command -v grub-mkconfig &>/dev/null; then
    grub-mkconfig -o /boot/grub/grub.cfg
fi

echo "=================================================================="
echo "  Verifying initramfs payload:"
echo "=================================================================="
lsinitrd /boot/initrd.img-$(uname -r) | grep -E "booter_load_ga102|gpu_unlock\.ko" || {
    echo "ERROR: Failed to find expected firmware or module in initramfs!"
    exit 1
}

echo "=================================================================="
echo "  Installation and initramfs generation SUCCESSFUL!"
echo "  Next step: run 'sudo poweroff', wait 10 seconds, then power on."
echo "=================================================================="
