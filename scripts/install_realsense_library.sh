#!/bin/bash

set -e
set -x

THIS_FILE=$(realpath $0)
ROOT=$(realpath $(dirname $THIS_FILE)/..)
PARENT_FOLDER=$(dirname $ROOT)

echo "Parent folder is ${PARENT_FOLDER}"

# if ROOT is "tmp"
if [ "$PARENT_FOLDER" == "/" ]; then
  cd /tmp/librealsense
else
  cd $ROOT/external/librealsense
fi

#LSMOD_INCLUDES_UVCVIDEO=$(lsmod | grep uvcvideo)
#if [ -z "$LSMOD_INCLUDES_UVCVIDEO" ]; then
#    echo "UVCVideo kernel module is not loaded"
#    echo "Ensure the kernel module is compiled and loaded by running the command OUTSIDE the docker container: "
#    echo "    ./scripts/install_realsense_kernel_path.sh"
#    exit 1
#fi

sudo apt-get install -y \
    git \
    libssl-dev \
    libusb-1.0-0-dev \
    libudev-dev \
    pkg-config \
    libgtk-3-dev \
    v4l-utils \
    libglu1-mesa-dev
./scripts/setup_udev_rules.sh  
rm -rf build && mkdir -p build && cd build  
cmake .. \
    -DBUILD_EXAMPLES=true \
    -DCMAKE_BUILD_TYPE=release \
    -DFORCE_RSUSB_BACKEND=false \
    -DBUILD_WITH_CUDA=true && make -j$(($(nproc)-1)) && \
    sudo make install