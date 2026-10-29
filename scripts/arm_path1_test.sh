#!/usr/bin/env bash
set -euo pipefail

ARM_FILE="/var/lib/gpu_unlock_arm"

echo "=================================================================="
echo "  Arming Path 1 Fail-Safe Test (One-Time Execution)"
echo "=================================================================="

sudo touch "$ARM_FILE"
sudo sync

echo "ARM token created at $ARM_FILE"
echo ""
echo "INSTRUCTIONS FOR TESTING:"
echo "1. Reboot the PC: sudo reboot"
echo "2. At the GRUB boot menu, highlight Ubuntu and press 'e' to edit."
echo "3. Locate the 'linux' line, remove 'quiet splash', and append the following:"
echo ""
echo "   initcall_blacklist=simpledrm_platform_driver_init video=efifb:off video=vesafb:off pcie_aspm=off modprobe.blacklist=nvidia,nvidia_drm,nvidia_modeset"
echo ""
echo "4. Press Ctrl+X or F10 to boot."
echo "=================================================================="
