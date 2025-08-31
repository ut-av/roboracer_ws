#!/bin/bash

THIS_FILE=$(realpath $0)
ROOT=$(dirname $THIS_FILE)/..

cd $ROOT/external/librealsense
./scripts/patch-realsense-ubuntu-L4T.sh