#!/bin/bash
# =============================================================
# 02_quick_test.sh
# =============================================================
# Interactive test script untuk verify tiap komponen workspace
# secara bertahap. Jalankan setelah setup_workspaces selesai.
#
# Test sequence:
#   1. ROS 2 environment
#   2. Hardware detection
#   3. Joystick input
#   4. STM32 bridge
#   5. Odometry
#   6. LiDAR
#   7. RealSense (optional)
#
# Usage:
#   bash ~/amr_starter/scripts/02_quick_test.sh
# =============================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

CLEANUP_PIDS=()

cleanup() {
    echo -e "\n${YELLOW}Cleaning up running processes...${NC}"
    for pid in "${CLEANUP_PIDS[@]}"; do
        kill $pid 2>/dev/null
    done
    pkill -f "ros2 run joy joy_node" 2>/dev/null
    pkill -f "ros2 run amr_controller" 2>/dev/null
    pkill -f "ros2 launch rplidar_ros" 2>/dev/null
    sleep 1
    exit 0
}
trap cleanup INT TERM EXIT

pause_continue() {
    echo ""
    read -p "Press ENTER to continue, or Ctrl+C to abort..."
    echo ""
}

clear
echo -e "${BOLD}AMR Quick Test Script${NC}"
echo "Tests run sequentially with manual verification between each."
echo ""
echo "This will start ROS 2 nodes in background. Press Ctrl+C anytime to cleanup."
pause_continue

# =============================================================
echo -e "${BOLD}${BLUE}═══ Test 1: ROS 2 Environment ═══${NC}"
# =============================================================
echo "Domain ID: $ROS_DOMAIN_ID"
echo "RMW: $RMW_IMPLEMENTATION"
echo ""

if ! command -v ros2 &>/dev/null; then
    echo -e "${RED}FAIL: ros2 command not available${NC}"
    exit 1
fi

ros2 pkg list 2>/dev/null | grep -c amr_ > /tmp/amr_pkg_count
PKG_COUNT=$(cat /tmp/amr_pkg_count)
echo "AMR packages found: $PKG_COUNT (expected: 6)"

if [ "$PKG_COUNT" -lt 5 ]; then
    echo -e "${RED}FAIL: Not enough AMR packages. Did you build?${NC}"
    exit 1
fi
echo -e "${GREEN}PASS${NC}"
pause_continue

# =============================================================
echo -e "${BOLD}${BLUE}═══ Test 2: Hardware Detection ═══${NC}"
# =============================================================
echo "Checking USB devices..."
echo ""

if lsusb | grep -q "0483:5740"; then
    echo -e "  ${GREEN}✓${NC} STM32 detected"
else
    echo -e "  ${RED}✗${NC} STM32 NOT detected"
fi

if lsusb | grep -q "10c4:ea60"; then
    echo -e "  ${GREEN}✓${NC} LiDAR USB-UART detected"
else
    echo -e "  ${YELLOW}!${NC} LiDAR NOT detected (warning, can skip LiDAR tests)"
fi

if [ -e /dev/input/js0 ]; then
    echo -e "  ${GREEN}✓${NC} Joystick at /dev/input/js0"
else
    echo -e "  ${RED}✗${NC} Joystick NOT detected"
fi

pause_continue

# =============================================================
echo -e "${BOLD}${BLUE}═══ Test 3: Joystick Input ═══${NC}"
# =============================================================
echo "Starting joy_node..."
ros2 run joy joy_node &
JOY_PID=$!
CLEANUP_PIDS+=($JOY_PID)
sleep 2

echo "Now press buttons / move sticks on the joystick."
echo "You should see message output below. Press Ctrl+C in terminal when done."
echo ""
echo "Watching /joy topic for 10 seconds..."
timeout 10 ros2 topic echo /joy --once 2>/dev/null | head -20
echo ""

if ros2 topic hz /joy --window 20 2>/dev/null | head -2 | grep -q "average rate"; then
    echo -e "${GREEN}PASS: Joystick publishing${NC}"
else
    echo -e "${RED}FAIL: Joystick not publishing. Check Bluetooth pairing.${NC}"
fi

kill $JOY_PID 2>/dev/null
sleep 1
pause_continue

# =============================================================
echo -e "${BOLD}${BLUE}═══ Test 4: STM32 Bridge ═══${NC}"
# =============================================================
echo "Starting joy_node + stm32_bridge..."
ros2 run joy joy_node &
JOY_PID=$!
CLEANUP_PIDS+=($JOY_PID)

ros2 run amr_controller stm32_bridge &
STM_PID=$!
CLEANUP_PIDS+=($STM_PID)
sleep 3

echo ""
echo "Verifying topics..."
echo ""

if ros2 topic list 2>/dev/null | grep -q "/encoder"; then
    echo -e "  ${GREEN}✓${NC} /encoder topic exists"
else
    echo -e "  ${RED}✗${NC} /encoder topic MISSING"
fi

echo ""
echo "Checking encoder publish rate (should be ~20 Hz)..."
timeout 5 ros2 topic hz /encoder --window 20 2>/dev/null | tail -3

echo ""
echo "Sample /encoder data:"
timeout 3 ros2 topic echo /encoder --once 2>/dev/null
echo ""

echo -e "${YELLOW}Manual verification: dorong roda dengan tangan (motor mati).${NC}"
echo "Encoder value harus berubah. Press ENTER kalau sudah test."
read

kill $JOY_PID $STM_PID 2>/dev/null
sleep 1
pause_continue

# =============================================================
echo -e "${BOLD}${BLUE}═══ Test 5: Odometry ═══${NC}"
# =============================================================
echo "Starting joy_node + stm32_bridge + odometry_publisher..."
ros2 run joy joy_node &
JOY_PID=$!
CLEANUP_PIDS+=($JOY_PID)

ros2 run amr_controller stm32_bridge &
STM_PID=$!
CLEANUP_PIDS+=($STM_PID)

ros2 run amr_controller odometry_publisher &
ODOM_PID=$!
CLEANUP_PIDS+=($ODOM_PID)
sleep 4

echo ""
echo "Verifying /odom..."
timeout 5 ros2 topic hz /odom --window 20 2>/dev/null | tail -3
echo ""

echo "Sample /odom pose:"
timeout 3 ros2 topic echo /odom --once 2>/dev/null | grep -A 3 "position:"
echo ""

echo "TF tree:"
ros2 run tf2_tools view_frames -o /tmp/frames 2>&1 | tail -2
echo "(saved to /tmp/frames.pdf — open to inspect)"
echo ""

echo -e "${YELLOW}Manual verification: dorong roda 1 putaran (~1496 pulsa).${NC}"
echo "position.x harus mendekati 0.487 m (keliling roda)."
echo "Press ENTER kalau sudah test."
read

kill $JOY_PID $STM_PID $ODOM_PID 2>/dev/null
sleep 1
pause_continue

# =============================================================
echo -e "${BOLD}${BLUE}═══ Test 6: LiDAR (optional) ═══${NC}"
# =============================================================
read -p "Test LiDAR? (y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Starting RPLIDAR..."
    ros2 launch rplidar_ros rplidar_c1_launch.py &
    LIDAR_PID=$!
    CLEANUP_PIDS+=($LIDAR_PID)
    sleep 4

    if ros2 topic list | grep -q "/scan"; then
        echo -e "  ${GREEN}✓${NC} /scan topic published"
    fi

    echo ""
    echo "Verifying /scan rate (should be ~10 Hz)..."
    timeout 5 ros2 topic hz /scan --window 10 2>/dev/null | tail -3
    echo ""

    echo "Sample /scan ranges (first 10 of 500 points):"
    timeout 3 ros2 topic echo /scan --once 2>/dev/null | grep -A 1 "ranges:" | head -5
    echo ""

    kill $LIDAR_PID 2>/dev/null
    sleep 2
fi

# =============================================================
echo -e "${BOLD}${GREEN}═══ All Tests Done ═══${NC}"
# =============================================================
echo ""
echo "Next steps:"
echo "  1. Test full launch:    ros2 launch amr_bringup amr_launch.py"
echo "  2. SLAM mapping:        ros2 launch amr_slam slam_mapping.launch.py"
echo "  3. Record session:      amr_record demo"
echo "  4. Open RViz at laptop: rviz2 (with ROS_DOMAIN_ID=42)"
