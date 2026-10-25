#!/usr/bin/env python3
"""
bench_gemm.py: Microbenchmark measuring Tensor Core FP16, BF16, and TF32 GEMM throughput.
"""
import sys
import json
import time
import subprocess
import torch

def get_gpu_telemetry():
    try:
        cmd = [
            "nvidia-smi",
            "--query-gpu=temperature.gpu,power.draw,clocks.current.graphics",
            "--format=csv,noheader,nounits"
        ]
        out = subprocess.check_output(cmd, text=True).strip().split(",")
        return {
            "temperature_c": float(out[0].strip()),
            "power_w": float(out[1].strip()),
            "clock_mhz": float(out[2].strip()),
        }
    except Exception as e:
        return {"error": str(e)}

def run_gemm(m: int, n: int, k: int, dtype: torch.dtype, allow_tf32: bool, warmup: int = 15, runs: int = 30):
    torch.backends.cuda.matmul.allow_tf32 = allow_tf32
    device = torch.device("cuda:0")

    a = torch.randn((m, k), device=device, dtype=dtype)
    b = torch.randn((k, n), device=device, dtype=dtype)

    # Warmup passes
    for _ in range(warmup):
        _ = torch.matmul(a, b)
    torch.cuda.synchronize()

    start_event = torch.cuda.Event(enable_timing=True)
    end_event = torch.cuda.Event(enable_timing=True)

    start_event.record()
    for _ in range(runs):
        _ = torch.matmul(a, b)
    end_event.record()
    torch.cuda.synchronize()

    latency_ms = start_event.elapsed_time(end_event) / runs
    total_flops = 2.0 * m * n * k
    tflops = (total_flops / (latency_ms / 1000.0)) / 1e12
    telemetry = get_gpu_telemetry()

    return {
        "m": m,
        "n": n,
        "k": k,
        "latency_ms": round(latency_ms, 3),
        "tflops": round(tflops, 2),
        "telemetry": telemetry
    }

def main():
    if not torch.cuda.is_available():
        print("ERROR: CUDA device not available.")
        sys.exit(1)

    device_name = torch.cuda.get_device_name(0)
    print(f"==================================================================")
    print(f"  PyTorch Dense GEMM Benchmark Suite")
    print(f"  Device: {device_name}")
    print(f"==================================================================")

    matrix_sizes = [2048, 4096, 8192]
    precisions = [
        ("BF16", torch.bfloat16, True),
        ("FP16", torch.float16, True),
        ("TF32 (FP32)", torch.float32, True),
        ("FP32 (no TF32)", torch.float32, False),
    ]

    results = {
        "device_name": device_name,
        "timestamp": time.time(),
        "benchmarks": {}
    }

    print(f"{'Precision':<16} | {'Shape (MxNxK)':<15} | {'Throughput (TFLOPS)':<20} | {'Latency (ms)':<12} | {'Temp (°C)':<8} | {'Power (W)':<8}")
    print("-" * 90)

    for label, dtype, allow_tf32 in precisions:
        results["benchmarks"][label] = []
        for size in matrix_sizes:
            res = run_gemm(m=size, n=size, k=size, dtype=dtype, allow_tf32=allow_tf32, warmup=15, runs=30)
            results["benchmarks"][label].append(res)
            temp = res["telemetry"].get("temperature_c", "N/A")
            power = res["telemetry"].get("power_w", "N/A")
            shape_str = f"{size}x{size}x{size}"
            print(f"{label:<16} | {shape_str:<15} | {res['tflops']:>18.2f}   | {res['latency_ms']:>10.2f}   | {temp:>8} | {power:>8}")
            time.sleep(1) # Thermal settling

    output_path = sys.argv[1] if len(sys.argv) > 1 else "gemm_results.json"
    with open(output_path, "w") as f:
        json.dump(results, f, indent=2)

    print("-" * 90)
    print(f"Results saved to: {output_path}")

if __name__ == "__main__":
    main()
