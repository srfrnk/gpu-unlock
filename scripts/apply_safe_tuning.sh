#!/usr/bin/env bash
set -euo pipefail

echo "=================================================================="
echo "  Applying Phase 2: Safe Silicon & Driver Performance Tuning"
echo "=================================================================="

# 1. Enable Persistence Mode to keep driver loaded & reduce latency
echo "[1/4] Enabling GPU persistence mode..."
sudo nvidia-smi -pm 1

# 2. Set Maximum Board Power Limit (366W on this RTX 3090, stock is 350W)
echo "[2/4] Setting power limit to 366W..."
sudo nvidia-smi -pl 366

# 3. Lock Graphics / Core Clock to Boost Frequency Range (1800-1950 MHz)
# This prevents aggressive frequency down-stepping during heavy GEMM compute
echo "[3/4] Locking GPU core clocks to 1800,1950 MHz..."
sudo nvidia-smi --lock-gpu-clocks=1800,1950

# 4. Lock Memory Clock to 9751 MHz (Bypassing the CUDA P2 State Downclock)
# By default NVIDIA drivers downclock GDDR6X by 200-500 MHz when CUDA starts
echo "[4/4] Locking memory clock to 9751 MHz (CUDA P2 bypass)..."
sudo nvidia-smi --lock-memory-clocks=9751,9751

echo "=================================================================="
echo "  Current Tuning Status:"
echo "=================================================================="
nvidia-smi -q -d CLOCK,POWER | grep -E "Current Power Limit|Graphics|Memory|SM" | head -n 6
echo "==> Safe silicon tuning successfully applied."
