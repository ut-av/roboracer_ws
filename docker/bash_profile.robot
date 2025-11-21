# Robot-specific (Jetson/ARM64) configuration
# This file is appended to bash_profile.shared

export LD_LIBRARY_PATH=/usr/local/lib/python3.10/dist-packages/torch/lib:/usr/local/cuda/lib64:$LD_LIBRARY_PATH
export Torch_DIR=/usr/local/lib/python3.10/dist-packages/torch/share/cmake/Torch:$Torch_DIR

export CMAKE_BUILD_MODE=Hardware
