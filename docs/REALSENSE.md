# Using the realsense requires 2 steps

1. Build and install the kernel modules (on the host, not inside the container): `./scripts/install_realsense_kernel_patch.sh`

2. Build and install the librealsense library (in the container, this happens when the container builds): `./scripts/install_realsense_library.sh`