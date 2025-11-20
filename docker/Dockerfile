# =============================================================================
# Base Image and Build Arguments
#  - Docker container must match jetpack version installed on Jetson
#    - Image list: https://catalog.ngc.nvidia.com/orgs/nvidia/containers/l4t-base/tags
#  - ROS2 Humble is used for Jetson Orin OpenCV and Python version compatibility
#  - For native builds: ARM64/Jetson uses l4t-jetpack, AMD64 uses Ubuntu 22.04
# =============================================================================

# Build arguments
ARG ros_distro=humble
ARG gid
ARG uid
ARG username
ARG install_cuda=false

# =============================================================================
# Stage 1: Platform-Specific Base Images
# =============================================================================
# For Robot (ARM64/Jetson): Use NVIDIA JetPack base image
# Note: Stage name uses "arm64" to match Docker's TARGETARCH variable
ARG BASE_IMAGE_ARM64
FROM ${BASE_IMAGE_ARM64} AS base-arm64
# JetPack container: includes CUDA, cuDNN, TensorRT, VPI, Jetson Multimedia, and so on
# Alternative ML container with PyTorch, TensorFlow pre-installed:
# FROM nvcr.io/nvidia/l4t-ml:r36.2.0-py3 AS base-arm64

# For Desktop (AMD64/x86_64): Use Ubuntu 22.04 with optional CUDA
# Note: Stage name uses "amd64" to match Docker's TARGETARCH variable
FROM ubuntu:22.04 AS base-amd64

ARG install_cuda

# Install CUDA toolkit for Desktop only if install_cuda is true
# This provides GPU support on Desktop machines with NVIDIA GPUs
RUN if [ "$install_cuda" = "true" ]; then \
        apt-get update && apt-get install -y \
            wget \
            gnupg2 \
            && rm -rf /var/lib/apt/lists/* && \
        wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb && \
        dpkg -i cuda-keyring_1.1-1_all.deb && \
        rm cuda-keyring_1.1-1_all.deb && \
        apt-get update && apt-get install -y \
            cuda-toolkit-12-6 \
            && rm -rf /var/lib/apt/lists/*; \
    fi

# =============================================================================
# Stage 2: Select Base - Auto-detects platform during native build
# =============================================================================
# When building natively on Robot (ARM64), this will pull from base-arm64
# When building natively on Desktop (AMD64), this will pull from base-amd64
FROM base-$TARGETARCH AS base-selected

ARG ros_distro=humble
ARG gid
ARG uid
ARG username

# =============================================================================
# Stage 3: Base Setup - Locale and Essential Tools
# =============================================================================
FROM base-selected AS base-setup

# Set non-interactive installation
ENV DEBIAN_FRONTEND=noninteractive

# Setup Locale
RUN apt-get update && apt-get install -y locales && \
    locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Install base dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    wget \
    curl \
    gnupg2 \
    lsb-release \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Stage 4: ROS2 Installation
# =============================================================================
FROM base-setup AS ros2-install

ARG ros_distro

# Setup Isaac ROS2 APT repository (ARM64 only, will fail gracefully on AMD64)
RUN wget -qO - https://isaac.download.nvidia.com/isaac-ros/repos.key | apt-key add - && \
  grep -qxF "deb https://isaac.download.nvidia.com/isaac-ros/release-3 $(lsb_release -cs) release-3.0" /etc/apt/sources.list || \
  echo "deb https://isaac.download.nvidia.com/isaac-ros/release-3 $(lsb_release -cs) release-3.0" | tee -a /etc/apt/sources.list || true

# Setup Official ROS2 APT repository
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg && \
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null

# Install Core ROS 2 Humble packages
RUN apt-get update && apt-get install -y \
    ros-${ros_distro}-desktop-full \
    ros-dev-tools \
    && rm -rf /var/lib/apt/lists/*

# Install Isaac ROS common dependencies and VPI (ARM64 only, skip on AMD64)
# Note: VPI libraries are also part of the Jetson host system and will be mounted.
# This ensures any additional dependencies are met inside the container.
RUN apt-get update && \
    (apt-get install -y ros-${ros_distro}-isaac-ros-common || echo "Isaac ROS not available on this platform") && \
    rm -rf /var/lib/apt/lists/*

# Initialize rosdep
RUN rosdep init && \
    rosdep update

# =============================================================================
# Stage 5: Hardware Dependencies (Cameras, Sensors)
# =============================================================================
FROM ros2-install AS hardware-deps

# Realsense
ARG install_cuda
COPY scripts/install_realsense_library.sh /tmp/install_realsense_library.sh
COPY external/librealsense /tmp/librealsense
RUN if [ "$install_cuda" = "true" ]; then \
    apt-get update && apt-get install -y kmod && \
    /tmp/install_realsense_library.sh && \
    rm /tmp/install_realsense_library.sh; \
  else \
    echo "Skipping Realsense installation (CUDA not found)"; \
  fi

# MPU6050 Dependencies
RUN apt-get update && apt-get install -y \
  libi2c-dev \
  && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Stage 6: Application Dependencies
# =============================================================================
FROM hardware-deps AS app-deps

# UT AUTOmata dependencies
RUN apt-get update && apt-get install -y \
  libgoogle-glog-dev \
  libgflags-dev \
  liblua5.1-0-dev \
  libqt5websockets5-dev \
  libqt5opengl5-dev \
  tmux \
  tmuxinator \
  && rm -rf /var/lib/apt/lists/*

# GStreamer (for camera streaming)
RUN apt-get update && apt-get install -y \
  gstreamer1.0-plugins-base \
  gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-bad \
  gstreamer1.0-plugins-ugly \
  gstreamer1.0-libav \
  gstreamer1.0-tools \
  gstreamer1.0-x \
  && rm -rf /var/lib/apt/lists/*

# EGL, OpenGL libraries (for GUI applications)
RUN apt-get update && apt-get install -y \
  libegl1 \
  libegl1-mesa \
  libgles2-mesa \
  libgles2 \
  libglvnd-dev \
  libgl1-mesa-glx \
  libgl1-mesa-dri \
  mesa-utils-extra \
  && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Stage 7: Python and ML Dependencies
# =============================================================================
FROM app-deps AS python-ml

# pip
RUN apt-get update && apt-get install -y \
  python3-pip \
  python3-venv \
  python3-setuptools \
  python3-wheel \
  python3-colcon-clean \
  && rm -rf /var/lib/apt/lists/*
#RUN python3 -m ensurepip --default-pip && python3 -m pip install --upgrade pip

# pytorch (using CUDA 12.6 compatible version)
# Note: On ARM64/Jetson, you may need to use a different PyTorch build
RUN pip3 install torch==2.6.0 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu126 || \
    pip3 install torch torchvision torchaudio

# leg_detector
RUN pip3 install pykalman

# =============================================================================
# Stage 8: Navigation and SLAM Libraries
# =============================================================================
FROM python-ml AS nav-slam

# Libraries for graph nav and enml
RUN apt-get update && apt-get install -y \
  libfreeimage3 \
  libfreeimage-dev \
  libgtest-dev \
  libeigen3-dev \
  libjpeg8-dev \
  libgoogle-perftools-dev \
  libsuitesparse-dev \
  libblas-dev \
  libopencv-dev \
  liblapack-dev \
  libceres-dev \
  libtbb-dev \
  libncurses5-dev \
  libpopt-dev \
  cimg-dev \
  && rm -rf /var/lib/apt/lists/*

# # =============================================================================
# # iceoryx for shared memory communication (optional)
# # =============================================================================
# RUN apt-get update && apt-get install -y \
#     cmake \
#     g++ \
#     git \
#     libacl1-dev \
#     libncurses5-dev \
#     pkg-config \
#     && rm -rf /var/lib/apt/lists/*
# WORKDIR /tmp
# RUN git clone https://github.com/eclipse-iceoryx/iceoryx.git
# WORKDIR /tmp/iceoryx
# RUN cmake -Bbuild -Hiceoryx_meta -DBUILD_ALL=ON -DCMAKE_BUILD_TYPE=Release
# RUN cmake --build build --target install -j$(nproc)

# =============================================================================
# Stage 9: Utilities and Additional Scripts
# =============================================================================
FROM nav-slam AS utilities

# Utils
RUN apt-get update && apt-get install -y \
  vim \
  && rm -rf /var/lib/apt/lists/*

# Jetson-stats (ARM64 only, will fail gracefully on AMD64)
RUN pip3 install jetson-stats || echo "jetson-stats not available on this platform"

# ROS2 and other dependencies installation scripts
COPY scripts/ros2_deps.sh /tmp/ros2_deps.sh
RUN /tmp/ros2_deps.sh && rm /tmp/ros2_deps.sh

# So we can detect if we are in a container
ENV CONTAINER_NAME=roboracer_ws

# =============================================================================
# Stage 10: Final - User Creation and Configuration
# =============================================================================
FROM utilities AS final

ARG uid
ARG gid
ARG username
ARG ros_distro

ENV UID=$uid
ENV GID=$gid
ENV USERNAME=$username
ENV ROS_DISTRO=$ros_distro

# Create user and group, then configure sudo
RUN set -e && \
    # Create group if it doesn't exist
    getent group ${GID} || groupadd -g ${GID} ${USERNAME} && \
    # Handle user creation/modification
    if id ${UID} >/dev/null 2>&1; then \
        # User with this UID exists, modify it
        existing_user=$(id -nu ${UID}) && \
        usermod -l ${USERNAME} -d /home/${USERNAME} -m $existing_user 2>/dev/null || true && \
        usermod -g ${GID} ${USERNAME} 2>/dev/null || true; \
    else \
        # Create new user
        useradd -u ${UID} -g ${GID} -m -s /bin/bash ${USERNAME}; \
    fi && \
    # Ensure home directory exists and has correct ownership
    mkdir -p /home/${USERNAME} && \
    chown -R ${UID}:${GID} /home/${USERNAME} && \
    # Add to sudo group and configure passwordless sudo
    usermod -aG sudo ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${USERNAME} && \
    chmod 0440 /etc/sudoers.d/${USERNAME} && \
    visudo -c && \
    # Add the user to the video group for access to video devices
    usermod -aG video ${USERNAME}

# Create groups matching the host's group IDs, handling existing groups
RUN set -e && \
    # Handle i2c group (host GID: 116)
    if getent group 116 >/dev/null 2>&1; then \
        # Group with GID 116 exists, rename it if it's not i2c
        existing_group=$(getent group 116 | cut -d: -f1) && \
        if [ "$existing_group" != "i2c" ]; then \
            groupmod -n i2c $existing_group; \
        fi; \
    elif getent group i2c >/dev/null 2>&1; then \
        # i2c group exists with different GID, change its GID
        groupmod -g 116 i2c; \
    else \
        # Create new i2c group
        groupadd -g 116 i2c; \
    fi && \
    # Handle dialout group (host GID: 20)
    if getent group 20 >/dev/null 2>&1; then \
        # Group with GID 20 exists, rename it if it's not dialout
        existing_group=$(getent group 20 | cut -d: -f1) && \
        if [ "$existing_group" != "dialout" ]; then \
            groupmod -n dialout $existing_group; \
        fi; \
    elif getent group dialout >/dev/null 2>&1; then \
        # dialout group exists with different GID, change its GID
        groupmod -g 20 dialout; \
    else \
        # Create new dialout group
        groupadd -g 20 dialout; \
    fi && \
    # Add user to both groups
    usermod -aG i2c,dialout ${USERNAME}

# Copy bash_profile files and setup script
COPY docker/bash_profile.shared docker/bash_profile.robot docker/bash_profile.desktop scripts/setup_bash_profile.sh /tmp/
# Copy local bash_profile if it exists (gitignored, optional)
# Copy all bash_profile files from docker directory, including optional local one
COPY docker/bash_profile.* /tmp/
RUN chmod +x /tmp/setup_bash_profile.sh
# Combine shared and platform-specific bash_profile based on architecture
RUN ARCH=$(dpkg --print-architecture) && \
    /tmp/setup_bash_profile.sh ${ARCH} ${USERNAME} ${ROS_DISTRO} ${GID} && \
    rm -f /tmp/bash_profile.shared /tmp/bash_profile.robot /tmp/bash_profile.desktop /tmp/bash_profile.local /tmp/setup_bash_profile.sh


# Create .tmux.conf
RUN echo "set -g mouse on" >> /home/${USERNAME}/.tmux.conf && \
    echo "set -g history-limit 10000" >> /home/${USERNAME}/.tmux.conf && \
    chown ${USERNAME}:${GID} /home/${USERNAME}/.tmux.conf

# =============================================================================
# Switch to User Context
# =============================================================================

USER $username
ENV HOME=/home/$username
WORKDIR /home/$username
