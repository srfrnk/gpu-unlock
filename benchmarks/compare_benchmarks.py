#!/usr/bin/env python3
"""
compare_benchmarks.py: Compares baseline and unlocked JSON benchmark outputs,
computing speedup percentages, TFLOPS deltas, and generating BENCHMARK_COMPARISON.md.
"""
import sys
import json
import os

def load_json(filepath):
    if not os.path.exists(filepath):
        print(f"Warning: File not found: {filepath}")
        return None
    with open(filepath, "r") as f:
        return json.load(f)

def format_pct(gain):
    sign = "+" if gain >= 0 else ""
    return f"{sign}{gain:.1f}%"

def generate_comparison_report(
    base_gemm_path="benchmarks/baseline_gemm.json",
    unlock_gemm_path="benchmarks/unlocked_gemm.json",
    base_llm_path="benchmarks/baseline_llm.json",
    unlock_llm_path="benchmarks/unlocked_llm.json",
    output_md="BENCHMARK_COMPARISON.md"
):
    base_gemm = load_json(base_gemm_path)
    unlock_gemm = load_json(unlock_gemm_path)
    base_llm = load_json(base_llm_path)
    unlock_llm = load_json(unlock_llm_path)

    lines = []
    lines.append("# GPU-Unlock Benchmark Comparison Report")
    lines.append("")
    lines.append(f"**Target Device**: {base_gemm.get('device_name', 'NVIDIA GPU') if base_gemm else 'NVIDIA GPU'}")
    lines.append("")
    lines.append("## 1. Executive Summary")
    lines.append("")
    lines.append("Comparison of raw Tensor Core throughput (TFLOPS) and LLM serving rates before and after applying the `gpu-unlock` kernel module.")
    lines.append("")

    # Tier 1 GEMM
    if base_gemm and unlock_gemm:
        lines.append("## 2. Tier 1: Dense GEMM Matrix Multiplications")
        lines.append("")
        lines.append("| Precision | Matrix Shape | Baseline (TFLOPS) | Unlocked (TFLOPS) | Throughput Gain | Baseline Latency | Unlocked Latency |")
        lines.append("| :--- | :--- | :--- | :--- | :--- | :--- | :--- |")

        for prec in base_gemm.get("benchmarks", {}):
            base_runs = {f"{r['m']}x{r['n']}x{r['k']}": r for r in base_gemm["benchmarks"][prec]}
            unlock_runs = {f"{r['m']}x{r['n']}x{r['k']}": r for r in unlock_gemm.get("benchmarks", {}).get(prec, [])}

            for shape, b_data in base_runs.items():
                u_data = unlock_runs.get(shape)
                if u_data:
                    b_tflops = b_data["tflops"]
                    u_tflops = u_data["tflops"]
                    gain = ((u_tflops - b_tflops) / b_tflops) * 100.0 if b_tflops > 0 else 0
                    b_lat = f"{b_data['latency_ms']} ms"
                    u_lat = f"{u_data['latency_ms']} ms"
                    lines.append(f"| **{prec}** | {shape} | {b_tflops:.2f} | {u_tflops:.2f} | **{format_pct(gain)}** | {b_lat} | {u_lat} |")
        lines.append("")

    # Tier 2 LLM
    if base_llm and unlock_llm:
        lines.append("## 3. Tier 2: Real-World LLM Serving (Qwen 27B)")
        lines.append("")
        lines.append("| Task Label | Prompt Tokens | Prefill Baseline | Prefill Unlocked | Prefill Gain | Decode Baseline | Decode Unlocked | Decode Delta |")
        lines.append("| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |")

        base_tasks = {t["label"]: t for t in base_llm.get("tasks", [])}
        unlock_tasks = {t["label"]: t for t in unlock_llm.get("tasks", [])}

        for label, b_task in base_tasks.items():
            u_task = unlock_tasks.get(label)
            if u_task:
                p_base = b_task["prefill_tok_per_sec"]
                p_unlk = u_task["prefill_tok_per_sec"]
                p_gain = ((p_unlk - p_base) / p_base) * 100.0 if p_base > 0 else 0

                d_base = b_task["decode_tok_per_sec"]
                d_unlk = u_task["decode_tok_per_sec"]
                d_gain = ((d_unlk - d_base) / d_base) * 100.0 if d_base > 0 else 0

                prompt_tok = b_task.get("prompt_tokens", "N/A")
                lines.append(f"| **{label}** | {prompt_tok} | {p_base:.2f} tok/s | {p_unlk:.2f} tok/s | **{format_pct(p_gain)}** | {d_base:.2f} tok/s | {d_unlk:.2f} tok/s | {format_pct(d_gain)} |")
        lines.append("")

    with open(output_md, "w") as f:
        f.write("\n".join(lines) + "\n")

    print(f"Comparison report written to: {output_md}")

def main():
    base_g = sys.argv[1] if len(sys.argv) > 1 else "benchmarks/baseline_gemm.json"
    unlk_g = sys.argv[2] if len(sys.argv) > 2 else "benchmarks/unlocked_gemm.json"
    base_l = sys.argv[3] if len(sys.argv) > 3 else "benchmarks/baseline_llm.json"
    unlk_l = sys.argv[4] if len(sys.argv) > 4 else "benchmarks/unlocked_llm.json"
    out_md = sys.argv[5] if len(sys.argv) > 5 else "BENCHMARK_COMPARISON.md"

    generate_comparison_report(base_g, unlk_g, base_l, unlk_l, out_md)

if __name__ == "__main__":
    main()
