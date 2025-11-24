#!/bin/sh
# Detect GPU and set environment variables for CUDA and PyTorch installation

# Default to Standard PyTorch 2.5 (CUDA 12.4) for older GPUs
export PT_VER="2.5.0"
export VIS_VER="0.20.0"
export AUD_VER="2.5.0"
export CUDA_TAG="cu124"
export CUDA_TOOLKIT_PKG="cuda-toolkit-12-4"

# Check for Blackwell (RTX 50 series)
# We check if nvidia-smi exists, then grep for "RTX 50" in the GPU name.
if command -v nvidia-smi >/dev/null 2>&1; then
    if nvidia-smi --query-gpu=name --format=csv,noheader | grep -q "RTX 50"; then
        echo ">>> DETECTED BLACKWELL GPU (RTX 50 Series). Upgrading to PyTorch 2.7 / CUDA 12.8"
        export PT_VER="2.7.0"
        export VIS_VER="0.22.0"
        export AUD_VER="2.7.0"
        export CUDA_TAG="cu128"
        export CUDA_TOOLKIT_PKG="cuda-toolkit-12-8"
    fi
fi
