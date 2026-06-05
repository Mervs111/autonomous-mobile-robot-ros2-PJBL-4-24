# 06 — Failover Controller Guide

> Cara test, debug, dan tuning failover state machine.

---

## 1. State Machine Diagram

```
                     ┌─────────────────────────────────┐
                     │  EMERGENCY_STOP (priority 1)    │
                     │  trigger: scan range < 0.3 m    │
                     │  output:  cmd_vel = (0, 0)      │
                     └──────────────┬──────────────────┘
                                    │ (release)
                                    ▼
                     ┌─────────────────────────────────┐
                     │  JOY_OVERRIDE (priority 2)      │
                     │  trigger: deadman R1 pressed    │
                     │  output:  cmd_vel = cmd_vel_joy │
                     └──────────────┬──────────────────┘
                                    │ (release)
                                    ▼
                ┌──────────────────┐         ┌──────────────────┐
                │  SLAM_ACTIVE     │         │  VISUAL_FALLBACK │
                │  (default)       │ <─────> │                  │
                │  cmd_vel =       │         │  cmd_vel =       │
                │  cmd_vel_nav     │         │  cmd_vel_visual  │
                └──────────────────┘         └──────────────────┘
                  ▲                              ▲
                  │ slam_healthy 5s              │ slam_unhealthy 2s
                  │ (recovery hysteresis)        │ (fallback delay)
                  └──────────────────────────────┘
```

---

## 2. Health Conditions

### SLAM healthy = ALL of these true:
- `/scan` received within last `scan_timeout_s` (default 1.0s)
- `/map` received within last `map_timeout_s` (default 10.0s)

### Visual healthy = ALL of these true:
- `/cmd_vel_visual` received within last `visual_timeout_s` (default 0.5s)

---

## 3. Test Procedure (5 Scenarios)

### Test 1: SLAM → VISUAL fallback
```bash
# Setup: launch full system
ros2 launch amr_bringup amr_full.launch.py \
    slam_mode:=localization use_nav2:=true \
    use_vr:=true use_failover:=true map_name:=lab_map

# Step 1: Verify default state
ros2 topic echo /failover_status --once
# Expected: state="SLAM_ACTIVE"

# Step 2: Tutup LiDAR pakai tangan/kain
# (kill process: ros2 lifecycle set /rplidar_node shutdown)

# Step 3: Tunggu ~2 detik
ros2 topic echo /failover_status --once
# Expected: state="VISUAL_FALLBACK"

# Step 4: Verify cmd_vel forwarding
ros2 topic echo /cmd_vel /cmd_vel_visual
# Should be identical
```

### Test 2: VISUAL → SLAM recovery (hysteresis)
```bash
# Step 1: Re-enable LiDAR
ros2 lifecycle set /rplidar_node configure
ros2 lifecycle set /rplidar_node activate

# Step 2: Tunggu 5 detik (hysteresis recovery)
ros2 topic echo /failover_status --once
# Expected: state="SLAM_ACTIVE"
```

### Test 3: JOY_OVERRIDE
```bash
# Step 1: Pegang joystick + tekan R1
# Step 2: Verify state immediate
ros2 topic echo /failover_status --once
# Expected: state="JOY_OVERRIDE" (instant, no delay)
```

### Test 4: EMERGENCY_STOP
```bash
# Step 1: Letakkan kardus 25 cm di depan robot
# Step 2:
ros2 topic echo /failover_status --once
# Expected: state="EMERGENCY_STOP", min_scan_range_m < 0.30
ros2 topic echo /cmd_vel
# Expected: linear.x=0, angular.z=0
```

### Test 5: Cold restart recovery
```bash
# Step 1: Run system, drive sebentar di SLAM_ACTIVE
# Step 2: Ctrl+C semua nodes
# Step 3: Re-launch full system
# Step 4: Wait until topics published
ros2 topic echo /failover_status --once
# Expected: state="SLAM_ACTIVE"
```

---

## 4. RViz Visualization

Add **Marker** display dengan topic `/failover_marker`. Akan muncul sphere
di posisi robot dengan warna sesuai state:
- 🟢 Hijau = SLAM_ACTIVE
- 🟡 Kuning = VISUAL_FALLBACK
- 🔵 Biru = JOY_OVERRIDE
- 🔴 Merah = EMERGENCY_STOP

---

## 5. Tuning Parameters

| Parameter | Default | Tune kalau... |
|---|---|---|
| `fallback_delay_s` | 2.0 | Naikkan jika SLAM kadang stutter sebentar |
| `recovery_delay_s` | 5.0 | Turunkan untuk recovery cepat |
| `scan_timeout_s` | 1.0 | Naikkan jika LiDAR rate <10 Hz |
| `map_timeout_s` | 10.0 | Naikkan jika SLAM update lambat |
| `visual_timeout_s` | 0.5 | Naikkan jika VR < 5 Hz |
| `emergency_min_range` | 0.30 | Naikkan ke 0.40 untuk safer |

Override via launch:
```bash
ros2 launch amr_failover failover.launch.py \
    -p fallback_delay_s:=3.0 -p emergency_min_range:=0.4
```

---

## 6. Common Issues

### "State stuck di EMERGENCY_STOP"
- Cek `min_scan_range_m` — apakah benar ada obstacle dekat?
- Cek apakah noise di LiDAR (range = 0.0 atau NaN) — filter di code skip ini
- Solusi: pindahkan robot, atau temporary naikkan `emergency_min_range`

### "Flapping antara SLAM dan VISUAL"
- Hysteresis tidak cukup. Naikkan `recovery_delay_s` ke 8-10 detik.
- Atau cek apakah LiDAR memang intermitten — debug di hardware level.

### "JOY_OVERRIDE tidak responsive"
- Cek apakah `/cmd_vel_joy` diproduksi:
  ```bash
  ros2 topic echo /cmd_vel_joy
  ```
- Cek apakah teleop_twist_joy publish ke topic ini (atau `/cmd_vel`?)
- Mungkin perlu remap di launch file.
