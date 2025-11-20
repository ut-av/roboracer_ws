# Docker Build Guide

This Dockerfile supports both **Jetson (ARM64)** and **AMD64** platforms using Docker's multi-stage build feature. It automatically detects your platform and builds the appropriate image natively.

## Architecture Overview

The Dockerfile automatically selects the appropriate base image based on your current platform:

- **ARM64 (Jetson Thor, Orin, etc.)**: Uses `nvcr.io/nvidia/l4t-jetpack:r36.4.0`
- **AMD64 (x86_64 development machines)**: Uses `ubuntu:22.04` with optional CUDA toolkit

**Note**: This setup is designed for native builds only. Build the image on the platform where you intend to run it.

## Requirements

- **Docker with BuildKit**: The Dockerfile uses BuildKit features for automatic platform detection. BuildKit is enabled by default in Docker 23.0+.
  - To enable BuildKit manually: `export DOCKER_BUILDKIT=1`
  - Or add to `/etc/docker/daemon.json`: `{"features": {"buildkit": true}}`

## Building the Image

The `container` script at the root of the workspace handles building automatically for your current platform.

### Using the Container Script (Recommended)

The script auto-detects your platform and builds accordingly:

```bash
cd /home/orin/roboracer_ws

# Build for current platform (auto-detected)
./container build --name roboracer
```

The build will automatically use:
- **On Jetson (ARM64)**: NVIDIA JetPack base image with CUDA, TensorRT, VPI, etc.
- **On AMD64**: Ubuntu 22.04 with CUDA Toolkit 12.6

### Container Script Commands

```bash
# Build and start container
./container build --name roboracer

# Start existing container
./container start --name roboracer

# Stop container
./container stop --name roboracer

# Restart container
./container restart --name roboracer

# Open shell in running container
./container shell --name roboracer

# Run a command in container
./container cmd --name roboracer "ros2 topic list"

# Remove container and image
./container rm --name roboracer
```

### Manual Docker Build

If you prefer to use docker commands directly:

```bash
# For Jetson (ARM64)
docker build \
  --build-arg uid=$(id -u) \
  --build-arg gid=$(id -g) \
  --build-arg username=$(whoami) \
  -t roboracer \
  -f docker/Dockerfile \
  .

# For AMD64
docker build \
  --build-arg uid=$(id -u) \
  --build-arg gid=$(id -g) \
  --build-arg username=$(whoami) \
  -t roboracer \
  -f docker/Dockerfile \
  .
```

## Build Stages

The Dockerfile is organized into 10 stages for better caching and modularity:

1. **base-arm64 / base-amd64**: Platform-specific base images
2. **base-selected**: Automatic platform selection
3. **base-setup**: Locale and essential tools
4. **ros2-install**: ROS2 Humble installation
5. **hardware-deps**: Camera and sensor dependencies (RealSense, MPU6050)
6. **app-deps**: Application libraries (GStreamer, OpenGL, Qt, etc.)
7. **python-ml**: Python and PyTorch
8. **nav-slam**: Navigation and SLAM libraries
9. **utilities**: Additional utilities and scripts
10. **final**: User creation and configuration

## Platform-Specific Features

### ARM64 (Jetson) Features
- NVIDIA JetPack (CUDA, cuDNN, TensorRT, VPI)
- Isaac ROS packages
- Jetson hardware acceleration
- jetson-stats monitoring tool

### AMD64 Features
- CUDA Toolkit 12.6 (optional, for NVIDIA GPU support)
- Standard Ubuntu 22.04 base
- Compatible with most x86_64 development machines

## Customization

### Disable CUDA on AMD64

If you don't need GPU support on AMD64, comment out lines 28-43 in the Dockerfile:

```dockerfile
# =============================================================================
# Stage 2: AMD64 Base (for x86_64 development machines)
# =============================================================================
FROM ubuntu:22.04 AS base-amd64

# Comment out the CUDA installation section below if not needed
# RUN apt-get update && apt-get install -y \
#     wget \
#     gnupg2 \
#     && rm -rf /var/lib/apt/lists/*
# ...
```

### Change Base Images

- **ARM64**: Modify line 18 to use a different JetPack version or the ML container
- **AMD64**: Modify line 26 to use a different Ubuntu version

## Troubleshooting

### Platform Detection

The build automatically detects your platform:
- ARM64/aarch64 (Jetson devices) → Uses NVIDIA JetPack base
- x86_64 (AMD64 machines) → Uses Ubuntu 22.04 base

You can verify your platform with: `uname -m`

### Build Fails on Platform-Specific Packages

The Dockerfile includes graceful fallbacks for platform-specific packages:
- **Isaac ROS** (ARM64-only): Will show "Isaac ROS not available on this platform" on AMD64
- **jetson-stats** (ARM64-only): Will show similar message on AMD64

This is expected behavior and won't stop the build.

### CUDA Version Mismatch

If you need a different CUDA version on AMD64, modify line 42:
```dockerfile
RUN apt-get update && apt-get install -y \
    cuda-toolkit-12-6 \  # Change to your desired version
    && rm -rf /var/lib/apt/lists/*
```

### PyTorch Installation Issues

The PyTorch installation includes a fallback:
```dockerfile
RUN pip3 install torch==2.6.0 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu126 || \
    pip3 install torch torchvision torchaudio
```

If the CUDA 12.6 version fails, it will install the default PyTorch version.

## Running the Container

### Using the Container Script (Recommended)

The easiest way to run the container:

```bash
# Start the container and open a shell
./container shell --name roboracer
```

The script automatically handles:
- Platform-specific runtime flags (NVIDIA runtime for Jetson)
- Volume mounts (configured in `config/mounts`)
- Port mappings (configured in `config/ports`)
- GPU access
- Device access

### Manual Docker Run

If you prefer to use docker commands directly:

#### Jetson (ARM64)
```bash
docker run -it --rm \
  --runtime nvidia \
  --network host \
  --privileged \
  -v /home/orin/roboracer_ws:/home/orin/roboracer_ws \
  -v /dev:/dev \
  roboracer
```

#### AMD64
```bash
docker run -it --rm \
  --gpus all \
  --network host \
  -v /path/to/roboracer_ws:/home/developer/roboracer_ws \
  roboracer
```

