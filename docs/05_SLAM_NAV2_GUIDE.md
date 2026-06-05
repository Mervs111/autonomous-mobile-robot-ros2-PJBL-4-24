# 05 — SLAM & Nav2 Guide

> Detail tuning SLAM Toolbox dan Nav2 untuk Mobile Robot Ackermann Indoor.

---

## 1. SLAM Toolbox — Mode Mapping

```bash
ros2 launch amr_slam slam_mapping.launch.py
```

### Parameter penting (`config/slam_mapping.yaml`)

| Parameter | Default | Tuning |
|---|---|---|
| `resolution` | 0.05 (5 cm) | Naikkan ke 0.1 kalau peta terlalu detail |
| `max_laser_range` | 12.0 | RPLIDAR C1 efektif sampai 10 m |
| `minimum_travel_distance` | 0.20 m | Turunkan ke 0.10 untuk lebih sering update |
| `loop_search_maximum_distance` | 3.0 | Naikkan jika ruangan besar |
| `loop_match_minimum_chain_size` | 10 | Turunkan untuk loop closure agresif |

### Tips mapping yang bagus
1. Drive **perlahan** (max 0.3 m/s) — scan-matching butuh waktu konvergen.
2. **Lewati setiap koridor 2×** — sekali pergi, sekali pulang, supaya loop closure punya overlap besar.
3. **Hindari jalan diagonal** — pencitraan LiDAR jadi distorsi.
4. **Mulai & akhiri di posisi sama** kalau bisa (loop closure terbaik).

### Save & verify map
```bash
ros2 run nav2_map_server map_saver_cli -f ~/amr_ws/maps/lab_map
ls -la ~/amr_ws/maps/
# Harus ada: lab_map.pgm + lab_map.yaml
```

Cek `lab_map.pgm` — buka pakai image viewer. Map yang baik:
- Dinding tampak **lurus** dan **kontinu**
- Sudut ruangan tampak **tegak lurus**
- Tidak ada "double walls" (tanda loop closure gagal)

---

## 2. SLAM Toolbox — Mode Localization

```bash
ros2 launch amr_slam slam_localization.launch.py map_name:=lab_map
```

**Initial pose:** Setelah launch, robot harus tahu posisi awalnya.
- Kalau robot di-start di posisi sama dengan saat mapping → otomatis localize OK
- Kalau di posisi berbeda → set "2D Pose Estimate" di RViz

---

## 3. Nav2 — Tuning untuk Ackermann

### Global Planner: SmacPlannerHybrid
Pakai **DUBIN** motion model (forward only) atau **REEDS_SHEPP** (allow reverse).

```yaml
GridBased:
  motion_model_for_search: "DUBIN"
  minimum_turning_radius: 0.5    # Sesuai geometri 4WD-Ackermann
  reverse_penalty: 2.0           # Higher = jarang mundur
```

### Local Controller: RegulatedPurePursuit
Cocok untuk Ackermann karena tidak perlu rotate-in-place.

```yaml
FollowPath:
  desired_linear_vel: 0.4         # Mulai 0.3, naikkan kalau stable
  lookahead_dist: 0.6             # Lebih besar = smooth, lebih kecil = responsif
  use_rotate_to_heading: false    # WAJIB false untuk Ackermann!
  allow_reversing: true
```

### Costmap tuning
```yaml
local_costmap:
  inflation_radius: 0.45    # 35 cm robot + 10 cm safety
  robot_radius: 0.35
```

Kalau robot terlalu sering "stuck" di koridor sempit:
- Turunkan `inflation_radius` ke 0.30
- Naikkan resolusi local costmap ke 0.025

---

## 4. Topic Remap untuk Failover

Penting: Nav2 publish `cmd_vel` di-remap ke `/cmd_vel_nav` (lihat `nav2.launch.py`).
Ini supaya `failover_controller` bisa arbitrasi antara Nav2 dan VR.

```python
# Di nav2.launch.py:
SetRemap(src='/cmd_vel', dst='/cmd_vel_nav'),
```

---

## 5. Tanpa IMU — Strategi Kompensasi

Karena AMR ini **TIDAK pakai IMU**, wheel odometry akan drift terutama yaw.

**Yang membantu:**
1. SLAM Toolbox **scan-matching aggressive** (parameter sudah tuned).
2. Loop closure aktif (`do_loop_closing: true`).
3. Drive perlahan saat mapping.

**Yang tidak help:**
- Tidak ada `robot_localization` EKF (akan ditambah saat IMU dipasang nanti).

**Future work:** Tambah BNO055 + EKF untuk yaw stability.

---

## 6. Troubleshooting Spesifik

### SLAM "yaw drift" — peta miring
- **Penyebab:** wheel slip + tanpa IMU
- **Solusi:** drive lebih lambat saat mapping; pastikan wheel_radius akurat (UMBmark)

### Nav2 "Failed to compute path"
- Cek apakah goal di area yang sudah ter-map dan free
- Cek `tolerance` di planner config (default 0.25 m)
- Pastikan tidak ada inflation yang menutupi seluruh free space

### Robot "stuck" tidak gerak meskipun ada path
- Cek `desired_linear_vel` di FollowPath — minimum 0.1
- Cek apakah `cmd_vel_nav` betul publishing: `ros2 topic echo /cmd_vel_nav`
- Cek apakah failover_controller forward ke `/cmd_vel`: `ros2 topic echo /cmd_vel`

### Robot oscillating saat mendekati goal
- `xy_goal_tolerance` terlalu kecil (default 0.25) — naikkan ke 0.30
- `lookahead_dist` terlalu pendek — naikkan
