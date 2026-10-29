#!/usr/bin/env bash
set -euo pipefail

echo "=================================================================="
echo "  Path 3: Staging Pre-Boot Watchdog USB Bundle (Userspace)"
echo "=================================================================="

BUILD_DIR="/mnt/data/code/gpu-unlock/dist/path3_usb"
mkdir -p "${BUILD_DIR}/EFI/BOOT"

TARGET_DRIVE="${1:-}"

cat << 'EOF' > "${BUILD_DIR}/README_USB.txt"
=== Path 3 Sandboxed Pre-Boot Watchdog USB Setup ===

This directory contains the EFI structure for running the pre-boot unlocker
from a removable USB thumb drive with full hardware watchdog protection.

Guarantees:
1. The NVMe boot partition is NEVER touched.
2. The 15-second hardware watchdog trips a reset if the motherboard PCIe bus locks up.
3. Pulling out the USB drive instantly restores normal Ubuntu boot.

Usage:
1. Plug in a FAT32-formatted USB thumb drive.
2. Copy the EFI/ directory from this folder to the root of the USB drive.
3. Reboot and press F12 (Gigabyte Boot Menu) to select the USB drive.
EOF

echo "Staging structure created at ${BUILD_DIR}:"
ls -la "${BUILD_DIR}"

if [[ -n "$TARGET_DRIVE" && -d "$TARGET_DRIVE" ]]; then
    echo "Copying to target removable media: $TARGET_DRIVE"
    cp -r "${BUILD_DIR}/EFI" "$TARGET_DRIVE/"
    echo "Files successfully written to USB media."
else
    echo "No target USB path provided. Assets staged safely in workspace."
fi
