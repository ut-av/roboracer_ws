#!/bin/bash

ROS_DISTRO=humble
# =============================================================================
# ROS2 Package Dependencies
# =============================================================================
apt-get update && apt-get install -y \
  ros-$ROS_DISTRO-diagnostic-updater \
  ros-$ROS_DISTRO-rmw-cyclonedds-cpp \
  ros-$ROS_DISTRO-tf2-geometry-msgs \
  ros-$ROS_DISTRO-tf2-sensor-msgs \
  ros-$ROS_DISTRO-slam-toolbox \
  ros-$ROS_DISTRO-urg-node\
  ros-$ROS_DISTRO-nav2-costmap-2d \
  ros-$ROS_DISTRO-nav2-bringup \
  ros-$ROS_DISTRO-nav2-map-server \
  ros-$ROS_DISTRO-nav2-navfn-planner \
  ros-$ROS_DISTRO-navigation2 \
  ros-$ROS_DISTRO-foxglove-bridge
