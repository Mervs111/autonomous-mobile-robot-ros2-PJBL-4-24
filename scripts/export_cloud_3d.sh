#!/bin/bash
# =============================================================================
# export_cloud_3d.sh — Export 3D point cloud dari RTAB-Map database
# =============================================================================
# Usage:
#   ./export_cloud_3d.sh                        → export dari db default
#   ./export_cloud_3d.sh ~/maps/lab_3d.db       → export dari db tertentu
#   ./export_cloud_3d.sh ~/maps/lab_3d.db --ply → force PLY format
#
# Output: ~/maps/export_YYYYMMDD_HHMMSS/
#   - cloud_map.ply      → full 3D point cloud (buka di CloudCompare/MeshLab)
#   - cloud_ground.ply   → ground plane saja
#   - cloud_obstacles.ply → obstacle points saja
# =============================================================================

set -e

DB_PATH="${1:-~/.ros/rtabmap.db}"
DB_PATH="${DB_PATH/#\~/$HOME}"     # expand ~ ke full path
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUT_DIR="$HOME/maps/export_${TIMESTAMP}"

echo "================================================================"
echo " RTAB-Map 3D Cloud Exporter"
echo " Database : $DB_PATH"
echo " Output   : $OUT_DIR"
echo "================================================================"

if [ ! -f "$DB_PATH" ]; then
    echo "[ERROR] Database tidak ditemukan: $DB_PATH"
    echo "  Pastikan mapping sudah selesai dan file .db tersimpan."
    exit 1
fi

mkdir -p "$OUT_DIR"

# Source ROS environment
source ~/amr_underlay_ws/install/setup.bash 2>/dev/null || true
source ~/amr_starter/install/setup.bash 2>/dev/null || true

echo ""
echo "[1/3] Export full 3D cloud → cloud_map.ply ..."
rtabmap-export \
    --cloud \
    --output-dir "$OUT_DIR" \
    --output "cloud_map" \
    "$DB_PATH" && echo "  ✓ cloud_map.ply saved" || echo "  ✗ Export gagal"

echo ""
echo "[2/3] Export dengan ground segmentation ..."
rtabmap-export \
    --cloud \
    --ground_normals_up 0.9 \
    --output-dir "$OUT_DIR" \
    --output "cloud_segmented" \
    "$DB_PATH" && echo "  ✓ cloud_segmented.ply saved" || echo "  ✗ Skip (opsional)"

echo ""
echo "[3/3] Info database ..."
rtabmap-info "$DB_PATH" 2>/dev/null | grep -E "Nodes|Links|Words" || true

echo ""
echo "================================================================"
echo " SELESAI. File tersimpan di: $OUT_DIR"
echo ""
echo " Cara visualisasi:"
echo "   CloudCompare (gratis): cloudcompare.org → buka .ply"
echo "   MeshLab     (gratis): meshlab.net      → buka .ply"
echo "   rtabmap-viz         : File → Open → pilih .db"
echo ""
echo " Cara buka di rtabmap_viz (live dari db):"
echo "   export DISPLAY=:0"
echo "   rtabmap-viz"
echo "   → File → Open → $DB_PATH"
echo "   → View → 3D Map panel"
echo "================================================================"
