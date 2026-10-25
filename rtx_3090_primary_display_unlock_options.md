# RTX 3090 Primary GPU Unlock: Complete Options Guide

## Why the Standard `initramfs` Method Froze Your PC

When the RTX 3090 is the sole primary display adapter, the motherboard's UEFI GOP (Graphics Output Protocol) initializes the video output pipe on Root Port `00:01.0` at power-on, and the Linux kernel immediately maps `BAR1` via `simpledrm`/`efifb` to draw the boot console. 

When `gpu_unlock` triggers a PCIe Function-Level Reset (`pcie_flr()`) inside `initramfs`:
1. It tears down the active PCIe link while the motherboard root port and framebuffer driver are mid-transaction.
2. This causes an immediate hardware PCIe bus lockup.
3. Because `initramfs` runs in RAM before your NVMe root partition (`/`) is mounted, the crash happens before `systemd-journald` can write a single line to disk.

---

## Comparison of All Viable Options

| Option | Requires iGPU? | Requires SSH? | Survives Driver Updates? | Complexity | Risk of Boot Loop |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **1. BIOS `IGFX` Boot Hand-off** *(Monitor stays on 3090)* | Yes (non-`F` CPU) | No | Yes | Low | Very Low |
| **2. Post-Mount Self-Disarming Service** *(Block `simpledrm`/`efifb`)* | No | No | Yes | Medium | Zero *(Auto-disarms)* |
| **3. Patched `nvidia-open` Driver** *(In-driver unlock)* | No | No | No *(Re-patch on update)* | Medium-High | Low |
| **4. Secondary Cheap Display GPU** *(Hardware isolation)* | No | No | Yes | Low | Very Low |
| **5. Pre-OS UEFI `.efi` Unlocker** *(Pre-bootloader)* | No | No | Yes | High | Medium |

---

## Option 1: BIOS `IGFX` Boot Hand-Off (Best if Your CPU Has Integrated Graphics)

If your Intel/AMD CPU includes integrated graphics (e.g., Intel Core i7/i9 non-`F` series or Ryzen 7000/9000 series), you can route the early 4-second BIOS/POST video to the CPU's iGPU while **leaving your monitor plugged directly into the RTX 3090**.

### How It Works
1. During POST and `initramfs`, the motherboard binds UEFI GOP to the iGPU.
2. The RTX 3090 boots completely headless (`WPR2 = 0`, no active `BAR1` scanout).
3. `gpu_unlock` runs `pcie_flr()` cleanly without colliding with the PCIe root port.
4. Seconds later, `nvidia-drm` (`modeset=1`) loads, detects your monitor plugged into the RTX 3090, and renders your Ubuntu login screen and desktop directly on the RTX 3090 at full speed.

### Setup Steps
1. Reboot into your motherboard UEFI/BIOS settings.
2. Locate **Primary Display** / **Initial Display Output** (usually under *System Agent (SA) Configuration -> Graphics Configuration* or *Advanced -> PCI Subsystem*).
3. Change it from `PEG` / `PCIe` to **`IGFX`** / **`CPU Graphics`**, and enable **iGPU Multi-Monitor**.
4. Leave your DisplayPort/HDMI cable plugged into the RTX 3090. *(Optional: connect a second cable from the motherboard HDMI port to a secondary input on your monitor in case you want to see the GRUB menu without switching BIOS settings).*
5. Enable `gpu-unlock` using the standard configuration (`gpu_unlock.targets=0000:01:00.0`).

---

## Option 2: Post-Mount Self-Disarming Systemd Service (Best if You Have No iGPU and No SSH)

If your CPU has no integrated graphics (e.g., Intel `-F`/`-KF` or Threadripper/Xeon) and you do not have a second machine for SSH, you can move `gpu_unlock` **out of `initramfs`** and into a post-mount systemd service while forbidding the Linux kernel from touching the GPU's framebuffer during boot.

### How It Works
* **Prevent `BAR1` Contention:** Kernel parameters (`initcall_blacklist=simpledrm_platform_driver_init video=efifb:off pcie_aspm=off`) stop Linux from binding to the UEFI GOP framebuffer during early boot.
* **Delay Driver Load Until Disk Mounts:** `modprobe.blacklist=nvidia,nvidia_drm,nvidia_modeset` keeps `udev` from loading `nvidia.ko` until your root filesystem (`/`) is mounted read-write.
* **Auto-Disarming Fail-Safe (No SSH Needed):** The service checks for `/var/lib/gpu_unlock_arm`. If present, it **deletes the file and flushes the disk (`sync`) before running `gpu_unlock`**. 
  * If `gpu_unlock` succeeds, it immediately loads `nvidia-drm` and starts your desktop.
  * If `pcie_flr()` still freezes the motherboard bus, you simply press the PC's reset/power button once—on the next boot, `/var/lib/gpu_unlock_arm` is already gone, so the PC boots normally into your desktop and saves the diagnostic log at `/var/log/gpu_unlock_postmount.log`.

### Setup Steps

#### Step 1: Ensure `gpu_unlock` Is Not in `initramfs`
Make sure `/etc/dracut.conf.d/gpu-unlock.conf` is removed and rebuild `initramfs` (`sudo dracut -f` or `sudo update-initramfs -u`), while keeping `gpu_unlock.ko` installed in `/lib/modules/$(uname -r)/kernel/drivers/gpu/drm/` and firmware in `/usr/lib/firmware/gpu-unlock/610.43.03/`.

#### Step 2: Create the Self-Disarming Service
Run the following script as root to install the post-mount service:

```bash
#!/usr/bin/env bash
set -euo pipefail

cat << 'EOF' > /usr/local/sbin/gpu-unlock-postmount.sh
#!/usr/bin/env bash
LOG="/var/log/gpu_unlock_postmount.log"
ARM_FILE="/var/lib/gpu_unlock_arm"

exec > "$LOG" 2>&1
echo "=== Boot timestamp: $(date) ==="

if [[ ! -f "$ARM_FILE" ]]; then
    echo "Disarmed state detected. Loading stock NVIDIA driver stack."
    modprobe nvidia_drm modeset=1 fbdev=1 || true
    exit 0
fi

# Disarm immediately and flush to NVMe BEFORE touching the GPU
rm -f "$ARM_FILE"
sync

echo "Armed run: saving pre-unlock dmesg and loading gpu_unlock..."
dmesg > /var/log/dmesg_pre_unlock.log
sync

modprobe gpu_unlock targets=all
RET=$?

echo "modprobe gpu_unlock exited with code: $RET"
dmesg | grep -iE "gpu_unlock|nvrm|pci" >> "$LOG" || true
sync

echo "Loading nvidia-drm to turn on display..."
modprobe nvidia_drm modeset=1 fbdev=1
sync
EOF

chmod +x /usr/local/sbin/gpu-unlock-postmount.sh

cat << 'EOF' > /etc/systemd/system/gpu-unlock-postmount.service
[Unit]
Description=Fail-Safe Post-Mount GPU Unlock
DefaultDependencies=no
After=local-fs.target systemd-modules-load.service systemd-journald.service
Before=display-manager.service gdm.service plymouth-quit.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/gpu-unlock-postmount.sh
RemainAfterExit=yes

[Install]
WantedBy=sysinit.target
EOF

systemctl daemon-reload
systemctl enable gpu-unlock-postmount.service
```

#### Step 3: Arm and Test Safely via One-Time GRUB Edit
1. Arm the service for a single boot:
   ```bash
   sudo touch /var/lib/gpu_unlock_arm && sudo sync
   ```
2. Reboot and press **`e`** at the GRUB menu (this edits the boot arguments for **one boot only**).
3. On the `linux` line, remove `quiet splash` and append:
   ```text
   initcall_blacklist=simpledrm_platform_driver_init video=efifb:off video=vesafb:off pcie_aspm=off modprobe.blacklist=nvidia,nvidia_drm,nvidia_modeset
   ```
4. Press **`Ctrl + X`** or **`F10`** to boot.
   * **If your login screen appears:** Open a terminal and check `sudo dmesg | grep gpu_unlock`. If it shows `unlocked`, you can remove the `rm -f "$ARM_FILE"` line to make it permanent.
   * **If the screen stays black for more than 20 seconds:** Power-cycle the PC. Both the temporary GRUB edit and the `/var/lib/gpu_unlock_arm` file will be gone, booting you straight back to your normal desktop where you can read `/var/log/gpu_unlock_postmount.log`.

---

## Option 3: Patched `nvidia-open` Kernel Modules (In-Driver Unlock)

Instead of loading a separate pre-driver module that forces a disruptive `pcie_flr()` before `nvidia.ko` loads, you can use NVIDIA's official open-source kernel modules (`NVIDIA/open-gpu-kernel-modules`) patched with the V67 PLM unlock sequence.

### How It Works
* The unlock sequence is compiled directly into `nvidia.ko`'s GSP initialization routine (`kernel_gsp.c` / `sec2`).
* Because the NVIDIA driver itself manages the transition while initializing the card's display engine, it does not fight with `initramfs` or crash the PCIe root port.

### Trade-Offs
* **Pros:** Works cleanly on single-GPU primary display systems without BIOS hacks or FLR bus freezes.
* **Cons:** Requires pinning your NVIDIA driver version (e.g., `610.43.03` or `570.x`/`575.x` depending on patch target) and rebuilding the kernel module whenever your kernel or driver updates.

---

## Option 4: Secondary Low-Profile Display Adapter

If your CPU lacks integrated graphics and your motherboard's PCIe root port strictly refuses any FLR on the boot display device:

### How It Works
1. Install a cheap, low-power secondary PCIe card (such as an NVIDIA GT 710/1030 or AMD RX 6400) in a secondary PCIe slot, or use an M.2-to-PCIe display adapter.
2. Set the secondary slot as the initial boot display in BIOS.
3. Configure `gpu_unlock` to target **only** the RTX 3090's PCIe address:
   ```text
   gpu_unlock.targets=0000:01:00.0
   ```
4. Keep your primary monitor plugged into the RTX 3090 (or use PRIME render offload). Once Ubuntu boots, Xorg/Wayland uses the unlocked RTX 3090 for your desktop and all CUDA/LLM workloads.

---

## Option 5: Pre-OS UEFI `.efi` Application

Before `gpu-unlock` was ported to a Linux kernel module, the original pre-driver method ran as a standalone UEFI `.efi` binary launched from the EFI System Partition (via `rEFInd`, `systemd-boot`, or the UEFI Shell) before GRUB loads Linux.

### Trade-Offs
* **Pros:** Runs before the Linux kernel ever initializes PCIe root port state or `simpledrm`.
* **Cons:** Requires Secure Boot to be disabled, and existing community `.efi` binaries often hardcode BAR0/VBIOS offsets that require manual hex adjustment for specific RTX 3090 board partners.

---

## Summary Decision Tree

```
Does your CPU have built-in Integrated Graphics (iGPU)?
 ├── YES ──► Use Option 1 (Set BIOS Initial Display to IGFX, keep monitor on RTX 3090).
 │           Cleanest, zero-maintenance hardware fix.
 │
 └── NO ───► Try Option 2 (Post-Mount Self-Disarming Service + blacklist simpledrm/efifb).
              ├── Succeeds? ──► Keep it enabled; zero hardware cost.
              └── Still hangs Root Port 00:01.0?
                   ├── Want zero hardware changes? ──► Use Option 3 (Patched nvidia-open driver).
                   └── Want stock unpatched drivers? ──► Use Option 4 (Cheap secondary display card).
```