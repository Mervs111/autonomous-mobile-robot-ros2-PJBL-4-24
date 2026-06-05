# 02 — Development Guide

> Untuk **developer / mahasiswa lanjutan** yang akan memodifikasi atau
> mengembangkan platform ini. Berisi arsitektur software, build system,
> dan konvensi coding.

---

## 1. Arsitektur Software

```
                   ┌────────────────────────────────────┐
                   │  Laptop Operator                    │
                   │  RViz + rqt + DDS Discovery client  │
                   └─────────────┬──────────────────────┘
                                 │ WiFi kampus
                                 │ (Fast DDS Discovery Server)
                   ┌─────────────▼──────────────────────┐
                   │  NUC (Ubuntu 22.04 + ROS 2 Humble) │
                   │                                     │
                   │  ┌─────────────┐  ┌──────────────┐ │
                   │  │  amr_       │  │ amr_visual_  │ │
                   │  │  bringup    │  │ regression   │ │
                   │  │  + sensors  │  │  (Path B)    │ │
                   │  └──────┬──────┘  └──────┬───────┘ │
                   │         │                │         │
                   │         ▼                ▼         │
                   │  ┌──────────────────────────────┐  │
                   │  │     amr_failover             │  │
                   │  │     (cmd_vel arbiter)        │  │
                   │  └──────┬───────────────────────┘  │
                   │         │ /cmd_vel                 │
                   │         ▼                          │
                   │  ┌──────────────────────────────┐  │
                   │  │     amr_controller           │  │
                   │  │     stm32_bridge.cpp         │  │
                   │  └──────┬───────────────────────┘  │
                   └─────────┼──────────────────────────┘
                             │ USB CDC 12 Mbps
                   ┌─────────▼──────────────────────────┐
                   │  STM32F407VGTx (bare-metal C)      │
                   │  TIM3 PWM, TIM12 PWM, TIM2 encoder │
                   └────────────────────────────────────┘
```

---

## 2. Cara Install Development Environment

### 2.1 Sistem operasi
- Ubuntu 22.04 LTS (HWE kernel 6.2+ recommended for NUC 13)
- Bukan Ubuntu 20.04, 24.04, atau distro lain.

### 2.2 ROS 2 Humble
Ikuti panduan resmi: https://docs.ros.org/en/humble/Installation/Ubuntu-Install-Debians.html

```bash
sudo apt install ros-humble-desktop
echo 'source /opt/ros/humble/setup.bash' >> ~/.bashrc
source ~/.bashrc
```

### 2.3 Workspace
```bash
mkdir -p ~/amr_ws/src
cd ~/amr_ws/src
git clone https://github.com/muhammadalazharf/autonomous-mobile-robot-ros2.git .
```

### 2.4 Dependencies otomatis
```bash
cd ~/amr_ws
chmod +x scripts/install_deps.sh
./scripts/install_deps.sh
```

### 2.5 Build
```bash
cd ~/amr_ws
colcon build --symlink-install
source install/setup.bash
```

> Tip: pakai `--symlink-install` agar perubahan launch file tidak butuh re-build.

---

## 3. Cara Run

### 3.1 Run individual node (untuk development)
```bash
# Terminal 1: bringup hardware
ros2 launch amr_bringup amr_launch.py

# Terminal 2: sensors
ros2 launch amr_bringup sensors_launch.py

# Terminal 3: odometry
ros2 run amr_controller odometry_publisher.py

# Terminal 4: SLAM
ros2 launch amr_slam slam_mapping.launch.py
```

### 3.2 Run all-in-one (untuk operasi normal)
```bash
ros2 launch amr_bringup amr_full.launch.py [args]
```

### 3.3 Debug single Python node
```bash
# Run node Python langsung tanpa colcon build:
cd ~/amr_ws/src/amr_visual_regression
python3 -m amr_visual_regression.vr_inference_node

# atau dengan parameter:
python3 -m amr_visual_regression.vr_inference_node \
    --ros-args -p model_path:=/tmp/test_model.pkl
```

---

## 4. Konvensi Coding

### Python (PEP 8 style)
- Indent: 4 spasi
- Line length: max 100 karakter
- Docstring: triple double-quote, format Google atau NumPy
- Type hints di function signatures (optional tapi recommended)

```python
def extract_features(depth_image: np.ndarray,
                     num_regions: int = 9) -> np.ndarray:
    """Extract depth statistics from image.

    Args:
        depth_image: 2D uint16 array (mm).
        num_regions: Number of vertical regions.

    Returns:
        Feature vector shape (num_regions * 4,)
    """
    ...
```

### C++ (ROS 2 style)
- Indent: 2 spasi
- Brace: same line (Java style)
- Naming: `snake_case` for variables/functions, `CamelCase` for classes
- File header: include license + author

```cpp
class STM32Bridge : public rclcpp::Node {
public:
  STM32Bridge() : Node("stm32_bridge") {
    // ...
  }
private:
  void joy_callback(const sensor_msgs::msg::Joy::SharedPtr msg) {
    // ...
  }
};
```

### Naming convention untuk topics
- `/cmd_vel`           — final cmd_vel ke robot
- `/cmd_vel_nav`       — output Nav2 (sebelum failover)
- `/cmd_vel_visual`    — output Visual Regression
- `/cmd_vel_joy`       — output joystick (untuk override)
- `/odom`              — wheel-only odometry
- `/odometry/filtered` — fused (kalau nanti add IMU + EKF)
- `/scan`              — LiDAR raw
- `/camera/...`        — RealSense topics

---

## 5. Cara Contribute

### Branch strategy
- `main` — stable, hanya merge dari `develop` setelah test
- `develop` — integrasi feature baru
- `feature/<name>` — branch per fitur
- `hotfix/<name>` — bug critical

### Commit message convention
Format: `[component] description`

Examples:
```
[odometry] fix encoder auto-detect for cumulative mode
[vr]       add data augmentation: horizontal flip
[urdf]     update camera position after re-mounting
[docs]     add troubleshooting for SLAM yaw drift
```

### Pull Request checklist
- [ ] Build pass: `colcon build --symlink-install`
- [ ] No new warning di `colcon test`
- [ ] Update `PROGRESS.md` jika milestone
- [ ] Update relevant docs/

---

## 6. Folder Reference

```
amr_ws/src/
├── amr_bringup/        # Launch files orchestration
├── amr_controller/     # stm32_bridge (C++) + odometry (Python)
├── amr_description/    # URDF/Xacro
├── amr_failover/       # State machine cmd_vel arbiter
├── amr_slam/           # SLAM Toolbox + Nav2 config
├── amr_visual_regression/  # Path B
└── rplidar_ros/        # Driver LiDAR (3rd party)
```

---

## 7. Future Work / Ideas

- [ ] Tambah IMU BNO055 untuk EKF fusion (mengurangi yaw drift)
- [ ] Upgrade VR dari klasik ke CNN (PyTorch MobileNetV2 + regression head)
- [ ] Multi-AMR fleet via VDA 5050 standard
- [ ] OPC UA + Sparkplug B untuk integrasi SCADA industri
- [ ] Behavior tree custom untuk skenario kompleks
- [ ] Simulasi Gazebo Harmonic + ros2_control
