#!/bin/bash

THIS_FILE=$(realpath $0)
ROOT=$(dirname $THIS_FILE)

pushd $ROOT/src/
git clone https://github.com/ut-amrl/amrl_maps.git
git clone https://github.com/ut-amrl/amrl_msgs.git
git clone git@github.com:ut-amrl/ut_automata.git --recurse-submodules
popd