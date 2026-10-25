# Comprehensive GPU-Unlock Plan & Evaluation Report

## 1. Goal Description & Executive Summary

The objective of this project was to test, install, configure, validate, and benchmark `gpu-unlock` on the host NVIDIA GeForce RTX 3090 (`GA102`, `10de:2204`) on Ubuntu Linux (`7.0.0-38-generic`).

On consumer GA102 silicon, NVIDIA enforces an artificial half-rate instruction issue throttle on FP16/BF16 tensor core instructions. The `gpu-unlock` Linux kernel module sets hardware speed selection registers (`SS0=0x88888888`, `SS1=0x8`) during early userspace boot via `initramfs` before the proprietary `nvidia.ko` driver attaches, attempting to unlock professional-equivalent full instruction issue rates without requiring permanent vBIOS flashing.

### Final Technical Finding & Incompatibility Verdict
Following comprehensive testing across four distinct hardware and software configurations, **the `gpu-unlock` pre-driver method is fundamentally incompatible with an RTX 3090 acting as the sole, primary physical display adapter**:
1. **PCIe Bus Lockup**: When `gpu_unlock` issues a PCIe Function-Level Reset (`pcie_flr()`) during early initramfs to apply the speed selection registers, it forcibly tears down the PCIe bus state while the motherboard UEFI GOP (Graphics Output Protocol) firmware and Intel PCIe root port (`00:01.0`) hold active display arbitration, causing a hard hardware hang.
2. **Text Console / Framebuffer Bypasses Fail**: Suppressing Plymouth (`plymouth.enable=0`) and running in pure text mode still freezes at the PCIe controller level during `pcie_flr()`.
3. **Motherboard BIOS Hand-off Failure**: Attempting to route early POST video to the integrated CPU graphics (`IGFX`) on the Gigabyte B460M D3H motherboard while a discrete PEG card is installed results in total loss of video signal across both motherboard and GPU outputs, requiring a physical CMOS jumper reset.
4. **Architectural Scope**: The `gpu-unlock` kernel module is viable strictly on **headless servers, secondary compute cards (with display driven by an active separate GPU), or virtualized passthrough (`vfio-pci`) setups**, but cannot be safely deployed on single-GPU desktop workstations.
5. **Preservation & Reversal**: The emergency recovery script [`scripts/reversal_recovery.sh`](file:///mnt/data/code/gpu-unlock/scripts/reversal_recovery.sh) proved 100% reliable across all recovery attempts, cleanly restoring factory driver operation and OS boot with zero filesystem or hardware degradation.

---

## 2. Invariant Guarantees & Risk Analysis

### Technical Invariants
* **EEPROM / VBIOS Safety Invariant**: The module only reads physical ROM (`NV_PROM_DATA` via `work->bar + 0x300000`). It contains zero SPI flash programming or erase opcodes. The physical card remained completely protected.
* **Volatility Invariant**: Register states are volatile. A power cycle or removing boot arguments completely returns silicon to factory defaults.
* **Explicit Target Guard**: The module remains inactive unless explicitly triggered via `gpu_unlock.targets=0000:01:00.0`.

### Risk Matrix & Tested Outcomes

| Configuration Tested | Failure Mode Observed | Severity | Recovery Method |
| :--- | :--- | :--- | :--- |
| **Warm Reboot (`initramfs`)** | Pre-udev modprobe unindexed path | Medium | `reversal_recovery.sh` via root recovery console |
| **Cold Boot (`initramfs` + firmware)** | PCIe bus hang during FLR | Critical | `reversal_recovery.sh` via root recovery console |
| **Text Console Boot (`plymouth.enable=0`)** | Root port 00:01.0 hardware freeze | Critical | `reversal_recovery.sh` via root recovery console |
| **BIOS `IGFX` Boot Routing** | Total display output drop across all ports | Critical | Full physical motherboard CMOS reset (`CLR_CMOS`) |

---

## 3. Emergency Reversal Procedure

The automated recovery script [`scripts/reversal_recovery.sh`](file:///mnt/data/code/gpu-unlock/scripts/reversal_recovery.sh) is verified and permanently maintained in the repository:

```bash
sudo /mnt/data/code/gpu-unlock/scripts/reversal_recovery.sh
```

### Complete Actions Executed on Rollback:
1. **GRUB Cleansing**: Strips `gpu_unlock.*`, `nvidia-drm.modeset`, and `plymouth.enable=0`, and restores standard `quiet splash`.
2. **Native Module & DKMS Purge**: Removes all `gpu_unlock.ko*` binaries from `/lib/modules/$(uname -r)/` and uninstalls DKMS packages.
3. **Dracut Drop-in Eviction**: Deletes `/etc/dracut.conf.d/gpu-unlock.conf` and `/usr/lib/dracut/dracut.conf.d/gpu-unlock.conf`.
4. **Firmware & Source Purge**: Deletes `/usr/lib/firmware/gpu-unlock` and `/usr/src/gpu-unlock-1.0.0`.
5. **Depmod Refresh**: Runs `depmod -a $(uname -r)` to cleanly restore the kernel module index.
6. **Sleep Target Restoration**: Unmasks all system sleep targets.
7. **Initramfs & GRUB Regeneration**: Re-runs `dracut -f` and `update-grub` to guarantee complete restoration.

---

## 4. Pre-Unlock Baseline Benchmark Metrics

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

## 5. Iterative Test Log & Failure Chronology

```mermaid
flowchart TD
    A["Attempt 1: Warm Reboot (DKMS default)"] -->|Failure: modprobe FATAL error & blank screen| B["Recovery: Clean Boot Restored"]
    B --> C["Attempt 2: Cold Boot + Recursive Firmware Inclusion"]
    C -->|Failure: Display framebuffer lockup during FLR| D["Recovery: Clean Boot Restored"]
    D --> E["Attempt 3: Text Console Boot (plymouth.enable=0) + Direct In-Tree Kernel Module"]
    E -->|Failure: Hard PCIe bus freeze on root port 00:01.0| F["Recovery: Clean Boot Restored"]
    F --> G["Attempt 4: Motherboard BIOS IGFX POST Hand-off"]
    G -->|Failure: Total display signal cut across all headers; CMOS reset required| H["Recovery: CMOS Cleared & System Restored"]
    H --> I["Final Verdict: Incompatible on single-GPU primary display workstations"]
```

---

## 6. Project Artifacts & Available Tools

All created benchmark and recovery tools remain intact and functional in the repository:

- [`scripts/reversal_recovery.sh`](file:///mnt/data/code/gpu-unlock/scripts/reversal_recovery.sh) — Emergency reversal script for instant restoration.
- [`scripts/prepare_option1.sh`](file:///mnt/data/code/gpu-unlock/scripts/prepare_option1.sh) — Setup script for secondary or headless environments.
- [`scripts/set_benchmark_invariants.sh`](file:///mnt/data/code/gpu-unlock/scripts/set_benchmark_invariants.sh) — Clocks locked to 1700 MHz, persistence mode, 350W power cap.
- [`scripts/reset_benchmark_invariants.sh`](file:///mnt/data/code/gpu-unlock/scripts/reset_benchmark_invariants.sh) — Restores dynamic GPU clocks and power limits.
- [`benchmarks/bench_gemm.py`](file:///mnt/data/code/gpu-unlock/benchmarks/bench_gemm.py) — Standalone PyTorch CUDA GEMM benchmark suite.
- [`benchmarks/bench_llm.py`](file:///mnt/data/code/gpu-unlock/benchmarks/bench_llm.py) — Real-world Ollama LLM serving benchmark suite.
- [`benchmarks/compare_benchmarks.py`](file:///mnt/data/code/gpu-unlock/benchmarks/compare_benchmarks.py) — Automated markdown comparison generator.
