# Roboracer Workspace 

This repository is a collection of ROS2 packages that are used to control the Roboracer 1/10th scale autonomous racecar.

See the [UT AV Getting Started](https://ut-av.pages.dev/getting_started/) page for detailed setup and usage instructions.

## System requirements

This repository is designed to be run in two modes, which are automatically selected based on your detected platform.

1. Simuation mode is active when the detected platform is amd64 or MacOS arm64.

2. Hardware mode is active when an NVIDIA Jetson Orin device is detected,

> Note: For hardware mode, firmware flashing and setup is in the [ot_orin_ros2](https://github.com/FRI-Self-Driving/ot_orin_ros2.git) repository.

The workspace must be named `roboracer_ws` and be located in the user's home directory, which the code relies on to find configuration files in the source tree.


## Quickstart

Ensure you have [Docker](https://ut-av.pages.dev/tools/docker/) installed according to the [Roboracer Documentation]((https://ut-av.pages.dev/tools/docker/).

```bash
# navigate to the home directory
cd ~

# clone the roboracer_ws repository
git clone https://github.com/ut-av/roboracer_ws.git

# navigate to the roboracer_ws directory
cd roboracer_ws

# build the docker image
./container build

# enter the container
./container shell

# build the ros 2 workspace
make
```