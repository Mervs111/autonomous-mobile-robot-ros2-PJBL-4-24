# 04 — Visual Regression Guide

> Cara collect dataset, train model, dan deploy Visual Regression Path B.

---

## 1. Konsep Singkat

**Visual Regression** = model regresi klasik (Random Forest) yang menerima
fitur statistik dari depth map RealSense D455 → memprediksi steering angle
dan velocity untuk obstacle avoidance.

**Bukan CNN** — kami pakai approach klasik karena:
- Tidak butuh GPU (jalan di CPU NUC 13)
- Training cepat (~5-15 menit)
- Mudah di-debug & explain ke dosen
- Cukup akurat untuk obstacle avoidance indoor

**Pipeline:**
```
Depth Image (16UC1, 640x480)
    ↓ ROI crop (rows 200-360)
    ↓ Bagi 9 region vertikal
    ↓ Per region: extract 4 fitur (mean, min, free_ratio, std)
    ↓ Total 36 fitur
    ↓ StandardScaler
    ↓ Random Forest Regressor (multi-output)
    ↓ Output: (steering_norm, velocity_norm) ∈ [-1, +1]
    ↓ Scale ke (steering_rad, velocity_mps)
    ↓ Safety check: min_depth > 0.4m?
    ↓ Publish /cmd_vel_visual
```

---

## 2. Collect Dataset

### Persiapan
```bash
# Pastikan semua sudah jalan:
ros2 launch amr_bringup amr_full.launch.py use_slam:=false
```

### Run data collector
```bash
ros2 launch amr_visual_regression collect_dataset.launch.py \
    output_dir:=/home/azhar/datasets \
    capture_rate:=10.0
```

### Recording session (target ~45 menit)
| Skenario | Durasi | Fokus |
|---|---|---|
| Lurus di koridor | 5 menit | Baseline mengetahui "free space" depan |
| Belok kiri-kanan random | 10 menit | Variasi steering |
| Mendekati dinding lalu menjauh | 10 menit | Variasi depth |
| Hindari obstacle (kursi, kardus) | 10 menit | Skenario utama |
| Eksplorasi penuh (ruang kelas) | 10 menit | Generalisasi |

### Verifikasi dataset
```bash
ls ~/datasets/run_<timestamp>/
# Harus ada: depth_*.npy, color_*.jpg, labels.csv

wc -l ~/datasets/run_<timestamp>/labels.csv
# Target: 27.000+ rows (10 Hz × 45 menit)
```

> **Tip:** gunakan `record_only_when_deadman=true` (default) supaya
> hanya frame saat kamu aktif kontrol yang ter-record. Ini menghindari
> frame "robot diam" yang tidak informatif.

---

## 3. Train Model

```bash
cd ~/amr_ws
python3 src/amr_visual_regression/scripts/train.py \
    --dataset ~/datasets/run_<timestamp> \
    --output ~/models \
    --num-regions 9 \
    --n-estimators 100 \
    --max-depth 15
```

**Output:**
- `~/models/vr_model.pkl` — trained RandomForest
- `~/models/vr_scaler.pkl` — StandardScaler
- `~/models/train_report.txt` — metrics
- `~/models/scatter_plot.png` — visualization

### Target metrics
| Metric | Target | Acceptable |
|---|---|---|
| MAE steering | < 0.10 | < 0.15 |
| MAE velocity | < 0.05 | < 0.10 |
| R² steering | > 0.6 | > 0.5 |
| R² velocity | > 0.6 | > 0.5 |

### Jika R² < 0.3 (poor)
Kemungkinan penyebab:
1. **Dataset terlalu sedikit** — minimal 5.000 frame yang valid
2. **Dataset tidak konsisten** — operator drive berbeda-beda untuk situasi yang sama
3. **Pencahayaan berubah** — collect lagi dengan kondisi pencahayaan tetap
4. **Model under-fit** — naikkan `--n-estimators 200` atau `--max-depth 20`

### Jika R² > 0.95 di test (suspicious)
- Mungkin **data leakage**: train/test split nggak random
- Atau dataset terlalu mirip-mirip → tidak generalize ke real situation

---

## 4. Deploy Inference

```bash
ros2 launch amr_visual_regression vr_inference.launch.py \
    model_path:=/home/azhar/models/vr_model.pkl \
    scaler_path:=/home/azhar/models/vr_scaler.pkl
```

### Verifikasi
```bash
ros2 topic echo /cmd_vel_visual
# Harus publish 10 Hz dengan linear.x dan angular.z

ros2 topic echo /vr_debug
# JSON dengan steering_rad, velocity_mps, min_depth_m, safety_stop
```

### Tuning
Parameter yang sering perlu di-tune:
- `safety_min_depth` (default 0.4m) — naikkan kalau robot terlalu agresif
- `vx_max` (default 0.4 m/s) — turunkan kalau VR sering nabrak
- `steer_max_rad` (default 0.785) — sesuaikan dengan limit servo fisik

---

## 5. Debug Tips

### Visualize features di Python
```python
import numpy as np
import matplotlib.pyplot as plt
from amr_visual_regression.feature_extractor import extract_features

depth = np.load('~/datasets/run_xxx/depth_000050.npy')
feats = extract_features(depth)

# 9 region × 4 stats
mean_d = feats[0::4]
min_d  = feats[1::4]
free_r = feats[2::4]
std_d  = feats[3::4]

fig, axs = plt.subplots(2, 2, figsize=(12, 8))
axs[0,0].bar(range(9), mean_d); axs[0,0].set_title('Mean depth (m)')
axs[0,1].bar(range(9), min_d);  axs[0,1].set_title('Min depth (m)')
axs[1,0].bar(range(9), free_r); axs[1,0].set_title('Free space ratio')
axs[1,1].bar(range(9), std_d);  axs[1,1].set_title('Depth std (m)')
plt.tight_layout()
plt.savefig('feature_check.png')
```

### Inference latency benchmark
```bash
ros2 topic hz /cmd_vel_visual
# Target: 9-11 Hz (sesuai publish_rate=10)
# Jika <8 Hz: NUC overload, kurangi num_regions atau publish_rate
```

---

## 6. Limitations & Future Work

### Known limitations:
- **Sensitif terhadap pencahayaan**: RealSense IR proyektor butuh cahaya cukup
- **Tidak generalize antar lingkungan**: model harus di-train ulang per ruangan
- **Tidak ada memori**: keputusan murni reactive, tidak ingat path

### Possible upgrades:
1. **CNN end-to-end**: PyTorch MobileNetV2 + regression head (butuh GPU)
2. **Recurrent model (LSTM)**: tambah memori jangka pendek
3. **Multi-modal fusion**: gabung depth + LiDAR feature → lebih robust
4. **Active learning**: model uncertain → trigger operator override → record sebagai training sample baru
