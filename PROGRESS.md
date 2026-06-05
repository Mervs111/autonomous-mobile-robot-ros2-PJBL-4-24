# PROGRESS — AMR Mobile Robot Ackermann (24-Day Sprint)

> Daily checklist + log untuk timeline 24 hari (3 minggu 3 hari).
> Tandai checkbox saat task selesai. Update di akhir setiap hari.

**Mahasiswa:** Muhammad Al Azhar Faradis (NRP 2040241017)
**Period:** Day 1 = ____________  •  Demo Day 24 = ____________

---

## Week 1 — Foundation (Day 1–7)

### Day 1 — Network & Repository Setup
- [ ] Run `sudo bash scripts/setup_network.sh "WiFi-Kampus-ITS"`
- [ ] Reboot NUC 3× → verify auto-reconnect <60 detik
- [ ] Setup SSH key: `ssh-keygen` di laptop, `ssh-copy-id azhar@<NUC_IP>`
- [ ] Test ROS 2 multi-machine atau setup Discovery Server (Plan A)
- [ ] Backup plan: kabel Ethernet langsung NUC↔Laptop (Plan C tested)
- [ ] `git clone` repository ke `~/amr_ws/src/`
- **Output:** _________________________________________________

### Day 2 — RPLIDAR C1 Integration
- [ ] Verify rplidar_ros package compile: `colcon build --packages-select rplidar_ros`
- [ ] Identify USB serial path: `ls -l /dev/serial/by-id/`
- [ ] Update `RPLIDAR_PORT` di `sensors_launch.py` jika perlu
- [ ] Test: `ros2 launch amr_bringup sensors_launch.py use_camera:=false`
- [ ] Verify `/scan` topic publishing 10 Hz
- [ ] Visualize di RViz: LaserScan display, fixed_frame=`laser_frame`
- **Output:** _________________________________________________

### Day 3 — RealSense D455 Integration
- [ ] Install librealsense2 (script setup mungkin sudah handle)
- [ ] Test: `realsense-viewer` (GUI native Intel) — RGB + depth muncul
- [ ] Test: `ros2 launch amr_bringup sensors_launch.py use_lidar:=false`
- [ ] Verify topics: `/camera/color/image_raw`, `/camera/depth/image_rect_raw`
- [ ] Visualize di RViz: Image + DepthCloud
- **Output:** _________________________________________________

### Day 4 — URDF + TF Tree
- [ ] Build amr_description: `colcon build --packages-select amr_description`
- [ ] Test: `ros2 launch amr_description view_robot.launch.py`
- [ ] Verify TF tree: `ros2 run tf2_tools view_frames`
- [ ] Pastikan `base_footprint → base_link → {wheels, sensors}` complete
- [ ] Geser slider steering joints di GUI → wheels berputar di RViz
- **Output:** _________________________________________________

### Day 5 — Wheel Odometry Publisher
- [ ] Build amr_controller: `colcon build --packages-select amr_controller`
- [ ] Run: `ros2 run amr_controller odometry_publisher.py`
- [ ] Verify auto-detect log: "Encoder mode detected: DELTA" atau "CUMULATIVE"
- [ ] Drive robot manual via joystick, verify `/odom` di rqt_topic_monitor
- [ ] RViz: Odometry display path → robot icon harus track gerakan
- **Output:** _________________________________________________

### Day 6 — UMBmark Wheel Calibration
- [ ] Tempel meteran 5 m di lantai
- [ ] Run: `python3 scripts/calibrate_wheel.py --distance 5.0`
- [ ] Drive lurus 5 m, Ctrl+C → catat diameter aktual
- [ ] Repeat 5 trial, ambil rata-rata
- [ ] Update `wheel_radius` di URDF dan launch parameter odometry
- [ ] Re-test: drive 5 m, error pose < 5 cm
- **Output:** wheel_radius = ______ m  (vs default 0.0775)

### Day 7 — Dataset Collection (Visual Regression Path B)
- [ ] Build amr_visual_regression: `colcon build --packages-select amr_visual_regression`
- [ ] Verify: `ros2 run amr_visual_regression data_collector_node`
- [ ] Recording session di lab (~45 menit total):
  - [ ] 5 menit: lurus di koridor
  - [ ] 10 menit: belok kiri-kanan random
  - [ ] 10 menit: dekat-jauh dinding
  - [ ] 10 menit: hindari obstacle (kursi, kardus)
  - [ ] 10 menit: eksplorasi ruang kelas penuh
- [ ] Verify dataset: `ls ~/datasets/run_*/labels.csv | head` ~ 27.000 frame
- **Output:** Dataset folder path = ____________________

---

## Week 2 — SLAM + VR Training (Day 8–14)

### Day 8 — SLAM Toolbox Mapping
- [ ] Build amr_slam: `colcon build --packages-select amr_slam`
- [ ] Launch: `ros2 launch amr_bringup amr_full.launch.py slam_mode:=mapping`
- [ ] Drive robot perlahan keliling ruangan, lihat `/map` terbentuk di RViz
- [ ] Save map: `ros2 run nav2_map_server map_saver_cli -f ~/amr_ws/maps/lab_map`
- [ ] Verify file `lab_map.pgm` + `lab_map.yaml` ada
- **Output:** Map saved at: _________________________

### Day 9 — Nav2 Stack
- [ ] Verify nav2-bringup installed
- [ ] Launch: `ros2 launch amr_bringup amr_full.launch.py slam_mode:=localization use_nav2:=true map_name:=lab_map`
- [ ] Set goal pose dari RViz "2D Goal Pose" tool
- [ ] Verify SmacPlannerHybrid generate path Ackermann-feasible
- [ ] Robot mengikuti path tanpa nabrak (mungkin perlu tuning)
- **Output:** _________________________________________________

### Day 10 — Feature Engineering VR
- [ ] Read code `amr_visual_regression/feature_extractor.py`
- [ ] Run self-test: `python3 -m amr_visual_regression.feature_extractor`
- [ ] Test pada 1-5 frame dataset:
  ```python
  import numpy as np
  d = np.load('datasets/run_xxx/depth_000010.npy')
  from amr_visual_regression.feature_extractor import extract_features
  print(extract_features(d))  # 36 features
  ```
- [ ] Plot heatmap features untuk verify makna semantik
- **Output:** _________________________________________________

### Day 11 — Training VR Model
- [ ] Run: `python3 src/amr_visual_regression/scripts/train.py --dataset ~/datasets/run_xxx --output ~/models`
- [ ] Wait ~5-15 menit (tergantung jumlah frame)
- [ ] Cek `train_report.txt`: target MAE_steer < 0.1, R² > 0.5
- [ ] Cek `scatter_plot.png`: prediction vs ground truth bagus
- [ ] If R² < 0.3 → re-collect dataset Day 13 atau add augmentation
- **Output:** R² steering = _____, R² velocity = _____

### Day 12 — VR Inference Node
- [ ] Test inference standalone: `ros2 launch amr_visual_regression vr_inference.launch.py`
- [ ] Verify `/cmd_vel_visual` publishing 10 Hz
- [ ] Echo `/vr_debug` JSON: steering, velocity, min_depth makes sense
- [ ] Test live di robot (matikan SLAM): drive autonomous via VR saja
- [ ] Tune `safety_min_depth` (start 0.4 m, adjust)
- **Output:** _________________________________________________

### Day 13 — VR Field Testing
- [ ] Test scenario:
  - [ ] Diam menghadap dinding → harus stop atau belok
  - [ ] Tengah lorong → jalan lurus
  - [ ] Obstacle 1 m di depan → belok hindari
  - [ ] Area baru (tidak di dataset) → measure generalization
- [ ] Identify failure modes
- [ ] If perlu: augment dataset & re-train
- **Output:** _________________________________________________

### Day 14 — Buffer & Mid-Project Documentation
- [ ] Catch-up task slip dari Day 1-13
- [ ] Update README.md dengan progress
- [ ] Commit ke GitHub: `git add . && git commit -m "Day 14: mid-project checkpoint"`
- [ ] Backup dataset + models ke external HDD / cloud
- [ ] Draft `docs/04_VISUAL_REGRESSION_GUIDE.md`
- **Output:** _________________________________________________

---

## Week 3 — Integration + Polish (Day 15–21)

### Day 15 — Failover Controller Implementation
- [ ] Build amr_failover: `colcon build --packages-select amr_failover`
- [ ] Test standalone: `ros2 launch amr_failover failover.launch.py`
- [ ] Verify `/failover_status` JSON publishing
- [ ] RViz: tambah Marker display, lihat sphere indicator (hijau=SLAM)
- **Output:** _________________________________________________

### Day 16 — Failover Testing (5 Scenarios)
- [ ] Scenario 1: Tutup LiDAR → switch ke VISUAL_FALLBACK dalam 2 detik
- [ ] Scenario 2: Buka LiDAR → kembali SLAM_ACTIVE setelah 5 detik
- [ ] Scenario 3: Pegang R1 deadman → JOY_OVERRIDE immediate
- [ ] Scenario 4: Obstacle <30 cm → EMERGENCY_STOP
- [ ] Scenario 5: Robot crash + restart → recovery ke SLAM_ACTIVE
- [ ] Tuning timeout & hysteresis values jika perlu
- **Output:** _________________________________________________

### Day 17 — End-to-End Integration Test #1
- [ ] Launch full system: `amr_full.launch.py slam_mode:=localization use_nav2:=true use_vr:=true use_failover:=true map_name:=lab_map`
- [ ] Verify semua node running, no error log
- [ ] 5-menit autonomous wandering test
- [ ] Catat behavior, transitions
- **Output:** _________________________________________________

### Day 18 — Stress Test + Edge Cases
- [ ] 15-menit continuous run
- [ ] Monitor: `htop`, frame rates, memory
- [ ] Test area baru (force VR fallback)
- [ ] Test recovery
- **Output:** CPU avg = ____, mem leak? = ____

### Day 19 — Documentation Sprint #1
- [ ] Tulis `docs/01_USER_MANUAL.md` lengkap dengan:
  - [ ] Foto anatomi robot (label NUC, STM32, sensor, dll)
  - [ ] Prosedur startup checklist
  - [ ] Prosedur mapping
  - [ ] Prosedur wandering mode
  - [ ] Shutdown procedure
- [ ] Tulis `docs/02_DEVELOPMENT_GUIDE.md`
- **Output:** _________________________________________________

### Day 20 — Documentation Sprint #2
- [ ] Tulis `docs/03_HARDWARE_GUIDE.md` (wiring, BoM, pinout)
- [ ] Tulis `docs/06_FAILOVER_GUIDE.md`
- [ ] Tulis `docs/07_TROUBLESHOOTING.md`
- **Output:** _________________________________________________

### Day 21 — Demo Rehearsal #1
- [ ] Setup demo from scratch (cold boot NUC)
- [ ] Time setup: target <10 menit
- [ ] Demo flow 10 menit: mapping intro → autonomous → failover demo → emergency stop
- [ ] Rekam video demo as backup
- [ ] Latihan pitch presentasi 15 menit
- **Output:** _________________________________________________

---

## Buffer Days (Day 22–24)

### Day 22 — Polish & Bug Fixing
- [ ] Fix issues from Day 21
- [ ] Polish kode: docstrings, comments
- [ ] Polish RViz config: clean panel layout
- [ ] Add badges to README

### Day 23 — Final Test + Foto/Video
- [ ] Full test di lab kondisi senyata mungkin
- [ ] Foto robot dari berbagai sudut untuk dokumentasi
- [ ] Video demo full 10 menit dengan narrasi
- [ ] GitHub release tag `v1.0.0-demo`

### Day 24 — DEMO DAY!
- [ ] Pagi: setup awal, sanity check
- [ ] Pre-demo: charge baterai full, restart NUC, fresh state
- [ ] Sore: presentasi + demo dosen
- [ ] Backup: video Day 23 ready

---

## Daily Cheat Sheet

```bash
# Setiap akhir hari (jam 22:00):
cd ~/amr_ws
git add .
git commit -m "Day X: [milestone selesai]"
git push

# Update PROGRESS.md ini, tandai checkbox
# Backup dataset, models, maps ke /media/external/
```

## Risk Mitigation Reminder

| Risk | Mitigation |
|------|-----------|
| WiFi kampus blokir multicast | Plan C: kabel Ethernet langsung |
| LiDAR tidak terbaca | Cek baudrate 460800, voltage 5V |
| RealSense USB error | Gunakan USB 3.0, cable berkualitas |
| Wheel slip parah | Tambah weight, ganti karet ban |
| Dataset terlalu sedikit | Re-collect Day 8 sore |
| R² model jelek (<0.3) | Augment + re-train Day 13 |
| VR sering nabrak | Naikkan safety_min_depth |
| Failover flapping | Naikkan hysteresis durations |
| NUC overheat/lag | Turunkan camera fps ke 15 Hz |
