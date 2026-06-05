#!/bin/bash
# =============================================================
# 01_setup_workspaces.sh
# =============================================================
# FIRST-TIME setup script untuk dual workspace pattern.
# Jalankan SEKALI saja saat baru deploy ke NUC.
#
# Apa yang dilakukan:
#   1. Install system dependencies (ROS 2 packages)
#   2. Build underlay workspace (rplidar_ros driver)
#   3. Build overlay workspace (amr_starter)
#   4. Setup .bashrc untuk auto-source workspace
#   5. Setup udev rules untuk hardware
#
# Usage:
#   bash ~/amr_starter/scripts/01_setup_workspaces.sh
# =============================================================

set -e
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date +%H:%M:%S)]${NC} $1"; }
ok() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}!${NC} $1"; }
err() { echo -e "${RED}✗${NC} $1"; exit 1; }

clear
echo -e "${BOLD}AMR Dual Workspace Setup${NC}"
echo "Target: $HOME"
echo ""
read -p "Ini akan modifikasi ~/.bashrc dan install dependencies. Lanjut? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# =============================================================
log "1. Verify base ROS 2 Humble installation"
# =============================================================
if ! command -v ros2 &>/dev/null; then
    err "ROS 2 not installed. Install Humble first: https://docs.ros.org/en/humble/Installation.html"
fi

source /opt/ros/humble/setup.bash
ok "ROS 2 Humble found"

# =============================================================
log "2. Install system dependencies"
# =============================================================
echo "Installing required ROS 2 packages..."
sudo apt update
sudo apt install -y \
    python3-colcon-common-extensions \
    python3-rosdep \
    python3-vcstool \
    ros-humble-slam-toolbox \
    ros-humble-nav2-bringup \
    ros-humble-nav2-common \
    ros-humble-rviz2 \
    ros-humble-tf2-tools \
    ros-humble-foxglove-bridge \
    ros-humble-joy \
    ros-humble-joint-state-publisher \
    ros-humble-robot-state-publisher \
    ros-humble-xacro \
    ros-humble-rmw-cyclonedds-cpp \
    python3-numpy \
    python3-scipy \
    python3-sklearn

# Initialize rosdep (idempotent)
sudo rosdep init 2>/dev/null || true
rosdep update

ok "System dependencies installed"

# =============================================================
log "3. Build UNDERLAY workspace (~/amr_underlay_ws)"
# =============================================================
if [ ! -d "$HOME/amr_underlay_ws" ]; then
    err "Underlay workspace not found at ~/amr_underlay_ws. Extract first."
fi

cd $HOME/amr_underlay_ws
echo "Running: rosdep install --from-paths src --ignore-src -r -y"
rosdep install --from-paths src --ignore-src -r -y || warn "rosdep had issues (might be OK if all already installed)"

echo "Building underlay..."
colcon build --symlink-install
ok "Underlay built successfully"

# Source the underlay
source $HOME/amr_underlay_ws/install/setup.bash

# =============================================================
log "4. Build OVERLAY workspace (~/amr_starter)"
# =============================================================
if [ ! -d "$HOME/amr_starter" ]; then
    err "Overlay workspace not found at ~/amr_starter. Extract first."
fi

cd $HOME/amr_starter
echo "Running: rosdep install --from-paths src --ignore-src -r -y"
rosdep install --from-paths src --ignore-src -r -y || warn "rosdep had issues (might be OK)"

echo "Building overlay..."
colcon build --symlink-install
ok "Overlay built successfully"

# =============================================================
log "5. Update ~/.bashrc"
# =============================================================
BASHRC_SNIPPET='
# === AMR Workspace Setup ===
if [ -f ~/amr_starter/.bashrc_amr ]; then
    source ~/amr_starter/.bashrc_amr
fi
# === End AMR Setup ==='

if grep -q "AMR Workspace Setup" "$HOME/.bashrc"; then
    ok ".bashrc already configured (skipping)"
else
    echo "$BASHRC_SNIPPET" >> "$HOME/.bashrc"
    ok "Added AMR workspace source to ~/.bashrc"
fi

# =============================================================
log "6. Setup udev rules (optional)"
# =============================================================
read -p "Setup udev rule for RPLIDAR (/dev/rplidar symlink)? (y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    UDEV_FILE="/etc/udev/rules.d/99-rplidar.rules"
    if [ -f "$UDEV_FILE" ]; then
        warn "udev rule already exists at $UDEV_FILE"
    else
        echo 'KERNEL=="ttyUSB*", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", MODE="0666", SYMLINK+="rplidar"' | sudo tee $UDEV_FILE
        sudo udevadm control --reload-rules
        sudo udevadm trigger
        ok "udev rule installed and reloaded"
    fi
fi

# =============================================================
log "DONE!"
# =============================================================
echo ""
echo -e "${GREEN}${BOLD}Setup complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Close and reopen terminal (atau: source ~/.bashrc)"
echo "  2. Run: bash ~/amr_starter/scripts/00_preflight_check.sh"
echo "  3. Connect hardware (STM32, LiDAR, joystick)"
echo "  4. Test: ros2 launch amr_bringup amr_launch.py"
echo ""
echo "If you need to rebuild later:"
echo "  - Underlay only:  cd ~/amr_underlay_ws && colcon build --symlink-install"
echo "  - Overlay only:   cd ~/amr_starter && colcon build --symlink-install"
echo "  - Clean rebuild:  rm -rf build install log && colcon build --symlink-install"
