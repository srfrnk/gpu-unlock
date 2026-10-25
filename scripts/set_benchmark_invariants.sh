#!/usr/bin/env bash
set -euo pipefail

echo "=================================================================="
echo "  Applying Benchmark Invariants & Environmental Controls"
echo "=================================================================="

# 1. Enable Persistence Mode
echo "[1/3] Enabling GPU persistence mode..."
sudo nvidia-smi -pm 1

# 2. Lock GPU Clocks to Base Frequency (1700 MHz for RTX 3090 reference)
echo "[2/3] Locking GPU core clocks to 1700 MHz..."
sudo nvidia-smi --lock-gpu-clocks=1700,1700

# 3. Set Uniform Power Limit (350W reference)
echo "[3/3] Setting uniform power limit to 350W..."
sudo nvidia-smi -pl 350

echo "==> Environmental controls applied successfully."
