#!/usr/bin/env bash
# Prints ACTIVE or INACTIVE for each gpu_unlock target of the current boot.
# Exit code: 0 if every target is unlocked, 1 otherwise.
# With --bench, also measures FP16 tensor GEMM throughput on the card (needs
# torch; set PYTHON to an interpreter that has it). It prints TFLOPS only; compare against a run without the unlock.
set -uo pipefail

targets=$(tr ' ' '\n' </proc/cmdline | sed -n 's/^gpu_unlock\.targets=//p' | tr ',' ' ')
if [[ -z "$targets" ]]; then
    echo "INACTIVE: gpu_unlock.targets= is not on the kernel command line"
    exit 1
fi

log=$(journalctl -k -b 2>/dev/null | grep gpu_unlock || sudo dmesg | grep gpu_unlock)

status=0
for dev in $targets; do
    if grep -q "pci $dev: gpu_unlock: unlocked" <<<"$log"; then
        echo "ACTIVE: $dev unlocked this boot"
    else
        echo "INACTIVE: $dev not unlocked this boot (check: journalctl -k -b | grep gpu_unlock)"
        status=1
    fi
done

if [[ "${1:-}" == "--bench" ]]; then
    "${PYTHON:-python3}" - <<'PY' || status=1
import torch
n = 8192
a = torch.randn(n, n, device="cuda", dtype=torch.float16)
b = torch.randn(n, n, device="cuda", dtype=torch.float16)
for _ in range(10):
    a @ b
torch.cuda.synchronize()
start, end = torch.cuda.Event(enable_timing=True), torch.cuda.Event(enable_timing=True)
start.record()
for _ in range(30):
    a @ b
end.record()
torch.cuda.synchronize()
print(f"FP16 GEMM {n}x{n}: {2 * n**3 * 30 / (start.elapsed_time(end) / 1e3) / 1e12:.1f} TFLOPS")
PY
fi
exit $status
