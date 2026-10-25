# Comprehensive GPU-Unlock Plan & Evaluation Report

## 1. Goal Description & Executive Summary

The objective of this project was to test, install, configure, validate, and benchmark `gpu-unlock` on the host NVIDIA GeForce RTX 3090 (`GA102`, `10de:2204`) on Ubuntu Linux (`7.0.0-38-generic`).

On consumer GA102 silicon, NVIDIA enforces an artificial half-rate instruction issue throttle on FP16/BF16 tensor core instructions. The `gpu-unlock` Linux kernel module sets hardware speed selection registers (`SS0=0x88888888`, `SS1=0x8`) during early userspace boot via `initramfs` before the proprietary `nvidia.ko` driver attaches, attempting to unlock professional-equivalent full instruction issue rates without requiring permanent vBIOS flashing.

### Final Technical Finding
Following comprehensive testing across three distinct iterations (warm boot, cold boot with recursive firmware inclusion, and cold boot in clean text console mode with Plymouth disabled), **the pre-driver kernel module cannot function on an RTX 3090 when it serves as the sole, primary physical display adapter**:
* When `gpu_unlock` issues a PCIe Function-Level Reset (`pcie_flr`) during early initramfs to apply the speed selection registers, it forcibly tears down the PCIe bus state while the motherboard UEFI GOP (Graphics Output Protocol) firmware and Intel PCIe root port (`00:01.0`) are actively arbitrating the active display pipe.
* This results in an immediate PCIe bus hang / hardware freeze before the Linux kernel can hand off control to `nvidia-drm` or write crash logs to disk.
* **Safe Architecture Requirement**: The `gpu-unlock` Linux kernel module is viable strictly on **headless systems, secondary compute GPUs, or virtualized passthrough (`vfio-pci`) setups**, but is incompatible with single-GPU workstations where the target card is the primary display.
* **Preservation & Reversal**: The emergency recovery script [`scripts/reversal_recovery.sh`](file:///mnt/data/code/gpu-unlock/scripts/reversal_recovery.sh) was battle-tested across all three failed boots, successfully restoring normal system operation with 100% hardware, driver, and filesystem integrity each time.

---

## 2. Invariant Guarantees & Risk Analysis

### Technical Invariants
* **EEPROM / VBIOS Safety Invariant**: The module only reads physical ROM (`NV_PROM_DATA` via `work->bar + 0x300000`). It contains zero SPI flash programming or erase opcodes. The physical card remained completely protected.
* **Volatility Invariant**: Register states are volatile. A power cycle or removing boot arguments completely returns silicon to factory defaults.
* **Explicit Target Guard**: The module remains inactive unless explicitly triggered via `gpu_unlock.targets=`.

### Risk Matrix & Findings

| Risk Domain | Failure Mode | Observed Behavior | Severity | Resolution / Outcome |
| :--- | :--- | :--- | :--- | :--- |
| **Primary Display** | Black screen / PCIe bus hang | Early `pcie_flr` kills the active display pipe before `nvidia-drm` binds. | Critical | Incompatible on single-card primary display setups. |
| **Dracut Modprobe** | Missing driver resolution | DKMS `updates/dkms/` was unindexed by early Dracut pre-udev modprobe. | Resolved | Fixed via direct native kernel tree installation (`kernel/drivers/gpu/drm/`). |
| **Firmware Subdir** | Missing Falcon blobs in initrd | Dracut `install_items` didn't recurse into `610.43.03/`. | Resolved | Fixed via explicit wildcard `install_items+=" /usr/lib/firmware/gpu-unlock/610.43.03/* "`. |
| **System Sleep** | Post-suspend panic | S3 suspend attempts to re-run unlock on a live card. | Mitigated | Masked all systemd sleep targets globally. |
| **Physical HW** | Hardware damage / corruption | None. Card, VBIOS, and drivers remained 100% intact. | None | Verified with `nvidia-smi` post-reversal. |

---

## 3. Emergency Reversal Procedure

The automated recovery script [`scripts/reversal_recovery.sh`](file:///mnt/data/code/gpu-unlock/scripts/reversal_recovery.sh) has been verified and hardened:

```bash
sudo /mnt/data/code/gpu-unlock/scripts/reversal_recovery.sh
```

### Actions Executed on Rollback:
1. **GRUB Cleansing**: Strips `gpu_unlock.*`, `nvidia-drm.modeset`, and `plymouth.enable=0`, and restores standard `quiet splash`.
2. **Native Module & DKMS Purge**: Removes `/lib/modules/$(uname -r)/kernel/drivers/gpu/drm/gpu_unlock.ko*` and uninstalls DKMS module `gpu-unlock/1.0.0`.
3. **Dracut Drop-in Eviction**: Deletes `/etc/dracut.conf.d/gpu-unlock.conf` and `/usr/lib/dracut/dracut.conf.d/gpu-unlock.conf`.
4. **Firmware & Source Purge**: Deletes `/usr/lib/firmware/gpu-unlock` and `/usr/src/gpu-unlock-1.0.0`.
5. **Depmod Refresh**: Runs `depmod -a $(uname -r)` to cleanly restore the kernel module index.
6. **Sleep Target Restoration**: Unmasks all system sleep targets.
7. **Initramfs & GRUB Regeneration**: Re-runs `dracut -f` and `update-grub` to guarantee complete restoration.

---

## 4. Pre-Unlock Baseline Benchmark Results

Recorded under strict environmental invariants (persistence mode enabled, core clock locked to 1700 MHz, uniform power limit 350W):

### Tier 1: Dense GEMM Microbenchmarks (PyTorch CUDA)
Output file: [`benchmarks/baseline_gemm.json`](file:///mnt/data/code/gpu-unlock/benchmarks/baseline_gemm.json)

| Precision | Matrix Shape | Baseline Throughput | Latency | Temp (°C) | Power (W) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **BF16** | 2048x2048x2048 | 60.23 TFLOPS | 0.28 ms | 42.0°C | 62.7W |
| **BF16** | 4096x4096x4096 | 60.44 TFLOPS | 2.27 ms | 43.0°C | 112.7W |
| **BF16** | 8192x8192x8192 | **70.06 TFLOPS** | 15.69 ms | 51.0°C | 173.5W |
| **FP16** | 8192x8192x8192 | **68.55 TFLOPS** | 16.04 ms | 52.0°C | 209.4W |
| **TF32 (FP32)** | 8192x8192x8192 | 34.74 TFLOPS | 31.65 ms | 53.0°C | 270.0W |
| **FP32 (no TF32)** | 8192x8192x8192 | 23.37 TFLOPS | 47.05 ms | 56.0°C | 337.7W |

### Tier 2: Real-World LLM Serving (`qwen3.8:27b-q4_K_M` on Ollama)
Output file: [`benchmarks/baseline_llm.json`](file:///mnt/data/code/gpu-unlock/benchmarks/baseline_llm.json)

| Task Tier | Prompt Length | Ingest / Prefill Speed | Decode Speed | Temp (°C) | Power (W) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Task 1: Code Gen (Short)** | 83 tok | 673.42 tok/s | 41.84 tok/s | 66.0°C | 334.2W |
| **Task 2: Analysis (Medium)** | 390 tok | 3078.99 tok/s | 41.00 tok/s | 69.0°C | 334.3W |
| **Task 3: Needle Extr (Long)** | 12614 tok | 100515.57 tok/s | 39.56 tok/s | 70.0°C | 333.9W |
| **Task 4: Synthesis (Extreme)** | 12998 tok | 99846.37 tok/s | 39.30 tok/s | 71.0°C | 333.6W |

---

## 5. Iterative Test Log & Post-Mortem Chronology

```mermaid
flowchart TD
    A["Attempt 1: Warm Reboot (DKMS default)"] -->|Failure: modprobe FATAL error & blank screen| B["Reversal Script Executed: Clean Boot Restored"]
    B --> C["Attempt 2: Cold Boot + Recursive Firmware Inclusion"]
    C -->|Failure: Display framebuffer lockup during FLR| D["Reversal Script Executed: Clean Boot Restored"]
    D --> E["Attempt 3: Text Console Boot (plymouth.enable=0) + Direct In-Tree Kernel Module"]
    E -->|Failure: Hard PCIe bus freeze during pcie_flr| F["Reversal Script Executed: Clean Boot Restored"]
    F --> G["Final Analysis: Primary Display Incompatibility Documented"]
```

### Detailed Attempt Logs:
1. **Attempt 1 (Warm Reboot)**:
   - Module placed in DKMS default path. System failed to boot.
   - Journal log revealed: `dracut-pre-udev: modprobe: FATAL: Module gpu_unlock not found in directory /lib/modules/7.0.0-38-generic`.
   - Restored via recovery mode using `reversal_recovery.sh`.
2. **Attempt 2 (Cold Power-off Boot + Explicit Firmware Inclusion)**:
   - Fixed firmware path to `/usr/lib/firmware/gpu-unlock/610.43.03/*`. Executed a full 10-second cold shutdown.
   - System froze during early boot with a black screen before the journal filesystem mounted.
   - Restored via recovery mode using `reversal_recovery.sh`.
3. **Attempt 3 (Cold Power-off Boot + Text Console + In-Tree Kernel Module)**:
   - Installed uncompressed module directly into `/lib/modules/$(uname -r)/kernel/drivers/gpu/drm/gpu_unlock.ko`.
   - Disabled Plymouth completely (`plymouth.enable=0`, removed `quiet splash`). Verified payload with `lsinitrd`.
   - Cold reboot froze during early initramfs. Zero journal entries written, confirming a hard PCIe bus controller hang triggered by `pcie_flr()` while the Intel PCIe root port (`00:01.0`) held active UEFI GOP display lines.
   - Restored via recovery mode using `reversal_recovery.sh`.

---

## 6. Project Artifacts & Available Tools

All created benchmark and recovery tools remain intact and functional in the repository:

- [`scripts/reversal_recovery.sh`](file:///mnt/data/code/gpu-unlock/scripts/reversal_recovery.sh) — Emergency reversal script for instant restoration.
- [`scripts/install_and_configure.sh`](file:///mnt/data/code/gpu-unlock/scripts/install_and_configure.sh) — Fully automated deployment script (suitable if a secondary GPU is attached).
- [`scripts/set_benchmark_invariants.sh`](file:///mnt/data/code/gpu-unlock/scripts/set_benchmark_invariants.sh) — Clocks locked to 1700 MHz, persistence mode, 350W power cap.
- [`scripts/reset_benchmark_invariants.sh`](file:///mnt/data/code/gpu-unlock/scripts/reset_benchmark_invariants.sh) — Restores dynamic GPU clocks and power limits.
- [`benchmarks/bench_gemm.py`](file:///mnt/data/code/gpu-unlock/benchmarks/bench_gemm.py) — Standalone PyTorch CUDA GEMM benchmark suite.
- [`benchmarks/bench_llm.py`](file:///mnt/data/code/gpu-unlock/benchmarks/bench_llm.py) — Real-world Ollama LLM serving benchmark suite.
- [`benchmarks/compare_benchmarks.py`](file:///mnt/data/code/gpu-unlock/benchmarks/compare_benchmarks.py) — Automated markdown comparison generator.
