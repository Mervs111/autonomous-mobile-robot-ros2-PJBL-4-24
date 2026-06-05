# 07 — Troubleshooting

> FAQ dan solusi masalah umum yang sering muncul.

---

## A. Boot & Network

### A1. NUC tidak boot
- Cek tombol Emergency apakah memutus 24V tapi 19V NUC tetap ada (relay NC tidak boleh memutus jalur NUC)
- Cek konektor power 19V dari buck converter ke NUC
- Cek baterai voltage ≥ 22.0 V

### A2. WiFi tidak auto-reconnect setelah boot
- Verify systemd service: `systemctl status amr-wifi-watchdog.service`
- Re-run setup: `sudo bash scripts/setup_network.sh "WiFi-Kampus-ITS"`
- Manual reconnect: `nmcli connection up "WiFi-Kampus-ITS"`

### A3. Cannot SSH dari laptop
- Verify NUC IP: dari NUC `hostname -I`
- Verify ping: dari laptop `ping <NUC_IP>`
- Try `ssh-keygen -R <NUC_IP>` (clear known_hosts)
- Pastikan SSH server jalan di NUC: `sudo systemctl status ssh`

### A4. ROS 2 multi-machine: laptop tidak lihat topik NUC
- Verify `ROS_DOMAIN_ID` sama di kedua mesin (kita pakai 42)
- Verify Discovery Server jalan: `systemctl status fastdds-discovery-server.service`
- Verify env: `echo $ROS_DISCOVERY_SERVER` (di laptop = IP NUC, di NUC = 127.0.0.1)
- Restart daemon: `ros2 daemon stop && ros2 daemon start`

---

## B. Sensor Issues

### B1. RPLIDAR tidak publishing /scan
- Cek device: `ls -l /dev/serial/by-id/ | grep CP2102N`
- Cek user dalam group dialout: `groups | grep dialout`
  - Jika tidak: `sudo usermod -aG dialout $USER` lalu logout+login
- Cek baudrate: 460800 untuk RPLIDAR C1 (bukan 115200!)
- Cek voltage 5V supply ke LiDAR (USB hub kadang kurang)

### B2. RealSense error "Failed to claim USB"
- Pakai kabel USB 3.0 berkualitas (kabel pendek <1m best)
- Pastikan colok ke port USB 3.0 (biru)
- Re-plug USB sampai 2x, terkadang firmware butuh reset
- Run `realsense-viewer` standalone untuk verify hardware OK

### B3. Joystick tidak terdetect
- Cek: `ls /dev/input/js*`
- Cek battery joystick wireless
- Test: `ros2 run joy joy_node` lalu `ros2 topic echo /joy`

### B4. Encoder tidak publishing
- Cek koneksi USB STM32: `ls -l /dev/serial/by-id/ | grep STM32`
- Update path di stm32_bridge.cpp (line 29) jika beda
- Cek STM32 firmware: harus print "E:0\n" tiap 50ms ke USB CDC

---

## C. Build & Compile

### C1. `colcon build` gagal: "package not found"
- Source ROS 2: `source /opt/ros/humble/setup.bash`
- Install missing deps: `rosdep install --from-paths src --ignore-src -y`
- Clean build: `rm -rf build install log` lalu `colcon build`

### C2. `realsense2_camera` tidak terdetect
- Install dari source jika apt version bermasalah:
  ```bash
  cd ~/amr_ws/src
  git clone -b ros2-master https://github.com/IntelRealSense/realsense-ros.git
  cd ~/amr_ws && colcon build
  ```

### C3. `slam_toolbox` parameter tidak match
- Cek versi: `ros2 pkg xml slam_toolbox`
- Update YAML config kalau ada deprecation warning

---

## D. Runtime Issues

### D1. SLAM gagal, peta tidak terbentuk
- Apakah `/scan` publishing? `ros2 topic hz /scan` harus 10 Hz
- Apakah TF `odom → base_link` ada? `ros2 run tf2_tools view_frames`
- Drive lebih perlahan saat mapping
- Verify wheel_radius akurat (UMBmark)

### D2. Nav2 stuck "Failed to compute path"
- Goal di area yang ter-map dan free?
- Inflation_radius tidak menutupi seluruh free space?
- Coba `tolerance: 0.5` di planner (lebih lenient)

### D3. Robot lambat respon `cmd_vel`
- Cek failover state: `ros2 topic echo /failover_status`
- Pastikan bukan EMERGENCY_STOP atau VISUAL_FALLBACK
- Cek USB CDC: `ros2 topic hz /encoder` harus ~20 Hz

### D4. Robot drive miring/oleng
- UMBmark calibration bermasalah
- Cek tekanan ban kanan-kiri sama
- Cek joint shaft transmisi tidak kendor

### D5. VR predict salah (robot nabrak)
- Naikkan `safety_min_depth` di params (mis. 0.5 m)
- Re-train model dengan lebih banyak data
- Cek pencahayaan (RealSense butuh cahaya cukup)

---

## E. Performance

### E1. NUC overheat / throttling
- Pasang fan tambahan
- Turunkan camera fps dari 30 ke 15 di sensors_launch.py
- Monitor: `watch -n1 sensors`

### E2. ROS 2 topic rate drop
- Cek CPU: `htop`
- Kurangi node yang jalan paralel (matikan rqt, RViz untuk debug)
- Pakai DDS Best Effort QoS untuk topik high-rate

### E3. Memory leak after 30+ min
- Cek dengan `smem -r -k`
- Suspect: rosbag2 recorder, slam_toolbox map cache
- Restart node periodically jika perlu

---

## F. Demo Day Checklist (1 jam sebelum demo)

- [ ] Baterai full charge ≥ 24.5V
- [ ] NUC boot, SSH OK
- [ ] WiFi konek, multi-machine OK
- [ ] All sensors publishing (verify di RViz)
- [ ] TF tree complete
- [ ] Map loaded di localization mode
- [ ] Test joystick R1 deadman
- [ ] Test E-stop hardware
- [ ] Backup video ready (kalau live demo gagal)
- [ ] Charge laptop operator full
- [ ] Charge joystick GX300 full
- [ ] Print PROGRESS.md dan dokumen ringkasan
