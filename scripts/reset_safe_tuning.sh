#!/usr/bin/env bash
set -euo pipefail

echo "=================================================================="
echo "  Resetting GPU to Stock Dynamic Factory Settings"
echo "=================================================================="

# 1. Reset GPU Core Clocks to Dynamic Auto Management
echo "[1/4] Resetting GPU core clocks..."
sudo nvidia-smi --reset-gpu-clocks

# 2. Reset Memory Clocks to Dynamic Auto Management
echo "[2/4] Resetting memory clocks..."
sudo nvidia-smi --reset-memory-clocks

# 3. Reset Power Limit to Default (350W)
echo "[3/4] Resetting power limit to default (350W)..."
sudo nvidia-smi -pl 350

# 4. Persistence Mode can remain enabled or be disabled
echo "[4/4] Keeping persistence mode enabled for desktop responsiveness."

echo "=================================================================="
echo "  Current Status:"
echo "=================================================================="
nvidia-smi -q -d CLOCK,POWER | grep -E "Current Power Limit|Graphics|Memory|SM" | head -n 6
echo "==> Successfully reset to factory dynamic clocks."
