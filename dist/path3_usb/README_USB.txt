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
