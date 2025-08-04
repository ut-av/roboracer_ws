# =============================================================================
# Base Image and Build Arguments
#  - Locked to a specific version of the ROS image to ensure reproducibility
#  - Updates here: https://hub.docker.com/r/osrf/ros/tags?name=jazzy-desktop
# =============================================================================
FROM osrf/ros:jazzy-desktop@sha256:20cce785f4b6810985a5a5617d66074d6a76f4ce8dde449d395198051f57cfbe

ARG gid
ARG uid
ARG username

# =============================================================================
# System Package Installation
# =============================================================================
RUN apt-get update && apt-get install -y \
  build-essential \
  git \
  python3-pip \
  python3-dev \
  python3-venv \
  python3-setuptools \
  python3-wheel \
  python3-numpy \
  python3-scipy \
  python3-matplotlib \
  python3-pandas \
  python3-tqdm \
  python3-pytest \
  python3-seaborn \
  python3-pygame \
  git \
  wget \
  vim \
  curl

# =============================================================================
# UT AUTOmata dependencies
# =============================================================================
RUN apt-get update && apt-get install -y \
  libgoogle-glog-dev \
  libgflags-dev \
  liblua5.1-0-dev \
  libqt5websockets5-dev \
  libqt5opengl5-dev

# =============================================================================
# User Creation and Configuration
# =============================================================================

ENV UID=$uid
ENV GID=$gid
ENV USERNAME=$username
RUN mkdir -p /home/${USERNAME} && \
    echo "${USERNAME}:x:${UID}:${GID}:${USERNAME},,,:/${USERNAME}:/bin/bash" >> /etc/passwd && \
    echo "${USERNAME}:x:${GID}:" >> /etc/group && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${USERNAME} && \
    chmod 0440 /etc/sudoers.d/${USERNAME} && \
    chown ${UID}:${GID} -R /home/${USERNAME} && \
    echo "export PATH=/home/${USERNAME}/.local/bin/:${PATH}" >> /home/${USERNAME}/.bash_profile && \
    echo "export LC_ALL=C.UTF-8" >> /home/${USERNAME}/.bash_profile && \
    echo "export LANG=C.UTF-8" >> /home/${USERNAME}/.bash_profile && \
    echo "source \"/opt/ros/$ROS_DISTRO/setup.bash\" --" >> /home/${USERNAME}/.bash_profile && \
    echo "export AMENT_PREFIX_PATH=/home/${USERNAME}/orin_ws/src/amrl_msgs/install:\$AMENT_PREFIX_PATH" >> /home/${USERNAME}/.bash_profile && \
    echo "export AMENT_PREFIX_PATH=/home/${USERNAME}/orin_ws/src/amrl_maps/install:\$AMENT_PREFIX_PATH" >> /home/${USERNAME}/.bash_profile && \
    echo "cd /home/${USERNAME}/orin_ws" >> /home/${USERNAME}/.bash_profile

# =============================================================================
# Switch to User Context
# =============================================================================

USER $username
ENV HOME /home/$username
WORKDIR /home/$username

# =============================================================================
# Python Package Installation
# =============================================================================

# System pip is being used
#RUN python3 -m ensurepip --default-pip
#RUN python3 -m pip install --upgrade pip
#RUN pip install \
#  pygame
#  torch \
#  torchvision \
#  torchaudio \
#  torchinfo \
#  torchmetrics \
#  protobuf \
#  tensorboard \
#  pytest \
#  pandas jupyterlab matplotlib seaborn unzip \
#  scikit-learn \
#  tqdm

# =============================================================================
# NumPy Upgrade (separate to ensure compatibility)
# =============================================================================
#RUN pip3 install numpy --upgrade
