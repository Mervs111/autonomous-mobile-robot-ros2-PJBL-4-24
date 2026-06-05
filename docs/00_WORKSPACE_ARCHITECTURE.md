# Workspace Architecture Guide

> Penjelasan konsep **dual workspace pattern** yang dipakai di proyek ini, kenapa kita pakai, dan bagaimana cara kerjanya.

---

## TL;DR (Untuk yang Buru-Buru)

Kami pakai **2 workspace terpisah**:

| Workspace | Purpose | Update Frequency |
|-----------|---------|------------------|
| `amr_underlay_ws` | Vendor drivers (stable) | Bulanan / saat update vendor |
| `amr_starter` | Active development | Setiap hari |

Saat error di `amr_starter`, **cukup reset overlay saja**, underlay tetap utuh.

---

## Konsep Dasar: ROS 2 Workspace Overlay

ROS 2 memungkinkan kamu source **multiple workspace** secara berlapis. Setiap workspace bisa "menumpuk" di atas workspace lain:

```bash
source /opt/ros/humble/setup.bash             # Layer 1: ROS 2 system
source ~/amr_underlay_ws/install/setup.bash   # Layer 2: stable vendor
source ~/amr_starter/install/setup.bash       # Layer 3: kerjaan aktif
```

Layer atas **bisa override** package dengan nama sama di layer bawah. Ini powerful — kamu bisa:
- Pakai versi vendor stable (di underlay)
- Develop versi modifikasi (di overlay) tanpa ganggu yang stable

---

## Kenapa Pisah Dua?

### Skenario "Setelah Kerja Eksperimen"

**Tanpa dual workspace** (semua di 1 folder):
```
Day 1: Workspace masih bersih, semua jalan.
Day 5: Kamu install custom Nav2 plugin, eksperimen.
Day 7: Plugin error, build fail.
Day 8: Coba clean rebuild → 30 menit + butuh internet.
Day 9: rplidar_ros juga ikut error karena cache build campur.
Day 10: Frustasi, mulai lagi dari nol.
```

**Dengan dual workspace**:
```
Day 1: Underlay sudah stable, overlay bersih.
Day 5: Eksperimen custom Nav2 plugin → di overlay saja.
Day 7: Plugin error, overlay broken.
Day 8: rm -rf ~/amr_starter && unzip backup → 30 detik.
        Underlay tidak terganggu. rplidar tetap jalan.
Day 9: Lanjut kerja.
```

### Skenario "Test Hardware Saja"

**Tanpa dual workspace**: harus build seluruh proyek dulu untuk test RPLIDAR.

**Dengan dual workspace**: kamu bisa source underlay only:
```bash
source /opt/ros/humble/setup.bash
source ~/amr_underlay_ws/install/setup.bash
ros2 launch rplidar_ros rplidar_c1_launch.py
```

Tidak perlu peduli apakah amr_starter sedang error atau tidak.

---

## Mapping ke Konsep Filesystem

```
~/                                    ← Home folder
├── amr_underlay_ws/                  ← UNDERLAY workspace
│   ├── src/                          ← Source code vendor
│   │   └── rplidar_ros/              ← Stable, jangan modify
│   ├── build/                        ← Build artifacts (auto-generated)
│   ├── install/                      ← Final binaries (yang dipakai runtime)
│   │   └── setup.bash                ← Source ini untuk activate
│   └── log/                          ← Build logs
│
└── amr_starter/                      ← OVERLAY workspace
    ├── src/                          ← Source code kerjaan kita
    │   ├── amr_bringup/
    │   ├── amr_controller/
    │   ├── amr_description/
    │   ├── amr_failover/
    │   ├── amr_slam/
    │   └── amr_visual_regression/
    ├── build/
    ├── install/
    │   └── setup.bash
    ├── log/
    ├── docs/                         ← Dokumentasi
    ├── scripts/                      ← Setup & utility scripts
    └── maps/                         ← SLAM map outputs
```

---

## Workflow Sehari-hari

### Setiap kali buka terminal baru
**Tidak perlu ngapa-ngapain** — `.bashrc` sudah auto-source. Cek dengan:
```bash
echo $ROS_DOMAIN_ID    # Harus: 42
ros2 pkg list | wc -l  # Harus: 200+ (semua paket terdaftar)
```

### Setelah edit code di amr_starter
```bash
cd ~/amr_starter
colcon build --packages-select <nama_package>
source install/setup.bash    # Refresh di terminal yang sudah jalan
```

### Setelah edit code di underlay (jarang)
```bash
cd ~/amr_underlay_ws
colcon build --symlink-install
source install/setup.bash
# Lalu rebuild overlay supaya dependency fresh:
cd ~/amr_starter
colcon build --symlink-install
source install/setup.bash
```

### Saat overlay rusak
```bash
cd ~
mv amr_starter amr_starter_BROKEN_$(date +%Y%m%d)   # Backup yang rusak
unzip amr_starter_v2.zip                             # Extract versi baik
cd amr_starter
colcon build --symlink-install
source install/setup.bash
```

Underlay tetap utuh.

---

## Common Pitfalls

### "Saya build, tapi node baru tidak ke-detect"
Build hanya menulis ke `install/`. Terminal yang sudah jalan masih pakai PATH lama. Solusi: re-source.
```bash
source install/setup.bash
```

### "Saya source, tapi command tidak ada"
Mungkin source order salah. Cek dengan `printenv | grep AMENT_PREFIX_PATH`. Harus muncul amr_starter dan amr_underlay_ws.

### "Build error: package not found"
Mungkin underlay belum di-build. Run:
```bash
cd ~/amr_underlay_ws && colcon build --symlink-install
source install/setup.bash
cd ~/amr_starter && colcon build --symlink-install
```

### "Symlink install: changes di Python tidak ter-reflect"
`--symlink-install` membuat install/ symlink ke src/. Edit Python langsung effective tanpa rebuild. Tapi kalau **edit setup.py atau package.xml**, harus rebuild.

---

## Untuk Tim atau Successor

Saat handover ke angkatan berikutnya, kasih mereka **2 ZIP terpisah**:
1. `amr_underlay_ws.zip` — vendor stuff, biarkan
2. `amr_starter.zip` — kerjaan, ini yang mereka develop

Plus DEPLOYMENT_GUIDE.md untuk step-by-step setup.

Manfaat: kalau mereka eksperimen dan rusakin, mereka cukup reset overlay tanpa risiko kehilangan vendor driver yang sudah ke-build dengan benar.

---

## Industry Standard

Pattern ini standar di proyek robotika industri:

- **Clearpath Robotics** (Husky, Jackal): underlay = vendor + ROS, overlay = robot-specific
- **Boston Dynamics** (Spot SDK): underlay = SDK, overlay = applications
- **ROBOTIS** (TurtleBot3): underlay = vendor packages, overlay = user packages

Jadi kamu **belajar pattern yang dipakai di industri**, bukan custom buatan sendiri.

---

## Reference

- [ROS 2 Workspace Documentation](https://docs.ros.org/en/humble/Tutorials/Beginner-Client-Libraries/Creating-A-Workspace/Creating-A-Workspace.html)
- [ROS 2 Overlay Tutorial](https://docs.ros.org/en/humble/Tutorials/Beginner-Client-Libraries/Creating-Your-First-ROS2-Package.html#colcon-build)
- [REP 122 — Filesystem Hierarchy](https://www.ros.org/reps/rep-0122.html)
