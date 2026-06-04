# HANDOVER UNTUK CLAUDE CHAT — KORELASI MATA KULIAH AMR

**Untuk:** Claude (via claude.ai chat interface)
**Dari:** Claude Code (sesi 3 Juni 2026)
**Mahasiswa:** Muhammad Al Azhar Faradis, NRP 2040241017
**Institusi:** Sarjana Terapan Teknologi Rekayasa Otomasi (TRO), Teknik Elektro Otomasi, ITS Surabaya
**Tujuan dokumen:** Memberikan briefing lengkap agar Claude chat bisa langsung membantu menulis 4 dokumen korelasi mata kuliah dengan akurat — berbasis bukti file aktual di repo, bukan asumsi.

---

## 1. KONTEKS PROYEK SINGKAT

**Nama proyek:** Autonomous Mobile Robot (AMR) — Sasis Ackermann 2WS
**Repo GitHub:** `github.com/muhammadalazharf/autonomous-mobile-robot-ros2`
**Branch aktif:** `claude/brave-newton-6zvS4` (PR #1, sudah merged-ready)

**Target output proyek (sesuai arahan dosen):**
1. SLAM Mapping (RTAB-Map 3D dengan VIO)
2. Nav2 Autonomous Navigation (Global + Local Planner)
3. Visual Regression (RANSAC line fitting dari LiDAR)

**Hardware:**
- Compute: Intel NUC 13 (i7), Ubuntu 22.04.5, ROS 2 Humble
- Kamera: Intel RealSense D455 (RGB-D + IMU BMI055)
- LiDAR: RPLIDAR C1 (8m range, 10Hz)
- Mikrokontroler: STM32F407
- Aktuator: 4x motor PG45 (BTS7960 driver), 1x servo DS3225 steering
- Encoder: 1496 PPR rear axle
- Joystick: PS4 DualShock via Bluetooth

**Dimensi robot:**
- Chassis: 0.7m × 0.4m
- Wheelbase: 0.5m
- Wheel radius: 77.5mm
- Min turning radius kinematik: R = L/tan(δ) = 0.5/tan(30°) = 0.866m → di-set 0.90m di config

---

## 2. ARSITEKTUR SOFTWARE (VERIFIED dari repo aktual)

### Workspace structure
```
src/
├── amr_description/        URDF robot 13 segments
├── amr_controller/         stm32_bridge.cpp + odometry_publisher.py + imu_merger_node.py
├── amr_bringup/            Master launch: amr_full.launch.py + sensors_launch.py
├── amr_slam/               SLAM Toolbox + Nav2 configs
├── amr_3d_mapping/         RTAB-Map VIO launch + config
├── amr_visual_regression/  RANSAC line_segments
└── amr_failover/           4-state FSM
```

### Launch tree (pipeline saat mapping)
```
amr_full.launch.py (Terminal 1)
├── robot_state_publisher (URDF → TF)
├── joy_node + stm32_bridge (kontrol manual)
├── RPLIDAR C1 → /scan @ 10 Hz
├── RealSense D455 → /camera/camera/{color,depth,accel,gyro}/* @ 30 Hz
└── odometry_publisher.py → /odom (wheel bicycle kinematics)

rtabmap_mapping.launch.py (Terminal 2)
├── imu_merger_node → /imu/data @ 100 Hz
├── rgbd_sync → /rgbd_image
├── rgbd_odometry → /rtabmap/odom (VIO @ 30 Hz)
└── rtabmap SLAM → /grid_prob_map + /cloud_obstacles + /cloud_ground
```

---

## 3. KORELASI MATA KULIAH #1 — PENGOLAHAN CITRA DIGITAL (PCD)

**Dosen PCD:** Fauzi Imaduddin Adhim, S.ST., M.T. / Faiza Alif Fakhrina, S.Kom., M.T.
**Kode MK:** VE230414

### 3.1 Teori PCD yang Diterapkan

Pipeline citra dari RealSense D455 → RTAB-Map melalui 6 tahap PCD klasik:

| Tahap | Operasi PCD | Implementasi di AMR |
|---|---|---|
| 1. **Akuisisi Citra** | Capture RGB + Depth dari sensor | RealSense D455 publish `/camera/camera/color/image_raw` (RGB8, 848×480 @ 30Hz) dan `/camera/camera/aligned_depth_to_color/image_raw` (Z16, 848×480) |
| 2. **Preprocessing / Filtering** | Noise reduction pada depth map | RealSense temporal_filter + spatial_filter (di sensors_launch.py: `temporal_filter.enable: True`, `spatial_filter.enable: True`) |
| 3. **Registrasi & Alignment** | Spasial alignment antar stream (Depth ke RGB) | `align_depth.enable: True` di sensors_launch.py — hardware align via intrinsic+extrinsic kalibrasi pabrik |
| 4. **Sinkronisasi Temporal** | Sync timestamp antar topic | `rgbd_sync` node (rtabmap_sync package) menggabungkan RGB+Depth+CameraInfo → `/rgbd_image` dengan `approx_sync: false` (RealSense hardware-synced) |
| 5. **Feature Extraction** | Deteksi titik fitur (corners/keypoints) | GFTT (Good Features To Track) + BRIEF descriptor — `Vis/FeatureType: "8"` di rtabmap_mapping.yaml, `Vis/MaxFeatures: "1000"` |
| 6. **Feature Matching & RANSAC** | Matching antar frame untuk pose estimation | RTAB-Map internal: epipolar geometry + RANSAC outlier rejection, `Vis/MinInliers: "10"` (threshold inlier minimum untuk validasi pose) |

### 3.2 Bukti Implementasi di File

**File:** `src/amr_bringup/launch/sensors_launch.py`
```python
realsense_node = Node(
    package='realsense2_camera',
    parameters=[{
        'depth_module.profile':     '848x480x30',
        'rgb_camera.profile':       '848x480x30',
        'rgb_camera.color_profile': '848x480x30',
        'align_depth.enable':       True,    # Tahap 3: Depth-RGB alignment
        'temporal_filter.enable':   True,    # Tahap 2: Temporal filtering
        'spatial_filter.enable':    True,    # Tahap 2: Spatial filtering
        'unite_imu_method':         2,       # Linear interpolation IMU
    }],
)
```

**File:** `src/amr_3d_mapping/config/rtabmap_mapping.yaml`
```yaml
Vis/FeatureType: "8"            # GFTT/BRIEF — feature extraction
Vis/MaxFeatures: "1000"         # Max keypoints per frame
Vis/MinInliers: "10"            # RANSAC inlier threshold
GFTT/MinDistance: "10"          # Min distance antar features
GFTT/QualityLevel: "0.001"      # Threshold kualitas corner

Reg/Strategy: "2"               # Vis+ICP — kombinasi visual + geometrik
Optimizer/GravitySigma: "0.3"   # IMU gravity constraint
```

### 3.3 Operasi PCD Spesifik yang Bisa Dijelaskan

1. **Color Space Conversion** — RealSense capture RGB, internally konversi ke grayscale untuk feature detection
2. **Image Pyramid** — GFTT bekerja multi-scale untuk deteksi feature yang invariant terhadap skala
3. **Corner Detection (Shi-Tomasi/GFTT)** — Compute eigenvalues dari gradient matrix → pilih titik dengan minimum eigenvalue > threshold
4. **BRIEF Descriptor** — Binary Robust Independent Elementary Features, deskriptor binary 256-bit per keypoint
5. **Brute Force Matching dengan Hamming Distance** — Untuk binary descriptor BRIEF
6. **RANSAC** — Random Sample Consensus untuk reject outlier matching → estimate pose 3D
7. **Depth Lookup** — Untuk setiap RGB keypoint, lookup Z value di aligned depth image → konversi 2D pixel ke 3D point
8. **Triangulasi** — Stereo IR D455 menggunakan disparity → depth via baseline + focal length

### 3.4 Sub-CPMK PCD yang Bisa Di-correlate

Berdasarkan RPS VE230414 (perlu cek RPS aktual), area yang ter-cover:
- Akuisisi & representasi citra digital
- Operasi point-to-point (color conversion)
- Filtering spatial dan temporal
- Deteksi fitur (corner, edge, keypoint)
- Matching dan transformasi geometri
- Aplikasi PCD di robotika/computer vision

### 3.5 Bukti Visual untuk Laporan

Screenshot yang bisa di-capture:
1. RViz showing `/camera/camera/color/image_raw` (raw RGB)
2. RViz showing `/camera/camera/aligned_depth_to_color/image_raw` (depth map dengan colormap)
3. rqt_image_view membandingkan depth sebelum dan sesudah filter
4. RTAB-Map viz showing matched features antar dua frame
5. Point cloud 3D di RViz hasil dari triangulasi depth+RGB

---

## 4. KORELASI MATA KULIAH #2 — METODE NUMERIK

### 4.1 Teori Metode Numerik yang Diterapkan

| Metode Numerik | Implementasi di AMR | Lokasi |
|---|---|---|
| **Integrasi Numerik (Euler Forward)** | Integrasi pose dari velocity di odometry | `odometry_publisher.py` line ~210: `self.x += delta_dist * cos(theta)` |
| **Iterative Closest Point (ICP)** | Registrasi point cloud LiDAR untuk loop closure | RTAB-Map: `Reg/Strategy: "2"` (Vis+ICP), `Icp/Iterations: "15"` |
| **Levenberg-Marquardt Optimization** | Bundle adjustment pose graph SLAM | RTAB-Map internal: g2o/GTSAM optimizer |
| **RANSAC** | Outlier rejection di feature matching dan line fitting | RTAB-Map `Vis/MinInliers`, juga di `amr_visual_regression` untuk LiDAR line fitting |
| **Least Squares Estimation** | Line fitting RANSAC untuk wall detection | `amr_visual_regression/lidar_line_segments_node.py` |
| **Quaternion Math** | Rotasi 3D tanpa singularitas | `odometry_publisher.py`: `yaw_to_quaternion()` |
| **Matrix Transformations (Homogeneous)** | TF tree ROS, transformasi 4×4 antar frame | ROS 2 `tf2_ros` |
| **Bicycle Kinematic Model** | Konversi velocity + steering → pose | `odometry_publisher.py`: `delta_theta = (vx/wheelbase) * tan(steering) * dt` |
| **Voxel Grid Downsampling** | Reduksi point cloud sebelum ICP | `Icp/VoxelSize: "0.05"` |
| **Extended Kalman Filter (EKF)** | Sensor fusion (standby, tidak deployed) | `amr_ekf_emergency` package |

### 4.2 Bukti Implementasi di File

**File:** `src/amr_controller/scripts/odometry_publisher.py`
```python
# Bicycle kinematic model (numerical integration Euler forward)
delta_dist = self.last_delta * self.dist_per_tick
vx = delta_dist / dt
delta_theta = (vx / self.wheelbase) * math.tan(self.steering) * dt

# Pose integration
self.x += delta_dist * math.cos(self.theta + delta_theta / 2.0)
self.y += delta_dist * math.sin(self.theta + delta_theta / 2.0)
self.theta += delta_theta
self.theta = math.atan2(math.sin(self.theta), math.cos(self.theta))  # wrap to [-pi, pi]
```

**File:** `src/amr_3d_mapping/config/rtabmap_mapping.yaml`
```yaml
# ICP parameters - Iterative Closest Point untuk loop closure
Icp/PointToPlane: "true"               # Variant point-to-plane (lebih akurat)
Icp/Iterations: "15"                   # Max iterasi konvergensi
Icp/VoxelSize: "0.05"                  # Downsample 5cm sebelum ICP
Icp/MaxCorrespondenceDistance: "0.1"   # Threshold matching point
Icp/Epsilon: "0.001"                   # Konvergensi: stop kalau delta < epsilon
Icp/MaxTranslation: "1.0"              # Reject hasil ICP > 1m translasi
Icp/MaxRotation: "0.78"                # Reject hasil ICP > 45° rotasi
```

**File:** `src/amr_visual_regression/amr_visual_regression/lidar_line_segments_node.py`
- Menggunakan RANSAC + Least Squares untuk fitting garis dari point cloud LiDAR 2D
- Output: 7-11 garis wall terdeteksi per scan

### 4.3 Algoritma Numerik Spesifik yang Bisa Dijelaskan

1. **Euler Forward Integration**
   - Pose update: `x(t+dt) = x(t) + v*cos(θ)*dt`
   - Error orde O(dt) — diterima karena dt kecil (20ms @ 50Hz)

2. **ICP Algorithm**
   - Step 1: Find closest correspondence antara source dan target point cloud
   - Step 2: Compute optimal rotation+translation via SVD
   - Step 3: Apply transformation
   - Step 4: Iterate sampai konvergen (delta < epsilon) atau max iterations

3. **RANSAC untuk Line Fitting**
   - Random sample 2 points → fit line
   - Count inliers (points within threshold distance)
   - Repeat N iterations → pilih best model
   - Refit dengan all inliers menggunakan least squares

4. **Pose Graph Optimization (g2o)**
   - Nodes: robot poses + landmark positions
   - Edges: relative transformations dengan covariance
   - Minimize: Σ ||z_ij - h(x_i, x_j)||²_Σ
   - Solver: Levenberg-Marquardt (nonlinear least squares)

5. **Bundle Adjustment**
   - Joint optimization camera poses + 3D points
   - Minimize reprojection error: Σ ||x_observed - π(K[R|t]X)||²

### 4.4 Bukti Numerik untuk Laporan

- Output `quality=372-378` di RTAB-Map log (jumlah inlier hasil RANSAC)
- `std dev=0.003-0.007m | 0.000173rad` (akurasi pose dari kovarian)
- VIO rate 30Hz (cycle integration numerik per detik)

---

## 5. KORELASI MATA KULIAH #3 — DCS (DISTRIBUTED CONTROL SYSTEM)

### 5.1 Teori DCS yang Diterapkan

DCS klasik (PLC + jaringan industri seperti Profibus/Modbus) tidak diterapkan literal. Namun **konsep arsitektural DCS sangat relevan** dengan ROS 2 yang memang dirancang sebagai sistem kontrol terdistribusi.

| Konsep DCS | Implementasi di AMR |
|---|---|
| **Distributed Processing** | ROS 2 multi-node, setiap node = proses terpisah dengan tanggung jawab spesifik (separation of concerns) |
| **Inter-Process Communication** | DDS (Data Distribution Service) via CycloneDDS sebagai middleware |
| **Field Bus / Industrial Network** | DDS dengan QoS profiles (Reliable/BestEffort, Transient/Volatile) — mirip Profibus DP/PA |
| **Master-Slave / Publisher-Subscriber** | ROS 2 pub-sub model, topic-based async messaging |
| **Real-time Determinism** | ROS 2 Humble + RT kernel options, QoS Deadline policy |
| **Hierarchical Control** | Layer: Sensors → Perception → Planning → Control → Actuation |
| **HMI (Human-Machine Interface)** | RViz2 + Foxglove Studio (monitoring), PS4 joystick (operator input) |
| **Redundancy & Fault Tolerance** | `amr_failover` 4-state FSM, `respawn: True` pada sensor nodes |
| **Engineering Workstation** | NUC sebagai onboard controller, laptop sebagai remote engineering station via Tailscale |

### 5.2 Arsitektur Distributed di AMR

```
                  ┌─────────────────────────────────────────┐
                  │     OPERATIONAL LAYER (HMI/Operator)    │
                  │   PS4 Joystick + RViz2 + Foxglove       │
                  └────────────────┬────────────────────────┘
                                   │ DDS (Tailscale VPN)
                  ┌────────────────▼────────────────────────┐
                  │  SUPERVISORY LAYER (Failover FSM)       │
                  │  4-state: IDLE/AUTO/MANUAL/FAULT        │
                  └────────────────┬────────────────────────┘
                                   │
                  ┌────────────────▼────────────────────────┐
                  │  CONTROL LAYER (Nav2 + Planner)         │
                  │  Global: SmacPlannerHybrid              │
                  │  Local:  RegulatedPurePursuit           │
                  └────────────────┬────────────────────────┘
                                   │
                  ┌────────────────▼────────────────────────┐
                  │  PERCEPTION LAYER (SLAM)                │
                  │  RTAB-Map VIO + LiDAR ICP               │
                  └────────────────┬────────────────────────┘
                                   │
                  ┌────────────────▼────────────────────────┐
                  │  SENSORS LAYER (Field Devices)          │
                  │  RealSense D455 + RPLIDAR C1 + Encoder  │
                  └────────────────┬────────────────────────┘
                                   │ USB Serial / USB 3.2
                  ┌────────────────▼────────────────────────┐
                  │  ACTUATORS (Field Devices)              │
                  │  STM32F407 + BTS7960 + DS3225 Servo     │
                  └─────────────────────────────────────────┘
```

### 5.3 Bukti Implementasi DCS-style

**File:** `src/amr_bringup/launch/amr_full.launch.py`
- Modular flag system: `use_slam`, `use_nav2`, `use_rtabmap`, `use_failover` — mirip "module enable/disable" di DCS engineering station

**File:** `src/amr_failover/amr_failover/failover_controller.py`
- 4-state FSM (Finite State Machine) — pattern klasik DCS untuk supervisory control

**File:** `src/amr_controller/src/stm32_bridge.cpp`
- Gateway antara ROS 2 (high-level) dan STM32 (low-level field device)
- Protokol serial: `V:{velocity},S:{steer}\n` (NUC→STM32), `E:{delta}\n` (STM32→NUC)
- Konsep ini = "Fieldbus protocol" di DCS

**Environment ROS 2:**
- `ROS_DOMAIN_ID=42` — isolasi network seperti VLAN di DCS
- `RMW_IMPLEMENTATION=rmw_cyclonedds_cpp` — middleware spesifik (analog: pilih Profinet vs EtherCAT)

### 5.4 Konsep DCS Spesifik yang Bisa Dijelaskan

1. **Hierarchical Control Pyramid (ISA-95)**
   - Level 0: Sensors/Actuators
   - Level 1: Basic Control (STM32 motor control)
   - Level 2: Supervisory (Nav2 + Failover)
   - Level 3: Production Control (mapping mission planning)
   - Level 4: Business (out of scope)

2. **Pub-Sub vs Polling**
   - ROS 2 DDS = event-driven pub-sub
   - DCS klasik = cyclic polling
   - AMR pakai pub-sub karena lebih efisien untuk sensor streaming

3. **QoS (Quality of Service)**
   - Reliability: Reliable (TCP-like) vs BestEffort (UDP-like)
   - Durability: Volatile vs TransientLocal (last value kept)
   - Contoh di proyek: `/scan` BestEffort (sensor stream), `/map` TransientLocal (state)

4. **Fault Detection & Recovery**
   - `respawn: True, respawn_delay: 2.0` pada RPLIDAR + RealSense = auto-restart kalau crash
   - Failover FSM monitor health → switch ke safe state kalau ada fault

5. **Distributed Synchronization**
   - TF tree = distributed time-synchronized coordinate frames
   - Mirip "time synchronization" di DCS (IEEE 1588 PTP)

### 5.5 Bukti Visual untuk Laporan

- Diagram arsitektur node ROS 2 (`rqt_graph`)
- TF tree visualization (`tf2_tools view_frames`)
- Topic list dengan QoS profile (`ros2 topic info -v <topic>`)

---

## 6. KORELASI MATA KULIAH #4 — SCADA (SUPERVISORY CONTROL AND DATA ACQUISITION)

### 6.1 Teori SCADA yang Diterapkan

SCADA = monitoring + control jarak jauh + data logging + alarming.

| Komponen SCADA | Implementasi di AMR |
|---|---|
| **HMI (Human-Machine Interface)** | RViz2 + Foxglove Studio (browser-based) |
| **Data Acquisition (DAQ)** | ROS 2 topic subscriptions, ros2 bag recording |
| **Remote Terminal Unit (RTU)** | STM32F407 sebagai field controller |
| **Communication Network** | Tailscale VPN + DDS (analog: SCADA via VPN ke field) |
| **Historian / Data Logger** | ros2 bag, RTAB-Map database `.db` (SQLite) |
| **Alarming** | RTAB-Map log warnings (VIO quality drop), Failover FSM state changes |
| **Trending / Live Charts** | rqt_plot, Foxglove Studio time-series panels |
| **Setpoint Control** | RViz `2D Goal Pose` → Nav2 (setpoint = goal position) |
| **Mimic Diagram** | RViz2 robot model + map + path visualization |
| **Tag Database** | ROS 2 parameter server, topic registry |

### 6.2 Pipeline SCADA di AMR

```
[FIELD: NUC + Sensors + Actuators]
          │
          │ Data Acquisition (DDS pub-sub)
          ▼
[REMOTE STATION: Laptop via Tailscale 100.85.144.92]
          │
          ├─→ RViz2 (Visualization & Control)
          ├─→ Foxglove Studio (Web-based HMI)
          ├─→ ros2 bag record (Historian)
          └─→ ros2 topic echo (Live debugging)
```

### 6.3 Bukti Implementasi SCADA-style

**Live Monitoring (HMI):**
- RViz2 di laptop client dengan Fixed Frame=map, displays:
  - `/grid_prob_map` (mimic diagram peta)
  - `/scan` (live LiDAR data)
  - `/cloud_obstacles` + `/cloud_ground` (3D point cloud)
  - `/rtabmap/odom` arrow (live robot position)
  - TF tree (frame relationships)

**Remote Access:**
- Tailscale VPN: NUC IP `100.85.144.92`, Laptop IP `100.123.180.42`
- SSH alias `ssh nuc` untuk remote shell
- NoMachine untuk full desktop remote

**Foxglove Bridge:**
- `ros2 run foxglove_bridge foxglove_bridge` → expose ws://NUC:8765
- Browser-based HMI, bisa diakses dari device manapun di Tailscale network

**Data Acquisition / Historian:**
- RTAB-Map database `~/maps/lab_vio.db` = persistent storage pose graph + features (SQLite)
- ros2 bag untuk recording session lengkap untuk replay/analysis offline
- Map files `~/maps/lab_vio_map.pgm + .yaml` = artifact pemetaan

**Setpoint / Command:**
- PS4 joystick → `/cmd_vel` (manual setpoint)
- RViz `2D Goal Pose` → Nav2 (autonomous setpoint)
- Failover FSM → arbitrasi prioritas command

### 6.4 Konsep SCADA Spesifik yang Bisa Dijelaskan

1. **Polling vs Event-driven**
   - SCADA klasik: master polling slave secara cyclic
   - AMR pakai event-driven DDS (publish saat ada data baru)
   - Lebih efisien untuk high-rate sensor (kamera 30Hz)

2. **Tag Naming Convention**
   - SCADA: `Pump01_Pressure`, `Tank02_Level`
   - ROS 2: `/camera/camera/color/image_raw`, `/rtabmap/odom`
   - Konsep sama: hierarchical namespace

3. **Alarm Categories**
   - Severity: INFO, WARN, ERROR, FATAL (ros2 log levels)
   - Contoh alarm di proyek: "Not enough inliers" (VIO degraded)

4. **Historian Architecture**
   - ros2 bag = time-series database untuk semua topic
   - Bisa replay offline untuk debugging/analysis
   - RTAB-Map .db = spatial database (pose graph + visual features)

5. **Mimic Display**
   - RViz2 = engineering view (3D + technical data)
   - Foxglove = operator view (web-based, customizable panels)

### 6.5 Bukti Visual untuk Laporan

Screenshot yang bisa di-capture:
1. RViz2 dengan peta + robot + path (mimic display)
2. Foxglove Studio dashboard (HMI operator)
3. Terminal `ros2 topic list` + `ros2 topic hz` (DAQ verification)
4. Tailscale admin panel showing NUC connected (remote access)
5. RTAB-Map database file size growing during mapping (historian)
6. ros2 bag info output (recorded session data)

---

## 7. RUMUS MATEMATIS UTAMA UNTUK LAPORAN

### Bicycle Kinematic Model (Ackermann)
```
v_x = (Δs) / Δt                            # velocity from encoder
δθ = (v_x / L) * tan(δ) * Δt               # angular velocity
x(t+Δt) = x(t) + v_x * cos(θ + δθ/2) * Δt  # position update (midpoint method)
y(t+Δt) = y(t) + v_x * sin(θ + δθ/2) * Δt
θ(t+Δt) = θ(t) + δθ
```
Dimana: L = wheelbase (0.5m), δ = steering angle, Δs = wheel travel distance

### Minimum Turning Radius
```
R_min = L / tan(δ_max) = 0.5 / tan(30°) = 0.866m
```

### ICP Cost Function
```
E(R, t) = Σ ||p_i - (R*q_i + t)||²
```
Dimana: p_i = target points, q_i = source points, R = rotation matrix, t = translation

### RANSAC Probability
```
P_success = 1 - (1 - w^n)^k
```
Dimana: w = inlier ratio, n = sample size, k = iterations

### Quaternion from Yaw
```
q.z = sin(yaw/2)
q.w = cos(yaw/2)
q.x = q.y = 0  (untuk rotasi planar)
```

### Depth Triangulation (Stereo)
```
Z = (f * B) / d
```
Dimana: f = focal length, B = baseline IR sensors (D455 = 95mm), d = disparity

---

## 8. PARAMETER AKTUAL DARI CONFIG (untuk dikutip di laporan)

### sensors_launch.py (RealSense D455)
```python
'depth_module.profile':     '848x480x30'    # Depth Z16, 848x480 @ 30 FPS
'rgb_camera.profile':       '848x480x30'    # RGB8, 848x480 @ 30 FPS
'rgb_camera.color_profile': '848x480x30'    # Belt-and-suspenders
'align_depth.enable':       True             # Hardware alignment
'temporal_filter.enable':   True             # Temporal smoothing
'spatial_filter.enable':    True             # Edge-preserving spatial
'enable_gyro':              True             # 200 Hz
'enable_accel':             True             # 100 Hz
'unite_imu_method':         2                # Linear interpolation
```

### rtabmap_mapping.yaml (SLAM core parameters)
```yaml
Vis/FeatureType: "8"           # GFTT/BRIEF
Vis/MaxFeatures: "1000"
Vis/MinInliers: "10"
GFTT/MinDistance: "10"
GFTT/QualityLevel: "0.001"

Icp/Iterations: "15"
Icp/VoxelSize: "0.05"          # 5cm
Icp/MaxCorrespondenceDistance: "0.1"

Reg/Strategy: "2"              # Vis+ICP
Reg/Force3DoF: "true"          # 2D ground robot
Optimizer/GravitySigma: "0.3"  # IMU gravity constraint

RGBD/AngularUpdate: "0.05"     # Min rotation untuk update map (rad)
RGBD/LinearUpdate: "0.05"      # Min translation untuk update map (m)
RGBD/NeighborLinkRefining: "true"
RGBD/ProximityBySpace: "true"
```

### nav2_params.yaml (Navigation)
```yaml
# Global Planner
plugin: "nav2_smac_planner/SmacPlannerHybrid"
motion_model_for_search: "DUBIN"      # Forward-only
minimum_turning_radius: 0.90          # m
angle_quantization_bins: 72

# Local Controller
plugin: "nav2_regulated_pure_pursuit_controller/RegulatedPurePursuitController"
desired_linear_vel: 0.4               # m/s
lookahead_dist: 0.6                   # m
use_rotate_to_heading: false          # Ackermann no spin
allow_reversing: true
```

### odometry_publisher.py (Wheel odometry)
```python
wheel_radius:         0.0775   # m (155mm diameter / 2)
wheelbase:            0.500    # m
pulses_per_revolution: 1496    # 11 PPR × 4 quadrature × 1:34 gearbox
max_steer_deg:        45.0     # mechanical limit (effective ~30°)
publish_rate:         50.0     # Hz
```

---

## 9. EVIDENCE CHECKLIST UNTUK SETIAP MATA KULIAH

### PCD — yang sudah verified working
- ✅ RealSense capture RGB+Depth @ 848×480
- ✅ Depth-RGB alignment (`align_depth.enable: True`)
- ✅ Temporal+spatial filtering aktif
- ✅ GFTT/BRIEF feature extraction running
- ✅ RANSAC inlier validation (quality 372-378 saat sistem stabil)
- ⚠️ Visual evidence (screenshot RViz + rqt_image_view) — perlu di-capture

### Metode Numerik — yang sudah verified
- ✅ Euler forward integration di odometry_publisher.py
- ✅ ICP running (Icp/Iterations: 15)
- ✅ RANSAC running di RTAB-Map VIO
- ✅ Pose graph optimization di RTAB-Map SLAM
- ✅ RANSAC line fitting di amr_visual_regression (7-11 walls/scan)
- ✅ Quaternion math di odometry_publisher.py

### DCS — yang sudah verified
- ✅ Multi-node distributed architecture (12+ nodes)
- ✅ DDS middleware (CycloneDDS)
- ✅ QoS profiles per topic
- ✅ Hierarchical layers (sensors → perception → control)
- ✅ Failover FSM (4-state)
- ✅ Fieldbus equivalent (USB serial STM32 protocol)
- ✅ Modular launch system

### SCADA — yang sudah verified
- ✅ Remote HMI via RViz2 + Foxglove
- ✅ Tailscale VPN remote access working
- ✅ DAQ via ros2 topic subscriptions
- ✅ Historian: RTAB-Map .db + map .pgm files
- ✅ Setpoint control (RViz Goal Pose → Nav2)
- ✅ Live telemetry visible saat sistem running
- ⚠️ ros2 bag recording — belum di-setup formal tapi mudah ditambah

---

## 10. CATATAN KHUSUS UNTUK CLAUDE CHAT

1. **Korelasi mata kuliah HARUS MENGIKUTI proyek, jangan sebaliknya.** Jangan buat-buat aktivitas teknis hanya untuk justify korelasi MK. Semua yang dikutip di sini ADA di file aktual repo.

2. **Format laporan korelasi MK yang dosen suka:**
   - Sebut operasi/algoritma SPESIFIK (bukan general "kami pakai PCD")
   - Tunjukkan TAHAPAN head-to-tail (input → proses → output)
   - Sertakan PARAMETER aktual dari config (bukti konkret)
   - Lampirkan bukti VISUAL (screenshot RViz/rqt)
   - Map setiap operasi ke Sub-CPMK dari RPS mata kuliah

3. **Jangan klaim hal yang belum verified:**
   - ❌ "AMCL sudah lock dan navigate berhasil" — belum diverifikasi end-to-end
   - ❌ "UMBmark menunjukkan akurasi 99%" — UMBmark belum pernah dijalankan
   - ✅ "VIO quality 372-378 ter-log di sesi 3 Juni 2026" — verified

4. **Kalau ada dokumen korelasi PCD sebelumnya** (`Korelasi_PCD_Sistem_Pencitraan_AMR.docx`), pakai sebagai referensi format tapi update dengan parameter aktual terbaru.

5. **Sumber kebenaran tunggal:** file di repo `github.com/muhammadalazharf/autonomous-mobile-robot-ros2` branch `claude/brave-newton-6zvS4`. Kalau ragu, baca file aktualnya.

6. **State sistem per 3 Juni 2026 (verified):**
   - VIO quality: 372-378 (sangat baik)
   - VIO rate: ~30 Hz stabil
   - Map publishing: `/grid_prob_map` aktif
   - SLAM Toolbox vs RTAB-Map conflict: SUDAH DI-FIX (default use_slam=false)
   - Resolusi RGB=Depth=848×480 (match)
   - Pending: mapping run dengan baterai LiPO (sedang dicari pengganti)

---

## 11. FILE-FILE PENTING UNTUK DI-REFERENCE

Repo: `github.com/muhammadalazharf/autonomous-mobile-robot-ros2`
Branch: `claude/brave-newton-6zvS4`

| File | Untuk MK |
|---|---|
| `src/amr_bringup/launch/sensors_launch.py` | PCD (RealSense config), DCS (sensor layer) |
| `src/amr_3d_mapping/config/rtabmap_mapping.yaml` | PCD (feature extraction), Metode Numerik (ICP) |
| `src/amr_3d_mapping/launch/rtabmap_mapping.launch.py` | DCS (pipeline architecture) |
| `src/amr_controller/scripts/odometry_publisher.py` | Metode Numerik (Euler integration, bicycle model) |
| `src/amr_controller/scripts/imu_merger_node.py` | PCD (sensor fusion), Metode Numerik (interpolation) |
| `src/amr_controller/src/stm32_bridge.cpp` | DCS (fieldbus protocol), SCADA (RTU) |
| `src/amr_slam/config/nav2_params.yaml` | Metode Numerik (path planning), DCS (control layer) |
| `src/amr_failover/amr_failover/failover_controller.py` | DCS (supervisory FSM) |
| `src/amr_visual_regression/amr_visual_regression/lidar_line_segments_node.py` | Metode Numerik (RANSAC, least squares) |
| `src/amr_bringup/launch/amr_full.launch.py` | DCS (modular orchestration) |

---

## 12. INSTRUKSI EKSEKUSI UNTUK CLAUDE CHAT

Saat user upload dokumen ini ke claude.ai, lakukan langkah berikut:

1. **Konfirmasi pemahaman** — ringkas struktur proyek dan 4 mata kuliah yang ingin di-correlate

2. **Tanya prioritas** — mata kuliah mana yang paling urgent (deadline laporan?)

3. **Untuk setiap mata kuliah, hasilkan:**
   - Dokumen Word/Markdown 4-8 halaman
   - Struktur: Pendahuluan → Teori MK → Implementasi di Proyek → Bukti Visual → Korelasi Sub-CPMK → Kesimpulan
   - Sertakan parameter aktual (jangan placeholder)
   - Sediakan placeholder gambar dengan instruksi capture (mis: "Screenshot RViz2 fixed_frame=map, displays /grid_prob_map")

4. **Pastikan setiap claim punya bukti file:**
   - "Sistem menggunakan GFTT feature extraction" → cite `Vis/FeatureType: "8"` di `rtabmap_mapping.yaml`
   - "Implementasi Euler integration" → cite line aktual di `odometry_publisher.py`

5. **Jangan regenerate kode** — semua kode sudah di repo. Cukup reference.

6. **Hindari over-claim** — sebut yang verified, tandai yang masih in-progress.

---

**END OF HANDOVER**

Dokumen ini disusun pada 3 Juni 2026 oleh Claude Code (sesi remote di
Claude Code on the web), berbasis pembacaan file aktual di branch
`claude/brave-newton-6zvS4`. Semua parameter dan claim sudah cross-check
ke source code. Kalau ada perbedaan dengan state di NUC, file di repo
GitHub adalah sumber kebenaran.
