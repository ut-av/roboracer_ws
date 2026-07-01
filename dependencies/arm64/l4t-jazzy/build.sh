#!/bin/bash
# Build the L4T-matched ROS 2 Jazzy base image used by Jetson packages that need
# the host's Tegra GStreamer plugins (e.g. orin_rp2_csi CSI camera).
#
# This is a one-time / occasional build. Airfield's `base_image:` only references
# an image tag; it does not build it, so run this first on the Jetson.
set -euo pipefail

THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
IMAGE_TAG="${IMAGE_TAG:-roboracer/l4t-jazzy:r39.2}"

echo "Building $IMAGE_TAG from $THIS_DIR/Dockerfile ..."
docker build --network host --platform linux/arm64 \
    -t "$IMAGE_TAG" \
    -f "$THIS_DIR/Dockerfile" "$THIS_DIR"
echo "Done: $IMAGE_TAG"
