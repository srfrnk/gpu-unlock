#!/bin/bash
set -e

# ==============================================================================
# GPU Unlock Persistent Deployment Script for Ubuntu
# Tested on: Ubuntu 24.04+ (Kernel 7.0+), Intel B460 + RTX 3090 (GA102)
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo ./install_persistent_unlock.sh)"
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KVER="$(uname -r)"
BOOT_UUID=$(findmnt -n -o UUID /boot 2>/dev/null || findmnt -n -o UUID /)
ROOT_UUID=$(findmnt -n -o UUID /)

echo "==> Deploying GPU Unlock from: $REPO_DIR"
echo "==> Target Kernel: $KVER"

# 1. Ensure firmware assets exist (check /lib/firmware, cache, or run make assets)
FIRMWARE_DIR="/lib/firmware/gpu-unlock/610.43.03"
mkdir -p "$FIRMWARE_DIR"

if [ -f "$FIRMWARE_DIR/booter_load_ga102.bin" ]; then
    echo "==> [1/4] Firmware assets already present in $FIRMWARE_DIR"
elif [ -d "$HOME/.cache/gpu-unlock/assets" ] && [ -f "$HOME/.cache/gpu-unlock/assets/booter_load_ga102.bin" ]; then
    cp -v "$HOME/.cache/gpu-unlock/assets/"*.bin "$FIRMWARE_DIR/"
    echo "==> [1/4] Firmware assets copied from cache to $FIRMWARE_DIR"
elif [ -d "/home/shahar/.cache/gpu-unlock/assets" ] && [ -f "/home/shahar/.cache/gpu-unlock/assets/booter_load_ga102.bin" ]; then
    cp -v "/home/shahar/.cache/gpu-unlock/assets/"*.bin "$FIRMWARE_DIR/"
    echo "==> [1/4] Firmware assets copied from user cache to $FIRMWARE_DIR"
else
    echo "==> [1/4] Generating firmware assets via make assets..."
    make -C "$REPO_DIR" assets
    cp -v "$HOME/.cache/gpu-unlock/assets/"*.bin "$FIRMWARE_DIR/"
fi

# 2. Build and install kernel module
SRC="$REPO_DIR/kernel/gpu_unlock"
MOD_DIR="/lib/modules/${KVER}/extra"
mkdir -p "$MOD_DIR"
make -C "$SRC" clean 2>/dev/null || true
make -C "$SRC" -j$(nproc)
cp -v "$SRC/gpu_unlock.ko" "$MOD_DIR/gpu_unlock.ko"
depmod -a "$KVER"
echo "==> [2/4] Kernel module compiled and installed for $KVER"

# 3. Create persistent kernel update hook (/etc/kernel/postinst.d/zz-gpu-unlock)
cat << 'HOOK' > /etc/kernel/postinst.d/zz-gpu-unlock
#!/bin/bash
# Automatically builds gpu_unlock.ko and initramfs on kernel updates & OS upgrades
set -e

KVER="$1"
[ -z "$KVER" ] && KVER=$(uname -r)
REPO_DIR="/mnt/data/code/gpu-unlock"
SRC="${REPO_DIR}/kernel/gpu_unlock"
MOD_DIR="/lib/modules/${KVER}/extra"
MOD_FILE="${MOD_DIR}/gpu_unlock.ko"
INITRD_OUT="/boot/initrd.img-${KVER}-gpuunlock"
FIRMWARE_DIR="/lib/firmware/gpu-unlock/610.43.03"

if [ -d "/lib/modules/${KVER}/build" ] && [ -d "$SRC" ]; then
    make -C "$SRC" KDIR="/lib/modules/${KVER}/build" clean 2>/dev/null || true
    make -C "$SRC" KDIR="/lib/modules/${KVER}/build" -j$(nproc)
    mkdir -p "$MOD_DIR"
    cp -v "${SRC}/gpu_unlock.ko" "$MOD_FILE"
    depmod -a "$KVER"
fi

DROPIN="/etc/dracut.conf.d/00-gpu-unlock-temp.conf"
cat << DROP > "$DROPIN"
install_items+=" ${MOD_FILE} ${FIRMWARE_DIR}/* "
force_drivers+=" gpu_unlock "
DROP

dracut --force --kver "$KVER" "$INITRD_OUT"
rm -f "$DROPIN"
HOOK
chmod +x /etc/kernel/postinst.d/zz-gpu-unlock
echo "==> [3/4] Kernel post-install hook installed at /etc/kernel/postinst.d/zz-gpu-unlock"

# 4. Generate unlocked initramfs for current kernel
/etc/kernel/postinst.d/zz-gpu-unlock "$KVER"

# 5. Configure GRUB menu (Ubuntu default = Unlocked, second = Safe Stock)
cat << 'GRUB_CFG' > /etc/grub.d/09_gpu_unlock
#!/bin/sh
exec tail -n +3 $0
# Dynamic GPU Unlock Boot Generator
LATEST_VMLINUZ=$(ls -1 /boot/vmlinuz-* 2>/dev/null | grep -v 'rescue' | sort -V | tail -n 1)
LATEST_KVER=$(basename "$LATEST_VMLINUZ" | sed 's/vmlinuz-//')
BOOT_UUID=$(findmnt -n -o UUID /boot 2>/dev/null || findmnt -n -o UUID /)
ROOT_UUID=$(findmnt -n -o UUID /)

if [ -f "/boot/initrd.img-${LATEST_KVER}-gpuunlock" ]; then
    UNLOCKED_INITRD="/initrd.img-${LATEST_KVER}-gpuunlock"
else
    UNLOCKED_INITRD="/initrd.img-${LATEST_KVER}"
fi

menuentry 'Ubuntu' --class ubuntu --class gnu-linux --class gnu --class os $menuentry_id_option 'gnulinux-simple-unlocked' {
	recordfail
	load_video
	insmod gzio
	insmod part_gpt
	insmod ext2
	search --no-floppy --fs-uuid --set=root ${BOOT_UUID}
	linux	/vmlinuz-${LATEST_KVER} root=UUID=${ROOT_UUID} ro quiet splash rootdelay=10 pcie_port_pm=off pcie_aspm.policy=performance pci=noaer,realloc pcie_aspm=off gpu_unlock.targets=0000:01:00.0
	initrd	${UNLOCKED_INITRD}
}

menuentry 'Ubuntu Safe No GPU Unlock' --class ubuntu --class gnu-linux --class gnu --class os $menuentry_id_option 'gnulinux-simple-stock-safe' {
	recordfail
	load_video
	insmod gzio
	insmod part_gpt
	insmod ext2
	search --no-floppy --fs-uuid --set=root ${BOOT_UUID}
	linux	/vmlinuz-${LATEST_KVER} root=UUID=${ROOT_UUID} ro quiet splash rootdelay=10 pcie_port_pm=off pcie_aspm.policy=performance
	initrd	/initrd.img-${LATEST_KVER}
}
GRUB_CFG
chmod +x /etc/grub.d/09_gpu_unlock

# Ensure 40_custom is clean
cat << 'EMPTY' > /etc/grub.d/40_custom
#!/bin/sh
exec tail -n +3 $0
EMPTY
chmod +x /etc/grub.d/40_custom

update-grub
echo "==> [4/4] GRUB menu updated! [0] Ubuntu (Unlocked), [1] Ubuntu Safe No GPU Unlock"
echo "==> [SUCCESS] GPU Unlock installation is 100% active and update-proof!"
