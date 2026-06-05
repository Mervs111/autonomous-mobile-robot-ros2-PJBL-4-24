#!/bin/bash
# =====================================================================
# install_rtabmap_deps.sh
# =====================================================================
# Install RTAB-Map ROS 2 packages di NUC untuk paket amr_3d_mapping.
# Run sekali, sebelum colcon build paket baru.
#
# Estimasi waktu: 5-10 menit (tergantung internet kampus).
# Disk: ~500 MB.
# =====================================================================

set -e  # exit on error
echo "=== Install RTAB-Map ROS 2 Dependencies ==="
echo ""

# 1. Verify ROS 2 Humble installed
if [ -z "$ROS_DISTRO" ]; then
    echo "ERROR: ROS 2 belum di-source. Run: source /opt/ros/humble/setup.bash"
    exit 1
fi

if [ "$ROS_DISTRO" != "humble" ]; then
    echo "ERROR: Script ini untuk ROS 2 Humble (ditemukan: $ROS_DISTRO)"
    exit 1
fi

echo "[1/4] ROS 2 distro: $ROS_DISTRO  OK"
echo ""

# 2. Update apt
echo "[2/4] sudo apt update..."
sudo apt update
echo ""

# 3. Install RTAB-Map packages
echo "[3/4] Install ros-humble-rtabmap* packages..."
sudo apt install -y \
    ros-humble-rtabmap-slam \
    ros-humble-rtabmap-sync \
    ros-humble-rtabmap-util \
    ros-humble-rtabmap-viz \
    ros-humble-rtabmap-ros \
    ros-humble-rtabmap-msgs \
    ros-humble-rtabmap-launch \
    ros-humble-rtabmap-conversions

echo ""

# 4. Verify installation
echo "[4/4] Verify installation..."
ros2 pkg list | grep rtabmap

echo ""
echo "=== RTAB-Map installation COMPLETE ==="
echo ""
echo "Next steps:"
echo "  cd ~/amr_starter"
echo "  colcon build --packages-select amr_3d_mapping amr_visual_regression"
echo "  source install/setup.bash"
echo ""
echo "Quick test (standalone line segments, butuh /scan publishing):"
echo "  ros2 launch amr_visual_regression line_segments.launch.py"
echo ""
echo "Full system dengan RTAB-Map mapping mode:"
echo "  ros2 launch amr_bringup amr_full.launch.py \\"
echo "      use_rtabmap:=true rtabmap_mode:=mapping \\"
echo "      use_line_segments:=true"
