# 01 — User Manual (Pengoperasian Robot)

> Panduan operator harian untuk Mobile Robot Ackermann Indoor Platform.
> **Audience:** Mahasiswa angkatan berikutnya yang akan mengoperasikan
> robot tanpa harus memahami detail kode.

> _Catatan: file ini adalah skeleton. Lengkapi screenshot dan foto
> di akhir proyek (Day 19-20) sesuai PROGRESS.md._

---

## Daftar Isi
1. [Anatomi Robot](#1-anatomi-robot)
2. [Persiapan Sebelum Operasi](#2-persiapan-sebelum-operasi)
3. [Prosedur Startup](#3-prosedur-startup)
4. [Mode Mapping](#4-mode-mapping-buat-peta-baru)
5. [Mode Localization & Navigation](#5-mode-localization--navigation)
6. [Mode Wandering (Visual Regression)](#6-mode-wandering-autonomous)
7. [Emergency Stop & Safety](#7-emergency-stop--safety)
8. [Shutdown Procedure](#8-shutdown-procedure)
9. [Quick Troubleshooting](#9-quick-troubleshooting)

---

## 1. Anatomi Robot

> _TODO: Sisipkan foto robot dengan label panah ke setiap komponen._
> _Foto sudut depan, samping, dan atas. Resolusi minimal 1920×1080._

![Anatomi Robot AMR](images/robot_anatomy.jpg)

| No | Komponen | Letak | Fungsi |
|---|---|---|---|
| 1 | Intel NUC 13 i7 | Atas chassis | High-level controller, jalankan ROS 2 |
| 2 | STM32F407 board | Tengah chassis | Low-level controller, motor + servo + encoder |
| 3 | Driver BTS7960 | Samping STM32 | Driver motor PG45 |
| 4 | Motor PG45 24V | Belakang chassis | Traksi 4 roda via differential |
| 5 | Servo DS3225 | Depan chassis | Steering Ackermann |
| 6 | Encoder kuadratur | Pada PG45 shaft | Feedback posisi roda |
| 7 | RPLIDAR C1 | Atas robot, tengah | Sensor utama SLAM |
| 8 | RealSense D455 | Depan robot | Visual Regression |
| 9 | Baterai LiPo 6S | Bawah/samping chassis | Catu daya 22.2V (5300 mAh) |
| 10 | Buck converter | Samping baterai | Step-down ke 19V/6V/5V |
| 11 | Tombol Emergency | Samping atas chassis | Hardware E-stop (relay NC) |
| 12 | Tombol Power | Atas chassis | Soft on/off |

---

## 2. Persiapan Sebelum Operasi

### 2.1 Cek Baterai
- Voltase baterai ≥ 22.0 V (cek dengan voltmeter atau LED indicator).
- Jika < 22.0 V → **JANGAN** dioperasikan, charge dulu.
- _TODO: foto cara cek voltase baterai_

### 2.2 Cek Hardware
- [ ] Kabel USB STM32 ke NUC terhubung
- [ ] Kabel USB LiDAR terhubung
- [ ] Kabel USB RealSense terhubung (port USB 3.0!)
- [ ] Joystick dongle wireless terpasang di NUC
- [ ] Tombol Emergency dalam posisi **lepas/keluar** (bukan ditekan)

### 2.3 Lingkungan
- Pencahayaan terang (jangan gelap, RealSense butuh cahaya).
- Lantai bertekstur (granit/keramik dengan nat) — jangan polos licin.
- Pastikan tidak ada kabel berantakan di lantai.
- Pastikan area aman: tidak ada anak kecil, hewan, barang fragile.

---

## 3. Prosedur Startup

```bash
# 1. Tekan power button NUC → tunggu boot Ubuntu (~30 detik)
# 2. Verifikasi WiFi konek (auto-reconnect aktif)
# 3. Dari laptop operator, SSH ke NUC:
ssh azhar@nuc-amr.local        # atau IP statis NUC

# 4. Source ROS 2 + workspace
source /opt/ros/humble/setup.bash
source ~/amr_ws/install/setup.bash

# 5. Verifikasi sensor terdetect:
ls -l /dev/serial/by-id/       # harus ada STM32 + RPLIDAR
realsense-viewer --info        # harus detect D455

# 6. Pilih mode operasi (lihat section 4-6 di bawah)
```

---

## 4. Mode Mapping (Buat Peta Baru)

Gunakan saat **pertama kali** masuk ruangan baru, atau saat ruangan diubah.

```bash
ros2 launch amr_bringup amr_full.launch.py slam_mode:=mapping
```

**Cara drive:**
- Tekan & tahan **R1** di joystick (deadman switch)
- Stik kiri (atas-bawah) → maju/mundur
- Stik kanan (kiri-kanan) → steering kiri/kanan
- Lepas R1 → robot stop instan

**Tips mapping yang baik:**
- Drive **perlahan** (max 0.3 m/s) supaya scan-matching tidak gagal.
- Drive **berputar lengkap** keliling ruangan.
- Lewati setiap koridor 2× (sekali pergi, sekali pulang) untuk loop closure.
- Hindari area yang terlalu mirip (lorong panjang tanpa fitur).

**Save map saat selesai:**
```bash
ros2 run nav2_map_server map_saver_cli -f ~/amr_ws/maps/lab_map
```

> _TODO: screenshot RViz saat mapping bagus_
> _TODO: contoh hasil map .pgm_

---

## 5. Mode Localization & Navigation

Gunakan setelah peta sudah ada untuk **autonomous navigation** ke goal pose.

```bash
ros2 launch amr_bringup amr_full.launch.py \
    slam_mode:=localization \
    use_nav2:=true \
    map_name:=lab_map
```

**Set goal pose:**
1. Buka RViz dari laptop (multi-machine via Discovery Server)
2. Klik tool **"2D Goal Pose"**
3. Klik dan drag di peta → set posisi & orientasi target
4. Robot akan mulai bergerak otomatis

> _TODO: screenshot RViz dengan goal pose + planned path_

---

## 6. Mode Wandering (Autonomous + VR Failover)

Mode demo unggulan: robot menjelajah autonomous dengan SLAM sebagai navigasi utama,
dan Visual Regression sebagai backup jika SLAM gagal.

```bash
ros2 launch amr_bringup amr_full.launch.py \
    slam_mode:=localization \
    use_nav2:=true \
    use_vr:=true \
    use_failover:=true \
    map_name:=lab_map
```

**Indikator status di RViz** (Marker `/failover_marker`):
- 🟢 **Hijau** = SLAM_ACTIVE (default mode)
- 🟡 **Kuning** = VISUAL_FALLBACK (SLAM gagal, VR ambil alih)
- 🔵 **Biru** = JOY_OVERRIDE (operator pegang R1)
- 🔴 **Merah** = EMERGENCY_STOP

> _TODO: screenshot 4 kondisi marker_

---

## 7. Emergency Stop & Safety

### Hardware E-Stop (Prioritas tertinggi)
Tekan **tombol merah** di samping atas chassis → memutus jalur 24V ke
motor secara fisik (relay NC). Robot akan berhenti dalam <100 ms.

**Reset:** putar/lepas tombol → cycling power motor.

### Software Emergency
- LiDAR detect obstacle <30 cm → otomatis EMERGENCY_STOP
- Lepas R1 deadman saat manual drive → cmd_vel = 0

### Safety Best Practices
- **Selalu** ada operator standby dengan joystick saat demo
- **Jangan** drive dengan mata tertutup ke arah obstacle
- **Jangan** charge baterai sambil robot dipakai
- **Jangan** drive di lantai basah/licin

---

## 8. Shutdown Procedure

```bash
# 1. Stop semua node ROS 2 (Ctrl+C di setiap terminal)

# 2. Shutdown NUC dengan benar:
sudo shutdown now

# 3. Tunggu LED NUC mati (~10 detik)

# 4. Tekan tombol Emergency Stop (menyimpan state)

# 5. Cabut konektor baterai
```

> ⚠️ **JANGAN** cabut baterai saat NUC masih nyala — bisa rusak SSD.

---

## 9. Quick Troubleshooting

| Gejala | Cek | Solusi |
|---|---|---|
| Robot tidak gerak saat R1 ditekan | Tombol E-stop ditekan? | Lepas tombol E-stop |
| Tidak bisa SSH ke NUC | WiFi NUC terhubung? | `nmcli connection up "WiFi-Kampus-ITS"` |
| LiDAR no data | Cek port `/dev/serial/by-id/` | Re-plug USB LiDAR |
| RealSense error | USB 2.0 port? | Pindah ke USB 3.0 |
| SLAM map crooked | Wheel slip / odometry drift | Re-do UMBmark calibration |
| VR salah prediksi | Pencahayaan kurang | Tambah lampu, cek RealSense IR |
| Failover stuck di kuning | LiDAR mati permanent | Restart `rplidar_node` |

Untuk troubleshooting mendalam → lihat [`07_TROUBLESHOOTING.md`](07_TROUBLESHOOTING.md).
