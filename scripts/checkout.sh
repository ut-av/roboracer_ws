#!/bin/bash

THIS_FILE=$(realpath $0)
ROOT=$(dirname $THIS_FILE)/..

pushd $ROOT/src/
if [ ! -d $ROOT/src/amrl_maps ]; then
  git clone --branch ros2 https://github.com/ut-amrl/amrl_maps.git
fi

if [ ! -d $ROOT/src/amrl_msgs ]; then
  git clone https://github.com/ut-amrl/amrl_msgs.git
fi

if [ ! -d $ROOT/src/ut_automata ]; then
  git clone --branch ros2 git@github.com:ut-amrl/ut_automata.git --recurse-submodules
fi

REALSENSE_VERSION=v2.56.5-l4t36.4.4
if [ ! -d "$ROOT/external/librealsense" ]; then
  cd $ROOT/external
  git clone --branch $REALSENSE_VERSION https://github.com/nathantsoi/librealsense.git
fi

popd
