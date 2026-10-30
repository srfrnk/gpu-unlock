#!/usr/bin/env bash
set -euo pipefail

echo "=================================================================="
echo "  Path 3: Building Custom Pre-Boot Unlocker & Staging USB Bundle"
echo "=================================================================="

REPO_DIR="/mnt/data/code/gpu-unlock"
BUILDER_DIR="${REPO_DIR}/uefi_builder"
DIST_DIR="${REPO_DIR}/dist/path3_usb"
TARGET_DRIVE="${1:-}"

# 1. Compile custom UEFI binary
echo "[*] Compiling custom UEFI application (BOOTX64.EFI)..."
make -C "${BUILDER_DIR}" clean
make -C "${BUILDER_DIR}"

# 2. Stage EFI directory structure in dist
echo "[*] Staging EFI files in ${DIST_DIR}..."
mkdir -p "${DIST_DIR}/EFI/BOOT"
cp "${BUILDER_DIR}/BOOTX64.EFI" "${DIST_DIR}/EFI/BOOT/BOOTX64.EFI"

cat << 'EOF' > "${DIST_DIR}/EFI/BOOT/startup.nsh"
@echo -off
cls
echo "Starting Custom Hardware-Guarded GPU Pre-Boot Check..."
BOOTX64.EFI
EOF

cat << 'EOF' > "${DIST_DIR}/README_USB.txt"
=== Path 3 Sandboxed Pre-Boot Watchdog USB Setup ===

This directory contains the EFI structure for running the pre-boot unlocker
from a removable USB thumb drive with full hardware watchdog protection.

Guarantees:
1. The NVMe boot partition is NEVER touched.
2. The 15-second hardware watchdog trips a reset if the motherboard PCIe bus locks up.
3. Pulling out the USB drive instantly restores normal Ubuntu boot.

Usage:
1. Plug in a FAT32-formatted USB thumb drive.
2. Copy the contents of this folder (or run: sudo ./scripts/build_path3_usb_bundle.sh /media/$USER/GPU_UNLOCK)
3. Reboot and press F12 (Gigabyte Boot Menu) to select the USB drive.
EOF

echo "[+] UEFI executable built and staged successfully:"
ls -lh "${DIST_DIR}/EFI/BOOT/"

# 3. Copy to external USB drive if path is provided
if [[ -n "$TARGET_DRIVE" ]]; then
    if [[ -d "$TARGET_DRIVE" ]]; then
        echo "[*] Copying bundle to target removable USB drive: $TARGET_DRIVE"
        cp -r "${DIST_DIR}/EFI" "$TARGET_DRIVE/"
        cp "${DIST_DIR}/README_USB.txt" "$TARGET_DRIVE/"
        sync
        echo "[SUCCESS] USB Drive successfully written and synced."
    else
        echo "[WARN] Target path $TARGET_DRIVE does not exist or is not a mounted directory."
    fi
else
    echo "[INFO] No target USB mount path provided. Bundle is safely staged at ${DIST_DIR}"
fi
