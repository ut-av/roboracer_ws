# Orin ROS2 Workspace

## Firmware flashing and setup is in the [ot_orin_ros2](https://github.com/FRI-Self-Driving/ot_orin_ros2.git) repository.

## System dependencies

[autoenv](https://github.com/inishchith/autoenv) is used to automatically load the environment variables from the `.env` file.

  - It can be installed with the following command: `curl -#fLo- 'https://raw.githubusercontent.com/hyperupcall/autoenv/main/scripts/install.sh' | sh`

## Setup

This repository is designed to be run in a container based on the ROS2 Jazzy Desktop image.

### Dependencies

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




