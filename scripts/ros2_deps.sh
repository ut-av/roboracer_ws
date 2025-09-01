#!/bin/bash

# =============================================================================
# ROS2 Package Dependencies
# =============================================================================
apt-get update && apt-get install -y \
  ros-jazzy-urg-node \
  ros-jazzy-diagnostic-updater \
  ros-jazzy-nav-msgs
