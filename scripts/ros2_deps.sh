#!/bin/bash

ROS_DISTRO=humble
# =============================================================================
# ROS2 Package Dependencies
# =============================================================================
apt-get update && apt-get install -y \
  ros-$ROS_DISTRO-urg-node \
  ros-$ROS_DISTRO-diagnostic-updater \
  ros-$ROS_DISTRO-nav-msgs \
  ros-$ROS_DISTRO-nav2-costmap-2d \
  ros-$ROS_DISTRO-foxglove-bridge
