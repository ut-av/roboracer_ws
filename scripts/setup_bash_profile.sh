#!/bin/bash
# Script to combine bash_profile files
# This handles the optional bash_profile.local file

ARCH=$1
USERNAME=$2
ROS_DISTRO=$3
GID=$4

# Start with shared configuration
cp /tmp/bash_profile.shared /home/${USERNAME}/.bash_profile

# Append platform-specific configuration
if [ "$ARCH" = "arm64" ]; then
    cat /tmp/bash_profile.robot >> /home/${USERNAME}/.bash_profile
else
    cat /tmp/bash_profile.desktop >> /home/${USERNAME}/.bash_profile
fi


# Replace placeholders with actual values
sed -i "s|__USERNAME__|${USERNAME}|g" /home/${USERNAME}/.bash_profile
sed -i "s|__ROS_DISTRO__|${ROS_DISTRO}|g" /home/${USERNAME}/.bash_profile

chown ${USERNAME}:${GID} /home/${USERNAME}/.bash_profile

