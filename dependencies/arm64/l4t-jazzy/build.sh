#!/bin/bash
# Build the L4T-matched ROS 2 Jazzy base image used by Jetson packages that need
# the host's Tegra GStreamer plugins (e.g. orin_rp2_csi CSI camera).
#
# The L4T version is read off THIS host and pinned into the image, so the
# container's Tegra userspace matches the host's exactly. Nothing here is tied to
# a specific JetPack release: a car on a newer JetPack simply produces a
# differently-tagged image, with no edit to this script or the Dockerfile.
#
# Why pin at all — NVIDIA's apt dists are major.minor and accumulate point
# releases (r39.2 serves both 39.2.0 / JetPack 7.2 and 39.2.1 / JetPack 7.2.1),
# so naming the dist does not pin the version. An unpinned install takes whatever
# is newest and drifts ahead of the host as soon as NVIDIA ships a patch release.
#
# This is a one-time / occasional build, run ON THE JETSON. Airfield's
# `base_image:` only references an image tag; it does not build it.
#
# Env overrides:
#   L4T_VERSION=39.2.1-20260806224157   build against a version other than the host's
#   IMAGE_TAG=my/base:tag               override the derived tag
set -euo pipefail

THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_YAML="$( cd "$THIS_DIR/../../.." && pwd )/airfield.yaml"

# --- 1. Which L4T version are we matching? ---------------------------------
if [ -z "${L4T_VERSION:-}" ]; then
    L4T_VERSION="$(dpkg-query -W -f='${Version}' nvidia-l4t-core 2>/dev/null || true)"
fi
if [ -z "$L4T_VERSION" ]; then
    cat >&2 <<'EOF'
ERROR: could not read nvidia-l4t-core's version from this host.

This image has to match a Jetson's Tegra userspace, so run it on the car, or
name the target version explicitly:

    L4T_VERSION=39.2.1-20260806224157 dependencies/arm64/l4t-jazzy/build.sh
EOF
    exit 1
fi

L4T_RELEASE="${L4T_VERSION%%-*}"          # 39.2.1-20260806224157 -> 39.2.1
case "$L4T_RELEASE" in                    # NVIDIA's dists are major.minor only
    *.*.*) L4T_REPO="r${L4T_RELEASE%.*}" ;;   # 39.2.1 -> r39.2
    *)     L4T_REPO="r${L4T_RELEASE}"    ;;
esac
IMAGE_TAG="${IMAGE_TAG:-roboracer/l4t-jazzy:r${L4T_RELEASE}}"

# --- 2. Pre-flight: is that exact version still published? -----------------
# NVIDIA prunes old point releases eventually. Catch that here with a readable
# message instead of a cryptic apt failure part-way through the image build.
PKG_URL="https://repo.download.nvidia.com/jetson/som/dists/${L4T_REPO}/main/binary-arm64/Packages"
if command -v curl >/dev/null 2>&1; then
    if AVAIL="$(curl -fsS --max-time 20 "$PKG_URL" 2>/dev/null)"; then
        CORE_VERSIONS="$(printf '%s\n' "$AVAIL" \
            | awk '/^Package: nvidia-l4t-core$/{f=1} f&&/^Version: /{print $2; f=0}')"
        if ! printf '%s\n' "$CORE_VERSIONS" | grep -qxF "$L4T_VERSION"; then
            {
                echo "ERROR: nvidia-l4t-core=$L4T_VERSION is not published in $L4T_REPO."
                echo "This host's L4T release has most likely been pruned upstream."
                echo
                echo "Still available in $L4T_REPO:"
                printf '%s\n' "$CORE_VERSIONS" | sed 's/^/    /'
                echo
                echo "Pick one and re-run:"
                echo "    L4T_VERSION=<version> $0"
                echo "Note that building against a version other than the host's"
                echo "re-introduces the skew this pin exists to prevent — the"
                echo "host-mounted Argus/nvbuf libraries may not match."
            } >&2
            exit 1
        fi
    else
        echo "WARN: could not fetch $PKG_URL — skipping the availability pre-check." >&2
    fi
fi

# --- 3. Build ---------------------------------------------------------------
echo "Host L4T version : $L4T_VERSION"
echo "NVIDIA apt dist  : $L4T_REPO"
echo "Image tag        : $IMAGE_TAG"
echo

docker build --network host --platform linux/arm64 \
    --build-arg L4T_VERSION="$L4T_VERSION" \
    --build-arg L4T_REPO="$L4T_REPO" \
    -t "$IMAGE_TAG" \
    -f "$THIS_DIR/Dockerfile" "$THIS_DIR"
echo "Done: $IMAGE_TAG"

# --- 4. Does the project actually point at what we just built? -------------
# `base_image:` is one fleet-wide value, so a car on a different JetPack builds a
# tag nothing references. Say so here rather than letting the launch fail later
# with an opaque "image not found" (the scripts set AIRFIELD_NO_PULL=1, so Docker
# won't go looking for it in a registry either).
if [ -f "$PROJECT_YAML" ]; then
    CONFIGURED="$(sed -n 's/^base_image:[[:space:]]*//p' "$PROJECT_YAML" | head -1)"
    if [ -n "$CONFIGURED" ] && [ "$CONFIGURED" != "$IMAGE_TAG" ]; then
        cat >&2 <<EOF

WARN: this car is not on the fleet's JetPack version.
      airfield.yaml base_image : $CONFIGURED
      built on this host       : $IMAGE_TAG

      Either reflash the car to the fleet version, or point base_image: at
      $IMAGE_TAG in $PROJECT_YAML for local use (don't commit that).
      If the whole fleet has moved, update base_image: once and rebuild on each car.
EOF
    fi
fi
