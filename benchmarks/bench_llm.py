#!/usr/bin/env python3
"""
bench_llm.py: Evaluates real-world LLM serving throughput on Ollama (Qwen 27B).
Measures prompt prefill rate (compute-bound) vs token decode rate (bandwidth-bound).
"""
import sys
import json
import time
import urllib.request
import statistics
import subprocess

MODEL = "qwen3.8:27b-q4_K_M"
OLLAMA_API = "http://localhost:11434/api/generate"

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

def query_ollama(prompt: str, max_tokens: int = 256) -> dict:
    payload = json.dumps({
        "model": MODEL,
        "prompt": prompt,
        "stream": False,
        "options": {
            "num_predict": max_tokens,
            "temperature": 0.0,
            "seed": 42
        }
    }).encode("utf-8")

    req = urllib.request.Request(OLLAMA_API, data=payload, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode("utf-8"))

    prompt_tokens = data.get("prompt_eval_count", 0)
    prompt_duration_sec = data.get("prompt_eval_duration", 1) / 1e9
    eval_tokens = data.get("eval_count", 0)
    eval_duration_sec = data.get("eval_duration", 1) / 1e9

    prefill_tps = prompt_tokens / prompt_duration_sec if prompt_duration_sec > 0 else 0
    decode_tps = eval_tokens / eval_duration_sec if eval_duration_sec > 0 else 0

    return {
        "prompt_tokens": prompt_tokens,
        "eval_tokens": eval_tokens,
        "prefill_tps": prefill_tps,
        "decode_tps": decode_tps,
        "response": data.get("response", "")
    }

def run_benchmark_task(label: str, prompt: str, max_tokens: int = 256, trials: int = 5):
    # Warmup pass
    query_ollama(prompt[:500], max_tokens=16)

    prefills, decodes = [], []
    prompt_len = 0
    gen_len = 0
    sample_response = ""

    for i in range(trials):
        res = query_ollama(prompt, max_tokens=max_tokens)
        prefills.append(res["prefill_tps"])
        decodes.append(res["decode_tps"])
        prompt_len = res["prompt_tokens"]
        gen_len = res["eval_tokens"]
        sample_response = res["response"]

    med_prefill = statistics.median(prefills)
    med_decode = statistics.median(decodes)
    telemetry = get_gpu_telemetry()

    print(f"[{label:<28}] Prompt: {prompt_len:>5} tok | Ingest: {med_prefill:>7.2f} tok/s | Decode: {med_decode:>6.2f} tok/s | Temp: {telemetry.get('temperature_c', 'N/A')}°C | Power: {telemetry.get('power_w', 'N/A')}W")

    return {
        "label": label,
        "prompt_tokens": prompt_len,
        "generated_tokens": gen_len,
        "prefill_tok_per_sec": round(med_prefill, 2),
        "decode_tok_per_sec": round(med_decode, 2),
        "trials_prefill": [round(x, 2) for x in prefills],
        "trials_decode": [round(x, 2) for x in decodes],
        "telemetry": telemetry,
        "sample": sample_response[:120].replace('\n', ' ') + "..."
    }

# ==============================================================================
# PROMPT DEFINITIONS
# ==============================================================================

PROMPT_SHORT_CODE = """You are a systems performance engineer. Write a complete, production-ready C++20 concurrent bounded lock-free circular ring buffer suitable for audio DSP processing.
Include memory ordering specifications (std::memory_order_acquire, std::memory_order_release), thread safety considerations, and handle cacheline false sharing with alignas.
Provide clean, concise implementation without unnecessary boilerplate."""

PROMPT_MEDIUM_ANALYSIS = """Analyze the following architectural summary comparing unified memory architectures against discrete PCIe GPU buses:

Modern discrete GPUs communicate across high-speed PCIe links (PCIe Gen4 x16 offering ~31.5 GB/s bidirectional throughput, and Gen5 doubling that to ~63 GB/s). While host DDR5 system memory achieves throughput in the range of 60-90 GB/s, modern GPU local memory subsystems utilizing GDDR6X or HBM3 routinely reach between 900 GB/s and 3.2 TB/s. Consequently, high-performance computing and deep learning models operating over discrete cards must minimize host-to-device transfers, relying on asynchronous DMA pinned ring buffers, pipelined prefetching, and localized kernel execution to prevent bus saturation.

Unified memory architectures, by contrast, present a contiguous physical address space shared coherently between the CPU host complex and heterogeneous accelerator clusters. By removing the discrete physical PCIe boundary, accelerators access system memory directly through wide multichannel buses (often exceeding 400-800 GB/s on integrated unified packages). This drastically simplifies zero-copy memory mapping, avoids duplicate buffer staging, and removes serialization costs for sparse graph processing or large KV cache lookups. However, unified systems often face thermal coupling challenges where high thermal dissipation on the accelerator package restricts CPU burst frequencies, alongside memory contention between cache-coherent CPU cores and throughput-oriented SIMD engines.

TASK:
1. Provide a rigorous structured comparison of PCIe Gen4/Gen5 vs. Unified Memory in terms of latency profiles, bandwidth bottlenecks, and cache coherency protocols.
2. Outline the trade-offs when serving a 27B parameter quantized model where KV-cache growth exceeds localized device memory.
3. Conclude with architectural recommendations for real-time low-latency voice translation vs. high-throughput batch document embeddings."""

def generate_log_haystack(lines_count=180, needle_line=""):
    base_logs = [
        "2026-10-24T14:20:10.104Z auth-service[1042]: INFO pam_unix(sshd:session): session opened for user service-mon by (uid=0)",
        "2026-10-24T14:20:11.201Z gateway-ingress[4012]: 200 GET /api/v2/metrics status=200 duration=1.24ms upstream=10.0.4.12:8080",
        "2026-10-24T14:20:12.890Z billing-worker[892]: INFO Invoice batch #40192 queued for processing (size=450 invoices)",
        "2026-10-24T14:20:13.402Z db-replica-04[209]: DEBUG WAL receiver checkpoint synclist acknowledged lsn=0/4A12B890",
        "2026-10-24T14:20:14.004Z cache-cluster[601]: INFO Evicted 1204 keys matching prefix 'sess_temp_' in 4.2ms",
        "2026-10-24T14:20:15.512Z compute-worker-12[310]: INFO CUDA kernel batch GEMM dispatch finished successfully elapsed=14.2ms"
    ]
    haystack = []
    needle_index = lines_count // 2
    for i in range(lines_count):
        if i == needle_index and needle_line:
            haystack.append(needle_line)
        else:
            haystack.append(base_logs[i % len(base_logs)])
    return "\n".join(haystack)

NEEDLE_STRING = "2026-10-24T14:20:13.999Z security-audit[9999]: CRITICAL Zero-day vulnerability CVE-2026-9812 verified. Compromised node ID: k8s-worker-gpu-node-04b with payload checksum: e9b4c102a8."
HAYSTACK_TEXT = generate_log_haystack(lines_count=220, needle_line=NEEDLE_STRING)

PROMPT_LONG_NEEDLE = f"""You are an automated security intelligence parser. Read the system log stream below carefully.
Identify and extract any critical security alerts or confirmed zero-day events.

SYSTEM AUDIT LOG:
{HAYSTACK_TEXT}

EXTRACTION INSTRUCTIONS:
Extract the critical security breach into strict JSON format with exactly the following schema:
{{
  "timestamp": "ISO8601 string",
  "cve_id": "string",
  "compromised_node": "string",
  "payload_checksum": "string",
  "recommended_mitigation": "string"
}}
Return ONLY the raw JSON block without any conversational prefixes or markdown formatting."""

PROMPT_EXTREME_SYNTHESIS = f"""Analyze and cross-reference the operational telemetry, security events, and architectural constraints detailed across the following comprehensive system profile:

=== LOG DUMP ===
{HAYSTACK_TEXT}

=== OPERATIONAL METRICS & ARCHITECTURAL PROFILE ===
{PROMPT_MEDIUM_ANALYSIS}

TASK:
1. Synthesize the operational telemetry with the compute-memory bottlenecks detailed in the profile.
2. If node k8s-worker-gpu-node-04b were serving Qwen 27B under the zero-day incident referenced in the audit logs, explain how an attacker could exploit KV cache allocation buffers.
3. Formulate a 5-step incident response playbook isolating compromised PCIe endpoints without causing a full cluster split-brain."""

def main():
    print(f"==================================================================")
    print(f"  Ollama Realistic Prompt Evaluation Suite: {MODEL}")
    print(f"==================================================================")

    tasks = [
        ("Task 1: Code Gen (Short)", PROMPT_SHORT_CODE, 256),
        ("Task 2: Analysis (Medium)", PROMPT_MEDIUM_ANALYSIS, 300),
        ("Task 3: Needle Extr (Long)", PROMPT_LONG_NEEDLE, 128),
        ("Task 4: Synthesis (Extreme)", PROMPT_EXTREME_SYNTHESIS, 400),
    ]

    results = {
        "model": MODEL,
        "timestamp": time.time(),
        "tasks": []
    }

    for label, prompt, max_tok in tasks:
        res = run_benchmark_task(label, prompt, max_tokens=max_tok, trials=5)
        results["tasks"].append(res)
        time.sleep(2) # Thermal settling between tasks

    output_path = sys.argv[1] if len(sys.argv) > 1 else "llm_results.json"
    with open(output_path, "w") as f:
        json.dump(results, f, indent=2)

    print("-" * 70)
    print(f"Results saved to: {output_path}")

if __name__ == "__main__":
    main()
