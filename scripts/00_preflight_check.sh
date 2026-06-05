#!/bin/bash
# =============================================================
# 00_preflight_check.sh
# =============================================================
# Verify environment dan hardware sebelum mulai kerja di lab.
# Jalankan SETIAP KALI setelah reboot NUC atau setup baru.
#
# Usage:
#   bash ~/amr_starter/scripts/00_preflight_check.sh
#
# Exit codes:
#   0  - semua hijau, siap kerja
#   1  - critical issues, harus diperbaiki
#   2  - warning only, bisa lanjut tapi ada yang missing
# =============================================================

set +e  # don't exit on error, kita mau report semua issue

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

OK_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

check_ok()    { echo -e "  ${GREEN}✓${NC} $1"; OK_COUNT=$((OK_COUNT+1)); }
check_warn()  { echo -e "  ${YELLOW}!${NC} $1"; WARN_COUNT=$((WARN_COUNT+1)); }
check_fail()  { echo -e "  ${RED}✗${NC} $1"; FAIL_COUNT=$((FAIL_COUNT+1)); }
section()     { echo -e "\n${BOLD}${BLUE}═══ $1 ═══${NC}"; }

clear
echo -e "${BOLD}AMR Pre-Flight Check${NC}"
echo "$(date '+%Y-%m-%d %H:%M:%S')"
echo "Host: $(hostname) | User: $(whoami)"

# =============================================================
section "1. ROS 2 Environment"
# =============================================================

if command -v ros2 &>/dev/null; then
    check_ok "ros2 command available"
    ROS_DISTRO_DETECTED=$(printenv ROS_DISTRO 2>/dev/null || echo "unknown")
    if [ "$ROS_DISTRO_DETECTED" = "humble" ]; then
        check_ok "ROS_DISTRO = humble"
    else
        check_warn "ROS_DISTRO = $ROS_DISTRO_DETECTED (expected: humble)"
    fi
else
    check_fail "ros2 command NOT found (source /opt/ros/humble/setup.bash)"
fi

if [ "$ROS_DOMAIN_ID" = "42" ]; then
    check_ok "ROS_DOMAIN_ID = 42"
else
    check_warn "ROS_DOMAIN_ID = '$ROS_DOMAIN_ID' (expected: 42)"
fi

if [ "$RMW_IMPLEMENTATION" = "rmw_cyclonedds_cpp" ]; then
    check_ok "RMW_IMPLEMENTATION = cyclonedds"
else
    check_warn "RMW_IMPLEMENTATION = '$RMW_IMPLEMENTATION' (expected: rmw_cyclonedds_cpp)"
fi

# =============================================================
section "2. Workspaces"
# =============================================================

if [ -d "$HOME/amr_underlay_ws/install" ]; then
    check_ok "Underlay workspace built: ~/amr_underlay_ws"
else
    check_warn "Underlay not built. Run: cd ~/amr_underlay_ws && colcon build"
fi

if [ -d "$HOME/amr_starter/install" ]; then
    check_ok "Active workspace built: ~/amr_starter"
    PKG_COUNT=$(ls $HOME/amr_starter/install 2>/dev/null | wc -l)
    check_ok "  $PKG_COUNT packages installed"
else
    check_fail "Active workspace NOT built. Run: cd ~/amr_starter && colcon build"
fi

# Check required packages
for pkg in amr_bringup amr_controller amr_description amr_failover amr_slam; do
    if [ -d "$HOME/amr_starter/install/$pkg" ]; then
        check_ok "Package installed: $pkg"
    else
        check_fail "Package missing: $pkg"
    fi
done

# =============================================================
section "3. Hardware Detection"
# =============================================================

# STM32
if lsusb 2>/dev/null | grep -q "0483:5740"; then
    check_ok "STM32 detected (USB 0483:5740)"
    if [ -e "/dev/serial/by-id/usb-STMicroelectronics_STM32_Virtual_ComPort_206833894152-if00" ]; then
        check_ok "  STM32 serial path: /dev/serial/by-id/usb-STMicroelectronics...if00"
    else
        check_warn "  STM32 serial-by-id path missing (check device ID)"
    fi
else
    check_fail "STM32 NOT detected (USB cable disconnected?)"
fi

# RPLIDAR
if lsusb 2>/dev/null | grep -q "10c4:ea60"; then
    check_ok "RPLIDAR USB-UART detected (CP2102N 10c4:ea60)"
    if [ -e "/dev/rplidar" ]; then
        check_ok "  /dev/rplidar symlink active (udev rule OK)"
    else
        check_warn "  /dev/rplidar symlink missing (run setup_network.sh atau udev reload)"
    fi
else
    check_warn "RPLIDAR NOT detected (LiDAR cable disconnected?)"
fi

# RealSense
if lsusb 2>/dev/null | grep -q "8086:0b5c"; then
    check_ok "RealSense D455 detected"
else
    check_warn "RealSense NOT detected (optional, kalau cuma manual drive bisa skip)"
fi

# Joystick
if [ -e "/dev/input/js0" ]; then
    check_ok "Joystick at /dev/input/js0"
    JOY_NAME=$(cat /sys/class/input/js0/device/name 2>/dev/null || echo "unknown")
    check_ok "  Name: $JOY_NAME"
else
    check_fail "Joystick NOT found (Bluetooth not paired?)"
fi

# =============================================================
section "4. System Packages"
# =============================================================

REQUIRED_PKGS=(
    "ros-humble-slam-toolbox"
    "ros-humble-nav2-bringup"
    "ros-humble-nav2-common"
    "ros-humble-rviz2"
    "ros-humble-tf2-tools"
    "ros-humble-foxglove-bridge"
    "ros-humble-joy"
)

MISSING_PKGS=()
for pkg in "${REQUIRED_PKGS[@]}"; do
    if dpkg -l 2>/dev/null | grep -q "^ii  $pkg "; then
        check_ok "$pkg"
    else
        check_fail "$pkg NOT installed"
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}To install missing packages, run:${NC}"
    echo "  sudo apt update && sudo apt install -y ${MISSING_PKGS[*]}"
fi

# =============================================================
section "5. Python Dependencies (for Visual Regression)"
# =============================================================

for module in numpy scipy sklearn; do
    if python3 -c "import $module" 2>/dev/null; then
        VERSION=$(python3 -c "import $module; print($module.__version__)" 2>/dev/null)
        check_ok "$module $VERSION"
    else
        check_warn "$module not available (needed only for visual regression)"
    fi
done

# =============================================================
section "Summary"
# =============================================================

TOTAL=$((OK_COUNT + WARN_COUNT + FAIL_COUNT))
echo ""
echo "  Results: ${GREEN}${OK_COUNT} OK${NC}, ${YELLOW}${WARN_COUNT} warnings${NC}, ${RED}${FAIL_COUNT} failures${NC} of $TOTAL checks"
echo ""

if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "${RED}${BOLD}Critical issues found. Fix these before starting work.${NC}"
    exit 1
elif [ $WARN_COUNT -gt 0 ]; then
    echo -e "${YELLOW}${BOLD}Warnings present but not blocking. You can proceed with caution.${NC}"
    exit 2
else
    echo -e "${GREEN}${BOLD}All systems go. Ready for lab work.${NC}"
    exit 0
fi
