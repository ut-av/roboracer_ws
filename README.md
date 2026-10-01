# Roboracer Workspace 

This repository is a collection of ROS2 packages that are used to control the Roboracer 1/10th scale autonomous racecar.

See the [UT AV Getting Started](https://ut-av.pages.dev/getting_started/) page for detailed setup and usage instructions.

## System requirements

This repository is designed to be run in two modes, which are automatically selected based on your detected platform.

1. Simuation mode is active when the detected platform is amd64 or MacOS arm64.

2. Hardware mode is active when an NVIDIA Jetson Orin device is detected,

> Note: For hardware mode on the F1TENTH cars, flashing and setup are covered in [Car Bring-Up](https://ut-av.pages.dev/hardware/car_bringup/).

The workspace must be named `roboracer_ws` and be located in the user's home directory, which the code relies on to find configuration files in the source tree.


## Quickstart

This workspace is built and launched with [airfield](https://github.com/airfield/airfield),
which wraps each ROS 2 package in its own container image and launches the stack
as a multi-pane tmux session. On the car (Jetson Orin) the whole navigation stack
comes up with one command once the one-time setup is done.

> **How the workspace is built, launched, configured and updated, including
> setting up a fresh machine and the Jetson base image, is in the
> [Airfield guide](https://ut-av.pages.dev/tools/airfield/). Read that first on a
> fresh machine — the steps below assume airfield is already installed.**

```bash
# clone into the home directory (this exact path is REQUIRED — see note above)
cd ~
git clone https://github.com/ut-av/roboracer_ws.git
cd roboracer_ws

# one-time, on the Jetson: build the L4T-matched base image. The script reads
# this host's L4T version, pins the image to it, and tags it accordingly
# (JetPack 7.2.1 -> roboracer/l4t-jazzy:r39.2.1). It warns if that tag differs
# from airfield.yaml's base_image, i.e. if this car is on a different JetPack.
dependencies/arm64/l4t-jazzy/build.sh

# build the ROS 2 packages ONCE into the shared .airfield/workspace/install
# (serial, memory-capped so it does not OOM the Jetson).
scripts/build

# launch the navigation stack: cleans stale state, (re)builds if needed, launches.
scripts/up            # same as: scripts/up navstack

# tear everything down cleanly (stops orphaned containers, frees the display).
scripts/down
```

`scripts/up` regenerates and starts the airfield/tmux session for the plan in
[plans/navstack.yaml](plans/navstack.yaml). To regenerate the tmux config without
launching anything, use `airfield project up navstack --no-launch`.

> The legacy `./container` + `make` workflow has been replaced by airfield and is
> no longer maintained.