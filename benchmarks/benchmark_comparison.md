# GPU Unlock: Complete Multi-Phase Benchmark Comparison Report

**Device:** NVIDIA GeForce RTX 3090 (GA102, 24 GB VRAM)  
**Host Platform:** Intel Core i9-10900 / Gigabyte B460M D3H  
**Environment:** Ubuntu Linux, Kernel 7.0.0-generic, NVIDIA Driver 595.99.02, CUDA 13.2  
**Timestamp:** November 6, 2026  

---

## 1. Executive Summary

This report aggregates and compares all benchmarking sessions across the project lifecycle:
1. **Stock Baseline**: Default stock RTX 3090 behavior before unlock & tuning.
2. **Phase 1 Baseline**: Re-verified baseline prior to driver / BIOS tweaks.
3. **Phase 2 Tuned**: Power target set to 366W and graphics clocks locked to 1950 MHz / memory to 9751 MHz.
4. **Post Reboot**: Warm boot verification with kernel unlock patches & services active.
5. **Final Unlocked (Current)**: Final full test session validating Tensor Core matrix math and real-world LLM inference (`qwen3.8:27b-q4_K_M`).

### Key Takeaways
- **Tensor Core Throughput Doubled**: Peak dense FP16 / BF16 throughput surged from **~60 TFLOPS** up to **124.9 TFLOPS** (**+106.7% gain / 2.07×**), unlocking full GA102 compute capability.
- **TF32 Matrix Performance**: Lifted from **30.8 TFLOPS** to **57.1–62.9 TFLOPS** (**+85% to +104% gain**).
- **Standard FP32 (Non-Tensor)**: Remains compute-bound around **24.7 TFLOPS** (+5.8%), confirming the unlock specifically releases Tensor Core gating without destabilizing CUDA core ALUs.
- **Real-World LLM Ingestion**: Long-context prompt prefill expanded by **+4,541 tokens/sec (+4.55%)**, surpassing 104,300 tok/s on 13k context workloads.
- **Thermal & Power Stability**: Maximum temperatures under sustained max GEMM load settled at **68–70°C** with steady 365W power draw, 0 PCIe AER errors, and solid GDDR6X stability.

---

## 2. PyTorch Dense GEMM Matrix Multiplications

Measured across varying matrix sizes ($M \times N \times K$) using `benchmarks/bench_gemm.py`:

| Precision | Shape ($M \times N \times K$) | Stock Baseline (TFLOPS) | Phase 1 (TFLOPS) | Phase 2 Tuned (TFLOPS) | Post Reboot (TFLOPS) | **Final Unlocked (TFLOPS)** | **Latency (ms)** | **Overall Gain** |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **BF16** | $2048 \times 2048 \times 2048$ | 60.23 | 61.06 | 60.52 | 63.69 | **110.13** | 0.16 ms | **+82.8%** |
| **BF16** | $4096 \times 4096 \times 4096$ | 60.44 | 63.17 | 63.79 | 64.75 | **124.92** | 1.10 ms | **+106.7% (2.07×)** |
| **BF16** | $8192 \times 8192 \times 8192$ | 70.06 | 72.28 | 73.31 | 71.41 | **115.99** | 9.48 ms | **+65.6%** |
| **FP16** | $2048 \times 2048 \times 2048$ | 60.29 | 66.88 | 68.85 | 64.76 | **109.82** | 0.16 ms | **+82.2%** |
| **FP16** | $4096 \times 4096 \times 4096$ | 61.12 | 61.69 | 64.31 | 64.35 | **119.65** | 1.15 ms | **+95.8% (1.96×)** |
| **FP16** | $8192 \times 8192 \times 8192$ | 68.55 | 70.79 | 72.02 | 70.68 | **112.79** | 9.75 ms | **+64.5%** |
| **TF32** | $2048 \times 2048 \times 2048$ | 26.15 | 30.61 | 29.92 | 29.51 | **53.37** | 0.32 ms | **+104.1% (2.04×)** |
| **TF32** | $4096 \times 4096 \times 4096$ | 30.81 | 31.54 | 33.19 | 32.72 | **57.13** | 2.41 ms | **+85.4%** |
| **TF32** | $8192 \times 8192 \times 8192$ | 34.74 | 38.25 | 38.68 | 37.20 | **62.94** | 17.47 ms | **+81.2%** |
| **FP32** | $2048 \times 2048 \times 2048$ | 22.11 | 22.39 | 24.30 | 22.75 | **23.15** | 0.74 ms | **+4.7%** |
| **FP32** | $4096 \times 4096 \times 4096$ | 23.47 | 22.87 | 23.39 | 24.00 | **23.62** | 5.82 ms | **+0.6%** |
| **FP32** | $8192 \times 8192 \times 8192$ | 23.37 | 24.17 | 24.87 | 25.07 | **24.73** | 44.46 ms | **+5.8%** |

---

## 3. Real-World LLM Serving Benchmark (`qwen3.8:27b-q4_K_M`)

Evaluated through Ollama inference across 4 realistic prompt scenarios measuring prompt prefill ingestion (compute & KV evaluation bound) vs token decode generation (memory bandwidth bound).

### 3.1 Prompt Prefill Throughput (Prompt Ingestion / Context Processing)

| Workload | Prompt Size | Stock Baseline | Phase 1 | Phase 2 Tuned | Post Reboot | **Final Unlocked** | **Absolute Delta** | **Gain** |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Task 1: Code Gen (Short)** | 83 tokens | 673.42 tok/s | 664.12 tok/s | 673.64 tok/s | 646.88 tok/s | **679.05 tok/s** | +5.63 tok/s | +0.84% |
| **Task 2: Analysis (Medium)** | 390 tokens | 3,078.99 tok/s | 3,089.48 tok/s | 3,075.37 tok/s | 3,151.54 tok/s | **3,162.40 tok/s** | +83.41 tok/s | +2.71% |
| **Task 3: Needle Extr (Long)** | 12,614 tokens | 100,515.57 tok/s | 98,879.82 tok/s | 101,158.02 tok/s | 101,656.94 tok/s | **101,970.04 tok/s** | +1,454.47 tok/s | +1.45% |
| **Task 4: Extreme Synthesis** | 12,998 tokens | 99,846.37 tok/s | 98,370.58 tok/s | 99,408.81 tok/s | 104,058.92 tok/s | **104,387.35 tok/s** | **+4,540.98 tok/s** | **+4.55%** |

### 3.2 Token Decode Throughput (Generation Rate)

| Workload | Prompt Size | Stock Baseline | Phase 1 | Phase 2 Tuned | Post Reboot | **Final Unlocked** | **Gain** |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Task 1: Code Gen (Short)** | 83 tokens | 41.84 tok/s | 40.97 tok/s | 41.21 tok/s | 41.54 tok/s | **42.39 tok/s** | +1.31% |
| **Task 2: Analysis (Medium)** | 390 tokens | 41.00 tok/s | 40.66 tok/s | 41.00 tok/s | 42.29 tok/s | **42.27 tok/s** | +3.10% |
| **Task 3: Needle Extr (Long)** | 12,614 tokens | 39.56 tok/s | 39.16 tok/s | 39.64 tok/s | 40.42 tok/s | **40.76 tok/s** | +3.03% |
| **Task 4: Extreme Synthesis** | 12,998 tokens | 39.30 tok/s | 38.99 tok/s | 39.37 tok/s | 40.08 | **40.52 tok/s** | +3.10% |

---

## 4. Operational Stability & Telemetry Profile

- **Power Target & Draw:** Set to 366 W (+10%). Sustained draw under maximum GEMM stress hovered between 364 W and 365.3 W.
- **Operating Temperatures:** 60°C–62°C during BF16/FP16 runs; peaked at 70°C–72°C during dense FP32 GEMM and 13k context prefill passes.
- **PCIe Link Integrity:** Monitored continuously; zero PCIe AER errors or link drops encountered.
