#!/bin/bash
# This script executes the correct simulator binary based on the OS

THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(realpath "$THIS_DIR/..")"

# Detect OS
if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null ; then
    OS_TYPE="win"
else
    UNAME_S=$(uname -s)
    case "$UNAME_S" in
        Linux*)     OS_TYPE="linux";;
        Darwin*)    OS_TYPE="macos";;
        CYGWIN*|MINGW*|MSYS*) OS_TYPE="win";;
        *)          OS_TYPE="linux"; echo "Unknown OS: $UNAME_S. Defaulting to linux.";;
    esac
fi

# Set the latest simulator version and set the sim_build_dir
VERSION="v1.0.1"
SIM_BUILD_DIR="$PROJECT_ROOT/simulator/simulator/build"

if [ "$OS_TYPE" == "win" ]; then
    SIMULATOR_PATH="$SIM_BUILD_DIR/win_${VERSION}/sim/Roboracer Simulator.exe"
elif [ "$OS_TYPE" == "macos" ]; then
    SIMULATOR_PATH="$SIM_BUILD_DIR/macos_${VERSION}/sim/Roboracer Simulator.app/Contents/MacOS/Roboracer Simulator"
elif [ "$OS_TYPE" == "linux" ]; then
    SIMULATOR_PATH="$SIM_BUILD_DIR/linux_${VERSION}/sim.x86_64"
else
    echo "Unknown OS or OS type $OS_TYPE is not supported yet."
fi

# Execute the simulator
if [ -f "$SIMULATOR_PATH" ]; then
    echo "Launching simulator for $OS_TYPE..."
    "$SIMULATOR_PATH" "$@"
else
    echo "Simulator binary not found at $SIMULATOR_PATH. Please ensure the simulator is installed correctly."
fi