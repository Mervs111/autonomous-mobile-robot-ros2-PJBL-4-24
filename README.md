# AMR — Mobile Robot Ackermann Indoor Platform

![ROS 2 Humble](https://img.shields.io/badge/ROS_2-Humble-blue.svg) ![Ubuntu 22.04](https://img.shields.io/badge/Ubuntu-22.04-orange.svg) ![License](https://img.shields.io/badge/License-MIT-green.svg)

> Platform pembelajaran mobile robot 4WD-Ackermann untuk eksperimen autonomous navigation, SLAM, dan visual regression-based obstacle avoidance — dirancang untuk lingkungan **indoor** (lab/ruang kelas).

**Author:** Muhammad Al Azhar Faradis (NRP 2040241017)
**Institusi:** Sarjana Terapan Teknologi Rekayasa Otomasi — DTEO — Fakultas Vokasi — ITS Surabaya

---

## Akses NUC (Step-by-Step)

Semua node ROS jalan di **NUC** (otak robot). Kamu mengaksesnya dari laptop.

**Identitas NUC:**
- Hostname: `itssurabaya-NUC13ANHi7`
- User: `itssurabaya`

### Metode 1 — NoMachine *(direkomendasikan — dapat desktop penuh)*

Pakai ini kalau butuh GUI (RViz, rtabmap_viz, lihat peta, file manager).

1. Buka aplikasi **NoMachine** di laptop.
2. Masukkan **IP NUC** (cara cek IP di bawah) → port default `4000`.
3. Login: user `itssurabaya` + password NUC.
4. Muncul desktop Ubuntu NUC. Buka **Terminal** dari sini untuk menjalankan command.

### Metode 2 — SSH *(terminal saja, lebih ringan)*

```bash
ssh itssurabaya@<IP_NUC>
```

### Cara cek IP NUC (kalau berubah)

> ⚠️ IP LAN NUC **bisa berganti** tiap reconnect WiFi. Untuk lihat IP saat ini, jalankan **di NUC** (lewat NoMachine):

```bash
hostname -I                      # tampilkan semua IP (ambil yang 192.168.x.x / 10.x.x.x)
# atau:
ip addr show | grep "inet "
```

> **IP Tailscale permanen:** `100.85.144.92` — IP ini **tidak pernah berubah** walau pindah jaringan. Syaratnya laptop juga terpasang Tailscale & gabung tailnet yang sama (opsional, tidak wajib).

### Setelah masuk NUC — WAJIB di SETIAP terminal baru

```bash
export ROS_DOMAIN_ID=42
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
cd ~/amr_starter && source install/setup.bash
```

> Lupa `ROS_DOMAIN_ID` / `RMW_IMPLEMENTATION` = topic **tidak terlihat antar terminal**. Ini penyebab "kok kosong / no data" yang paling sering.

### Matikan robot (urutan benar)

1. `Ctrl+C` di terminal RTAB-Map / mapping dulu → **tunggu** log `Saving database... done!` (jangan dipaksa, ini sedang menulis DB).
2. `Ctrl+C` terminal sensor.
3. Shutdown NUC: `sudo shutdown now`. Cabut/charge baterai.

---

## Arsitektur Dual Workspace

Proyek ini menggunakan **ROS 2 Overlay Pattern** untuk pisahkan paket stable vs paket aktif:

```
~/amr_underlay_ws/                    ← UNDERLAY (stable, jarang berubah)
└── src/
    └── rplidar_ros/                  ← Vendor LiDAR driver

~/amr_starter/                        ← OVERLAY (kerjaan aktif development)
├── src/
│   ├── amr_bringup/                  ← Launch files
│   ├── amr_controller/               ← STM32 bridge + odometry
│   ├── amr_description/              ← URDF model
│   ├── amr_failover/                 ← State machine 4-mode
│   ├── amr_slam/                     ← SLAM Toolbox + Nav2 config
│   └── amr_visual_regression/        ← Random Forest VR backup
├── scripts/                          ← Setup & utility scripts
├── docs/                             ← Dokumentasi lengkap
├── maps/                             ← Peta hasil SLAM mapping
├── .bashrc_amr                       ← Environment setup
├── README.md                         ← (this file)
├── DEPLOYMENT_GUIDE.md               ← Setup instructions
└── PROGRESS.md                       ← Daily progress log
```

**Source order saat startup**:
1. `/opt/ros/humble/setup.bash` (ROS 2 system)
2. `~/amr_underlay_ws/install/setup.bash` (stable packages)
3. `~/amr_starter/install/setup.bash` (active development)

**Manfaat pattern ini**: kalau amr_starter rusak/error, cukup re-clone overlay. Underlay tetap utuh.

---

## Quick Start

### Pertama kali setup di NUC baru

```bash
# 1. Pastikan ROS 2 Humble sudah terinstall
# 2. Extract amr_underlay_ws.zip dan amr_starter.zip ke ~
cd ~
unzip amr_underlay_ws.zip
unzip amr_starter.zip

# 3. Run setup script
bash ~/amr_starter/scripts/01_setup_workspaces.sh

# 4. Verify
bash ~/amr_starter/scripts/00_preflight_check.sh
```

### Setiap hari kerja di lab

```bash
# Verify environment
bash ~/amr_starter/scripts/00_preflight_check.sh

# Manual drive saja
ros2 launch amr_bringup amr_launch.py

# Full system dengan SLAM mapping
ros2 launch amr_bringup amr_full.launch.py slam_mode:=mapping

# Full system dengan Nav2 autonomous
ros2 launch amr_bringup amr_full.launch.py \
    slam_mode:=localization use_nav2:=true \
    map_name:=lab_map
```

---

## Hardware

| Komponen | Spec | Status |
|----------|------|--------|
| Compute | Intel NUC 13 i7 (Raptor Lake), 14 cores | ✅ Verified |
| Microcontroller | STM32F407VGTx, bare-metal C, USB CDC | ✅ Verified |
| Motor | 1× PG45 24V 60W, gearbox 1:34 | ✅ Verified |
| Motor driver | BTS7960 half-bridge 43A | ✅ Verified |
| Steering servo | DS3225 25kg.cm, range ±45° | ✅ Verified |
| Wheel encoder | Hall 11 PPR × 4 quad × 34 = 1496 pulsa/rev | ✅ Verified |
| LiDAR | RPLIDAR Slamtec C1 (USB-UART CP2102N) | ✅ Detected |
| Depth camera | Intel RealSense D455 | ✅ Detected |
| Joystick | PS4/PS5 DualShock via Bluetooth | ✅ Verified |
| Battery | LiPo 6S 5300mAh 22.2V Ovonic | ✅ Verified |

**Dimensi mekanis**:
- Wheelbase: 0.500 m
- Track width: 0.400 m
- Wheel radius: 0.0775 m (diameter 155.01 mm)
- Min turning radius: L/tan(45°) = 0.500 m

---

## Komunikasi Protocol

**NUC → STM32** (commands via USB CDC ASCII):
```
V:<velocity_pwm>,S:<steering_deg>\n
```
- `velocity_pwm`: -4000 to +4000 (motor PWM)
- `steering_deg`: -45 to +45 (servo angle in degrees)

**STM32 → NUC** (encoder feedback, every 50ms):
```
E:<delta_pulses>\n
```
- `delta_pulses`: signed integer (pulses sejak pembacaan terakhir)
- Format: **delta** (bukan cumulative) — di-handle oleh stm32_bridge dan odometry_publisher

---

## Mode Operasi

Workspace mendukung **4 mode operasi** via `amr_full.launch.py` flags:

### Mode 1: Foundation (Manual Drive)
```bash
ros2 launch amr_bringup amr_full.launch.py use_slam:=false
```
Hanya joystick + STM32 bridge + odometry + LiDAR. Tidak ada SLAM atau Nav2. Cocok untuk testing hardware.

### Mode 2: SLAM Mapping
```bash
ros2 launch amr_bringup amr_full.launch.py slam_mode:=mapping
```
Drive manual sambil bangun peta. Hasil disimpan ke `maps/`.

### Mode 3: SLAM Localization
```bash
ros2 launch amr_bringup amr_full.launch.py slam_mode:=localization map_name:=lab_map
```
Load peta yang sudah ada, robot melakukan localization di peta tersebut.

### Mode 4: Full Autonomous
```bash
ros2 launch amr_bringup amr_full.launch.py \
    slam_mode:=localization use_nav2:=true use_failover:=true \
    map_name:=lab_map
```
Nav2 stack aktif. Set Pose Estimate via RViz, lalu Nav2 Goal untuk autonomous navigation.

---

## Dokumentasi Lengkap

Semua dokumentasi ada di `docs/`:

1. **[USER MANUAL](docs/01_USER_MANUAL.md)** — Panduan operator: power-on, mode operasi, emergency procedures
2. **[DEVELOPMENT GUIDE](docs/02_DEVELOPMENT_GUIDE.md)** — Architecture, workflow git, build instructions, tuning
3. **[HARDWARE GUIDE](docs/03_HARDWARE_GUIDE.md)** — Wiring, pin assignment, kalibrasi, baterai management
4. **[VISUAL REGRESSION GUIDE](docs/04_VISUAL_REGRESSION_GUIDE.md)** — Random Forest training, dataset collection
5. **[SLAM & NAV2 GUIDE](docs/05_SLAM_NAV2_GUIDE.md)** — Mapping workflow, parameter tuning, Nav2 setup
6. **[FAILOVER GUIDE](docs/06_FAILOVER_GUIDE.md)** — 4-state machine, hysteresis, recovery
7. **[TROUBLESHOOTING](docs/07_TROUBLESHOOTING.md)** — Common issues, debug commands

---

## Roadmap

### Phase 1: Foundation ✅
- [x] Hardware integration (STM32, joystick, encoder)
- [x] Workspace architecture (dual workspace pattern)
- [x] Manual drive verified
- [x] Encoder feedback verified
- [x] Documentation framework

### Phase 2: Perception (next)
- [ ] LiDAR scan publishing verified
- [ ] RealSense depth/color publishing verified
- [ ] URDF + TF tree verified in RViz
- [ ] Multi-machine visualization (Foxglove)

### Phase 3: Localization
- [ ] First SLAM mapping run
- [ ] Map quality validation
- [ ] Localization mode tested
- [ ] Pose accuracy benchmark

### Phase 4: Navigation
- [ ] Nav2 stack configuration tuned
- [ ] Point-to-point demo
- [ ] Obstacle avoidance demo
- [ ] Recovery behaviors

### Phase 5: Failover + ML
- [ ] Failover state machine deployed
- [ ] Visual Regression dataset collected (500-2000 samples)
- [ ] Random Forest model trained
- [ ] VR backup path validated

### Phase 6: Polish
- [ ] User manual finalized
- [ ] Demo video recorded
- [ ] Handover documentation for next batch

---

## Acknowledgments

Project dibimbing oleh dosen pembimbing tugas akhir, dengan sumber daya laboratorium ITS Surabaya. Code architecture mengikuti ROS 2 best practices (REP-105 untuk TF, REP-103 untuk units).

External libraries:
- [SLAM Toolbox](https://github.com/SteveMacenski/slam_toolbox) by Steve Macenski
- [Nav2](https://github.com/ros-planning/navigation2) Navigation Stack
- [rplidar_ros](https://github.com/Slamtec/rplidar_ros) by Slamtec
- [librealsense](https://github.com/IntelRealSense/realsense-ros) by Intel

---

## License

MIT License — see [LICENSE](LICENSE) file.
