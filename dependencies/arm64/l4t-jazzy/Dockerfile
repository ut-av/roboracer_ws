# L4T-matched ROS 2 Jazzy base image for Jetson (Ubuntu 24.04 noble).
#
# Why this exists:
#   The host's Tegra GStreamer plugins (nvarguscamerasrc, nvvidconv, ...) are built
#   against the host userspace: Ubuntu 24.04 / GLib 2.80 / GStreamer 1.24. The stock
#   ros:humble base (Ubuntu 22.04 / GLib 2.72) is too old to load them
#   ("undefined symbol: g_once_init_leave_pointer"). This base matches the host so the
#   NVIDIA-container-runtime-mounted plugins load and CSI camera capture works.
#
# How the version matching works:
#   No L4T release is hardcoded in this file. build.sh reads it off the host
#   (nvidia-l4t-core's installed version) and passes it in as L4T_VERSION and
#   L4T_REPO, so every car builds a base matching itself and a new JetPack needs
#   no edit here. The apt dist is NOT a version pin on its own: NVIDIA's dists are
#   major.minor and accumulate point releases (r39.2 serves both 39.2.0 /
#   JetPack 7.2 and 39.2.1 / JetPack 7.2.1), so an unpinned install silently
#   drifts ahead of the host the moment NVIDIA ships a patch release.
#
# Build: run build.sh in this directory. A bare `docker build` will fail — the
# build args are required and have no defaults, on purpose.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV ROS_DISTRO=jazzy

# --- Base tooling ---
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg locales software-properties-common kmod \
    && locale-gen en_US en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*
ENV LANG=en_US.UTF-8

# --- NVIDIA L4T apt repo, matching the host JetPack ---
# Both the dist (r39.2, r39.3, ...) and the exact package version come from the
# host via build.sh. Declared here rather than before the generic layers above so
# a version change doesn't invalidate the Ubuntu tooling cache.
#   nvidia-l4t-core / -camera / -multimedia  live in the `som` dist
#   nvidia-l4t-gstreamer / nvidia-opencv     live in `common`
ARG L4T_VERSION
ARG L4T_REPO
RUN test -n "${L4T_VERSION}" && test -n "${L4T_REPO}" || { \
        echo "ERROR: L4T_VERSION and L4T_REPO build args are required." >&2; \
        echo "Run dependencies/arm64/l4t-jazzy/build.sh, not 'docker build'." >&2; \
        exit 1; }

COPY jetson-ota-public.asc /etc/apt/trusted.gpg.d/jetson-ota-public.asc
RUN echo "deb https://repo.download.nvidia.com/jetson/common ${L4T_REPO} main" >  /etc/apt/sources.list.d/nvidia-l4t-apt-source.list \
 && echo "deb https://repo.download.nvidia.com/jetson/som ${L4T_REPO} main"    >> /etc/apt/sources.list.d/nvidia-l4t-apt-source.list

# Hold every nvidia-l4t-* package at the host's exact version. The explicit
# `=${L4T_VERSION}` on the installs below covers the four packages we name; this
# pin also covers anything they pull in transitively, and priority >1000 beats a
# "newer" candidate in the same dist.
#
# Note that an apt pin only RAISES the priority of versions it matches — it never
# makes anything uninstallable. So the nvidia-l4t-* packages on a different
# version scheme (nvidia-l4t-kernel* are "6.8.12-tegra-39.2.1-<build>",
# nvidia-l4t-cudadebuggingsupport is on CUDA's "13.2-<build>") simply don't match
# and resolve normally. That's intended: none of them are part of the
# host-mounted plugin surface this image has to match.
RUN printf 'Package: nvidia-l4t-*\nPin: version %s\nPin-Priority: 1001\n' "${L4T_VERSION}" \
        > /etc/apt/preferences.d/l4t-version-pin

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
        nvidia-l4t-core="${L4T_VERSION}" \
        nvidia-l4t-multimedia="${L4T_VERSION}" \
        nvidia-l4t-gstreamer="${L4T_VERSION}" \
        nvidia-l4t-camera="${L4T_VERSION}" \
    && rm -rf /var/lib/apt/lists/*

# --- Jetson CUDA-accelerated OpenCV ---
# The package does find_package(OpenCV) and uses CUDA OpenCV. The L4T libopencv-dev
# ships the CMake config + dev symlinks but NOT the versioned runtime libs
# (libopencv_core.so.4.8.0); those come from the nvidia-opencv meta package. Install
# both so find_package(OpenCV) resolves completely.
#
# Deliberately NOT pinned to L4T_VERSION: nvidia-opencv is versioned on the JetPack
# scheme (7.2.1-b49), not the L4T one, and unlike the Tegra plugins these libs live
# inside the image rather than being mounted in from the host — so they don't have
# to match the host build. The apt pin above only matches nvidia-l4t-*, so it
# leaves these alone.
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
