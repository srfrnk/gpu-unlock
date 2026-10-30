# GPU-Unlock Benchmark Comparison Report

**Target Device**: NVIDIA GeForce RTX 3090

## 1. Executive Summary

Comparison of raw Tensor Core throughput (TFLOPS) and LLM serving rates before and after applying the `gpu-unlock` kernel module.

## 2. Tier 1: Dense GEMM Matrix Multiplications

| Precision | Matrix Shape | Baseline (TFLOPS) | Unlocked (TFLOPS) | Throughput Gain | Baseline Latency | Unlocked Latency |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **BF16** | 2048x2048x2048 | 61.06 | 60.52 | **-0.9%** | 0.281 ms | 0.284 ms |
| **BF16** | 4096x4096x4096 | 63.17 | 63.79 | **+1.0%** | 2.176 ms | 2.154 ms |
| **BF16** | 8192x8192x8192 | 72.28 | 73.31 | **+1.4%** | 15.212 ms | 14.998 ms |
| **FP16** | 2048x2048x2048 | 66.88 | 68.85 | **+2.9%** | 0.257 ms | 0.25 ms |
| **FP16** | 4096x4096x4096 | 61.69 | 64.31 | **+4.2%** | 2.228 ms | 2.137 ms |
| **FP16** | 8192x8192x8192 | 70.79 | 72.02 | **+1.7%** | 15.532 ms | 15.268 ms |
| **TF32 (FP32)** | 2048x2048x2048 | 30.61 | 29.92 | **-2.3%** | 0.561 ms | 0.574 ms |
| **TF32 (FP32)** | 4096x4096x4096 | 31.54 | 33.19 | **+5.2%** | 4.357 ms | 4.141 ms |
| **TF32 (FP32)** | 8192x8192x8192 | 38.25 | 38.68 | **+1.1%** | 28.744 ms | 28.426 ms |
| **FP32 (no TF32)** | 2048x2048x2048 | 22.39 | 24.30 | **+8.5%** | 0.767 ms | 0.707 ms |
| **FP32 (no TF32)** | 4096x4096x4096 | 22.87 | 23.39 | **+2.3%** | 6.008 ms | 5.877 ms |
| **FP32 (no TF32)** | 8192x8192x8192 | 24.17 | 24.87 | **+2.9%** | 45.492 ms | 44.204 ms |

