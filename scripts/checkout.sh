#!/bin/bash

set -x
set -e

THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(realpath "$THIS_DIR/..")"
SRC_DIR="$PROJECT_ROOT/src"

cd $SRC_DIR

function clone_or_pull {
    REPO_BRANCH=$1
    REPO_URL=$2
    REPO_DIR=$3
    REPO_DIR="$SRC_DIR/$REPO_DIR"

    if [ -d "$REPO_DIR/.git" ]; then
        echo "Pulling latest changes for $REPO_DIR"
        cd "$REPO_DIR"
        git pull origin "$REPO_BRANCH"
        git submodule update --init --recursive
        cd "$SRC_DIR"
    else
        echo "Cloning $REPO_URL into $REPO_DIR"
        git clone -b "$REPO_BRANCH" "$REPO_URL" "$REPO_DIR"
    fi
}

# common
clone_or_pull ros2 https://github.com/ut-amrl/amrl_maps.git amrl_maps
clone_or_pull master https://github.com/ut-amrl/amrl_msgs.git amrl_msgs

# ut_automata
clone_or_pull ros2 git@github.com:ut-amrl/ut_automata.git ut_automata

# graph nav
clone_or_pull ros2_dev git@github.com:ut-amrl/graph_navigation.git graph_navigation

# localization (enml)
clone_or_pull ros2_dev git@github.com:ut-amrl/enml.git enml

## Realsense
#REALSENSE_VERSION=v2.56.5-l4t36.4.4
#clone_or_pull $REALSENSE_VERSION https://github.com/nathantsoi/librealsense.git librealsense

# MPU6050
clone_or_pull main https://github.com/nathantsoi/ros2_mpu6050_driver.git ros2_mpu6050_driver