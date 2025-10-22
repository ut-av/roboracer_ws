# =============================================================================
# Base Image and Build Arguments
#  - Docker container must match jetpack version installed on Jetson
#    - Image list: https://catalog.ngc.nvidia.com/orgs/nvidia/containers/l4t-base/tags
#  - ROS2 Humble is used for Jetson Orin OpenCV and Python version compatibility
# =============================================================================
# JetPack container: includes CUDA, cuDNN, TensorRT, VPI, Jetson Multimedia, and so on
ARG BASE_IMAGE=nvcr.io/nvidia/l4t-jetpack:r36.4.0
# ML container: includes TensorFlow, PyTorch, JupyterLab, and other popular ML and data science frameworks such as scikit-learn, scipy, and Pandas pre-installed in a Python environment.
#ARG BASE_IMAGE=nvcr.io/nvidia/l4t-ml:r36.2.0-py3
FROM ${BASE_IMAGE}

ARG ros_distro=humble
ARG gid
ARG uid
ARG username

# Set non-interactive installation
ENV DEBIAN_FRONTEND=noninteractive

# Setup Locale
RUN apt-get update && apt-get install -y locales \
    && locale-gen en_US.UTF-8
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

# Setup Isaac ROS2 APT repository
RUN wget -qO - https://isaac.download.nvidia.com/isaac-ros/repos.key | apt-key add - && \
  grep -qxF "deb https://isaac.download.nvidia.com/isaac-ros/release-3 $(lsb_release -cs) release-3.0" /etc/apt/sources.list || \
  echo "deb https://isaac.download.nvidia.com/isaac-ros/release-3 $(lsb_release -cs) release-3.0" | tee -a /etc/apt/sources.list

# Setup Offical ROS2 APT repository
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg && \
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null

# Install Core ROS 2 Humble packages
RUN apt-get update && apt-get install -y \
    ros-humble-desktop-full \
    ros-dev-tools \
    && rm -rf /var/lib/apt/lists/*

# Install Isaac ROS common dependencies and VPI
# Note: VPI libraries are also part of the Jetson host system and will be mounted.
# This ensures any additional dependencies are met inside the container.
RUN apt-get update && apt-get install -y \
    ros-humble-isaac-ros-common \
    && rm -rf /var/lib/apt/lists/*

# Initialize rosdep
RUN rosdep init && \
    rosdep update

# =============================================================================
# Realsense
# =============================================================================
RUN apt-get update && apt-get install -y \
  kmod
COPY scripts/install_realsense_library.sh /tmp/install_realsense_library.sh
COPY external/librealsense /tmp/librealsense
RUN /tmp/install_realsense_library.sh && rm /tmp/install_realsense_library.sh

# =============================================================================
# UT AUTOmata dependencies
# =============================================================================
RUN apt-get update && apt-get install -y \
  libgoogle-glog-dev \
  libgflags-dev \
  liblua5.1-0-dev \
  libqt5websockets5-dev \
  libqt5opengl5-dev \
  tmux \
  tmuxinator \
  && rm -rf /var/lib/apt/lists/*

# =============================================================================
# GStreamer (for camera streaming)
# =============================================================================
RUN apt-get update && apt-get install -y \
  gstreamer1.0-plugins-base \
  gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-bad \
  gstreamer1.0-plugins-ugly \
  gstreamer1.0-libav \
  gstreamer1.0-tools \
  gstreamer1.0-x \
  && rm -rf /var/lib/apt/lists/*

# =============================================================================
# EGL, OpenGL libraries (for GUI applications)
# =============================================================================
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
# MPU6050 Dependencies
# =============================================================================
RUN apt-get update && apt-get install -y \
  libi2c-dev \
  && rm -rf /var/lib/apt/lists/*

# =============================================================================
# pip
# =============================================================================
RUN apt-get update && apt-get install -y \
  python3-pip \
  python3-venv \
  python3-setuptools \
  python3-wheel \
  && rm -rf /var/lib/apt/lists/*
#RUN python3 -m ensurepip --default-pip && python3 -m pip install --upgrade pip

# =============================================================================
# pytorch
# =============================================================================
RUN pip3 install torch==2.6.0 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu126

# =============================================================================
# Libraries for graph nav and enml
# =============================================================================
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

# =============================================================================
# ROS2 and other dependencies installation scripts
# =============================================================================
COPY scripts/ros2_deps.sh /tmp/ros2_deps.sh
RUN /tmp/ros2_deps.sh && rm /tmp/ros2_deps.sh

# So we can detect if we are in a container
ENV CONTAINER_NAME=roboracer_ws

# =============================================================================
# User Creation and Configuration
# =============================================================================
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

RUN echo "export PATH=/home/${USERNAME}/.local/bin/:${PATH}" >> /home/${USERNAME}/.bash_profile && \
    echo "export LC_ALL=C.UTF-8" >> /home/${USERNAME}/.bash_profile && \
    echo "export LANG=C.UTF-8" >> /home/${USERNAME}/.bash_profile && \
    echo "alias killros2='killall -9 ros2 _ros2_daemon rviz2 gzserver robot_state_publisher gzclient controller_server lifecycle_manager'" >> /home/${USERNAME}/.bash_profile && \
    echo "source \"/opt/ros/${ROS_DISTRO}/setup.bash\" --" >> /home/${USERNAME}/.bash_profile && \
    echo "source \"/home/${USERNAME}/roboracer_ws/install/setup.bash\" --" >> /home/${USERNAME}/.bash_profile && \
    echo "export AMENT_PREFIX_PATH=/home/${USERNAME}/roboracer_ws/src/amrl_msgs/install:\$AMENT_PREFIX_PATH" >> /home/${USERNAME}/.bash_profile && \
    echo "export AMENT_PREFIX_PATH=/home/${USERNAME}/roboracer_ws/src/amrl_maps/install:\$AMENT_PREFIX_PATH" >> /home/${USERNAME}/.bash_profile && \
    echo "export ROS_VERSION=2" >> /home/${USERNAME}/.bash_profile && \
    echo "export PS1='\\[\\e[0;32m\\][docker]:\\u@\\h:\\w\\$ \\[\\e[0m\\]'" >> /home/${USERNAME}/.bash_profile && \
    echo "export LD_LIBRARY_PATH=/usr/local/lib/python3.10/dist-packages/torch/lib:/usr/local/cuda/lib64:\$LD_LIBRARY_PATH" >> /home/${USERNAME}/.bash_profile && \
    echo "export Torch_DIR=/usr/local/lib/python3.10/dist-packages/torch/share/cmake/Torch:\$Torch_DIR" >> /home/${USERNAME}/.bash_profile && \
    echo "export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST" >> /home/${USERNAME}/.bash_profile && \
    echo "export CMAKE_BUILD_MODE=Hardware" >> /home/${USERNAME}/.bash_profile && \
    echo "cd /home/${USERNAME}/roboracer_ws" >> /home/${USERNAME}/.bash_profile


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
