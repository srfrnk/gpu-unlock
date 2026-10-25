#!/usr/bin/env bash
set -euo pipefail

echo "=================================================================="
echo "  Resetting Benchmark Invariants & Environmental Controls"
echo "=================================================================="

# 1. Reset GPU Clock Locks
echo "[1/2] Resetting GPU core clock lock..."
sudo nvidia-smi -rgc || true

# 2. Reset Power Limit
echo "[2/2] Resetting GPU power limit to default..."
sudo nvidia-smi -rpl || true

echo "==> Environmental controls reset to defaults."
