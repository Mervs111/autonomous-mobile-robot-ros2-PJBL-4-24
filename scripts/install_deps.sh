#!/bin/bash
# =====================================================================
# AMR Mobile Robot Ackermann Indoor - Dependency Installer
# =====================================================================
# Otomatis install semua paket ROS 2 + Python yang dibutuhkan AMR.
# Tested on: Ubuntu 22.04 LTS + ROS 2 Humble Hawksbill
# =====================================================================

set -e

echo "=================================================="
echo "  AMR Dependency Installer"
echo "=================================================="

# Check ROS 2 sourced
if [ -z "$ROS_DISTRO" ]; then
    echo "[ERROR] ROS 2 belum di-source. Run: source /opt/ros/humble/setup.bash"
    exit 1
fi
echo "[OK] ROS distro: $ROS_DISTRO"

# Check Ubuntu 22.04
. /etc/os-release
if [ "$VERSION_ID" != "22.04" ]; then
    echo "[WARN] Detected Ubuntu $VERSION_ID, script tested for 22.04 only."
fi

echo ""
echo "[1/4] Apt update..."
sudo apt update

echo ""
echo "[2/4] Install ROS 2 packages..."
sudo apt install -y \
    ros-humble-rclcpp \
    ros-humble-rclpy \
    ros-humble-geometry-msgs \
    ros-humble-sensor-msgs \
    ros-humble-nav-msgs \
    ros-humble-std-msgs \
    ros-humble-visualization-msgs \
    ros-humble-tf2-ros \
    ros-humble-tf2-tools \
    ros-humble-cv-bridge \
    ros-humble-image-transport \
    ros-humble-message-filters \
    ros-humble-xacro \
    ros-humble-joint-state-publisher \
    ros-humble-joint-state-publisher-gui \
    ros-humble-robot-state-publisher \
    ros-humble-rviz2 \
    ros-humble-joy \
    ros-humble-teleop-twist-joy \
    ros-humble-slam-toolbox \
    ros-humble-nav2-bringup \
    ros-humble-nav2-map-server \
    ros-humble-nav2-lifecycle-manager \
    ros-humble-nav2-amcl \
    ros-humble-nav2-controller \
    ros-humble-nav2-planner \
    ros-humble-nav2-behaviors \
    ros-humble-nav2-bt-navigator \
    ros-humble-nav2-smac-planner \
    ros-humble-nav2-regulated-pure-pursuit-controller \
    ros-humble-nav2-velocity-smoother \
    ros-humble-realsense2-camera \
    ros-humble-realsense2-description

echo ""
echo "[3/4] Install Python packages..."
pip3 install --user --upgrade \
    numpy \
    opencv-python \
    scikit-learn \
    joblib \
    matplotlib \
    pandas

echo ""
echo "[4/4] Install librealsense2 (Intel SDK)..."
if ! command -v realsense-viewer &> /dev/null; then
    sudo mkdir -p /etc/apt/keyrings
    curl -sSf https://librealsense.intel.com/Debian/librealsense.pgp \
        | sudo tee /etc/apt/keyrings/librealsense.pgp > /dev/null
    echo "deb [signed-by=/etc/apt/keyrings/librealsense.pgp] https://librealsense.intel.com/Debian/apt-repo $(lsb_release -cs) main" \
        | sudo tee /etc/apt/sources.list.d/librealsense.list
    sudo apt update
    sudo apt install -y librealsense2-dkms librealsense2-utils
else
    echo "[OK] librealsense2 already installed."
fi

echo ""
echo "=================================================="
echo "  All dependencies installed successfully!"
echo "=================================================="
echo ""
echo "Next steps:"
echo "  cd ~/amr_ws"
echo "  colcon build --symlink-install"
echo "  source install/setup.bash"
echo "  ros2 launch amr_bringup amr_full.launch.py"
echo ""
