# Orin ROS2 Workspace

> Note: This repository is designed to be run on an NVIDIA Jetson Orin device (Hardware mode) or in a Ubuntu 22.04 container (Simulation mode). The workspace must be named `roboracer_ws` and be located in the home directory, which the code relies on to find configuration files in the source tree.

## Firmware flashing and setup is in the [ot_orin_ros2](https://github.com/FRI-Self-Driving/ot_orin_ros2.git) repository.

## System dependencies

[autoenv](https://github.com/inishchith/autoenv) is used to automatically load the environment variables from the `.env` file.

  - It can be installed with the following command: `curl -#fLo- 'https://raw.githubusercontent.com/hyperupcall/autoenv/main/scripts/install.sh' | sh`

## Setup

This repository is designed to be run in a container based on the ROS2 Humble Desktop image or on the Jetson, a lt4 image with Jetpack.

1. Clone this repository into the home directory and name it `roboracer_ws`

```bash
git clone https://github.com/FRI-Self-Driving/roboracer_ws.git ~/roboracer_ws
```

2. Run the checkout script to update all dependencies

```bash
cd ~/roboracer_ws
./checkout.sh
```

3. Build the container

```bash
./container build
```

4. Enter the container and build the workspace

```bash
make
```

### Simulation Dependencies

> Only required for simulation mode (container). Skip this step if running on the Jetson Orin hardware.

Install [docker](https://docs.docker.com/get-docker/) or [podman](https://podman.io/getting-started/installation)

- Docker can be installed with the command: `curl -L https://gist.githubusercontent.com/nathantsoi/e668e83f8cadfa0b87b67d18cc965bd3/raw/setup_docker.sh | sudo bash
`

- Alternatively, Podman can be installed `sudo apt install -y podman nvidia-container-toolkit`


Both of these are virtualization tools that allow you to run the containerized infrastructure on your local machine.

### Build the container image

```
./container build
```

### Start the container and enter a shell in the container

```
./container shell
```




