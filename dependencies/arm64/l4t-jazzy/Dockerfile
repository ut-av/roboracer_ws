# L4T-matched ROS 2 Jazzy base image for Jetson (JetPack / L4T r39.2, Ubuntu 24.04 noble).
#
# Why this exists:
#   The host's Tegra GStreamer plugins (nvarguscamerasrc, nvvidconv, ...) are built
#   against the host userspace: Ubuntu 24.04 / GLib 2.80 / GStreamer 1.24. The stock
#   ros:humble base (Ubuntu 22.04 / GLib 2.72) is too old to load them
#   ("undefined symbol: g_once_init_leave_pointer"). This base matches the host so the
#   NVIDIA-container-runtime-mounted plugins load and CSI camera capture works.
#
# Build: see build.sh in this directory.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV ROS_DISTRO=jazzy

# --- Base tooling ---1
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg locales software-properties-common kmod \
    && locale-gen en_US en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*
ENV LANG=en_US.UTF-8

# --- NVIDIA L4T apt repo (r39.2), matching the host JetPack ---
# The Tegra multimedia/camera userspace is installed so versions match the
# host-mounted GStreamer plugins exactly.
COPY jetson-ota-public.asc /etc/apt/trusted.gpg.d/jetson-ota-public.asc
RUN echo "deb https://repo.download.nvidia.com/jetson/common r39.2 main" >  /etc/apt/sources.list.d/nvidia-l4t-apt-source.list \
 && echo "deb https://repo.download.nvidia.com/jetson/som r39.2 main"    >> /etc/apt/sources.list.d/nvidia-l4t-apt-source.list

# --- GLVND / EGL loaders + GStreamer (noble = GStreamer 1.24, GLib 2.80) ---
RUN apt-get update && apt-get install -y --no-install-recommends \
        libegl1 libgles2 libglvnd0 \
        libglib2.0-0t64 \
        libgstreamer1.0-0 libgstreamer-plugins-base1.0-0 \
        gstreamer1.0-tools gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
    && rm -rf /var/lib/apt/lists/*

# --- L4T multimedia / camera stack (Argus, nvarguscamerasrc, nvvidconv) ---
# nvidia-l4t-core's preinst checks /proc/device-tree/compatible for a Tegra SOC and
# aborts when it can't read it (the device tree is read-only / empty in a build
# sandbox). NVIDIA provides an official bypass: the marker file below makes the
# preinst "skip compatibility checking" and exit 0, which is the intended way to
# install L4T packages into a non-target rootfs/image.
RUN mkdir -p /opt/nvidia/l4t-packages \
 && touch /opt/nvidia/l4t-packages/.nv-l4t-disable-boot-fw-update-in-preinstall \
 && apt-get update && apt-get install -y --no-install-recommends \
        nvidia-l4t-core \
        nvidia-l4t-multimedia \
        nvidia-l4t-gstreamer \
        nvidia-l4t-camera \
    && rm -rf /var/lib/apt/lists/*

# --- Jetson CUDA-accelerated OpenCV ---
# The package does find_package(OpenCV) and uses CUDA OpenCV. The L4T libopencv-dev
# ships the CMake config + dev symlinks but NOT the versioned runtime libs
# (libopencv_core.so.4.8.0); those come from the nvidia-opencv meta package. Install
# both so find_package(OpenCV) resolves completely.
RUN mkdir -p /opt/nvidia/l4t-packages \
 && touch /opt/nvidia/l4t-packages/.nv-l4t-disable-boot-fw-update-in-preinstall \
 && apt-get update && apt-get install -y --no-install-recommends \
        nvidia-opencv libopencv-dev \
    && rm -rf /var/lib/apt/lists/*

# --- ROS 2 Jazzy (noble-native) ---
RUN add-apt-repository universe \
 && curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
        -o /usr/share/keyrings/ros-archive-keyring.gpg \
 && echo "deb [arch=arm64 signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu noble main" \
        > /etc/apt/sources.list.d/ros2.list \
 && apt-get update && apt-get install -y --no-install-recommends \
        ros-jazzy-ros-base \
        python3-colcon-common-extensions \
    && rm -rf /var/lib/apt/lists/*
