#!/usr/bin/env bash
# demo_drive_forward.sh — drive forward dengan Plan B (cmd_vel direct).
# Backup demo kalau Nav2 BT masih nakal. Predictable & auto-stop.
#
# Default: 0.5m maju @ 0.2 m/s = 2.5 detik (25 pesan @ 10 Hz)
# Override: ./demo_drive_forward.sh 0.3 0.15   # 0.3m, 0.15 m/s
#
# Aman karena: --times terbatas + autonomous_enabled di-disable di akhir.

set -e
DIST="${1:-0.5}"     # meter
VEL="${2:-0.2}"      # m/s
HZ=10

DURATION=$(awk "BEGIN{print $DIST/$VEL}")
TIMES=$(awk "BEGIN{print int($DURATION*$HZ + 0.5)}")

echo "[demo] maju $DIST m @ $VEL m/s = ${DURATION}s ($TIMES pesan @ ${HZ}Hz)"
echo "[demo] buka gerbang..."
ros2 param set /stm32_bridge autonomous_enabled true

echo "[demo] publishing cmd_vel..."
ros2 topic pub --rate "$HZ" --times "$TIMES" /cmd_vel geometry_msgs/msg/Twist \
  "{linear: {x: $VEL}, angular: {z: 0.0}}"

echo "[demo] tutup gerbang..."
ros2 param set /stm32_bridge autonomous_enabled false
echo "[demo] DONE"
