# HANDOVER — Re-Mapping Bersih + Validasi Lokalisasi — 18 Juni 2026

**Dari:** Mararevi Subagyo (2040241036) · **Untuk:** Tim AMR (Kelompok PJBL 4-24)
**Status:** ✅ **Peta baru `lab_demo_18jun.db` dibuat & tervalidasi → jadi peta KANONIK untuk demo & Nav2.**

> Mengisi celah antara [HANDOVER_LOKALISASI_17JUNI](HANDOVER_LOKALISASI_17JUNI.md)
> (breakthrough lokalisasi) dan [HANDOVER_NAV2_AUTONOMOUS_19JUNI](HANDOVER_NAV2_AUTONOMOUS_19JUNI.md)
> (Nav2 jalan). Semua kerja Nav2 19 Juni **berdiri di atas peta yang dibuat hari ini.**

---

## 1. TL;DR

Peta hasil 17 Juni (`lab_demo_17jun.db`) **terlalu panjang & kotor** — 1224 pose,
lintasan ~175 m (banyak lap berulang) → 3D cloud "menjalar"/ghosting karena akumulasi
drift VIO. Pada 18 Juni dilakukan **mapping ulang BERSIH satu sesi, satu loop pendek**
→ menghasilkan **`lab_demo_18jun.db`** (448 pose, 28,9 m). Peta ini jauh lebih rapi,
konsisten, dan **berhasil dilokalisasi (loop closure hijau)**. Sejak saat ini
`lab_demo_18jun.db` dipakai sebagai peta acuan.

---

## 2. Kenapa perlu mapping ulang (padahal 17 Juni sudah lock?)

| Masalah peta 17 Juni | Akibat |
|---|---|
| Lintasan ~175 m, banyak lap | Akumulasi drift VIO → 3D cloud ghosting/"menjalar" |
| 1224 pose, DB 1.2 GB | Berat, banyak node redundan |
| Kondisi (lighting/tata ruang) terus berubah | Relokalisasi makin tidak stabil |

**Pelajaran:** untuk lokalisasi yang andal, **mapping 1 loop pendek & bersih** jauh lebih
baik daripada keliling lama berulang-ulang. Kualitas > kuantitas.

---

## 3. Yang dilakukan (18 Juni)

1. Mapping ulang area dalam **satu sesi** (~17 menit, total lintasan 28,9 m), **satu
   loop**, gerak pelan, kamera selalu menghadap area bertekstur.
2. Simpan sebagai `~/maps/lab_demo_18jun.db`.
3. Validasi: jalankan mode localization terhadap peta baru di sesi yang sama →
   **loop closure DITERIMA (background hijau)**, robot tahu posisinya & koreksi sendiri.

---

## 4. Hasil & Bukti (data nyata `rtabmap-info`)

```
Path:                 ~/maps/lab_demo_18jun.db
Version:              0.22.1     |  Sessions: 1
Total odometry length: 28,9 m   |  Total time: 1012 s (~17 menit)
LTM:                 1846 nodes, 126.506 words
WM (optimized graph): 448 poses
Links:  Neighbor 447 (avg 0,06 m) · GlobalClosure 125 · LocalSpaceClosure 648
Database size:        743 MB  (Depth 56% · RGB 25% · Grid 5% · Features 10%)
```

| Metrik | Nilai | Verdict |
|---|---|---|
| Global loop closure | **125** | 🟢 sangat sehat (lab kecil cukup 10–20) |
| Proximity (LocalSpace) | **648** | 🟢 banyak revisit → constraint kuat, drift ~nol |
| Jarak antar-keyframe | **0,06 m** | ✅ trajektori mulus |
| Sessions | 1 | ✅ single coherent run |

**Bukti visual (lampirkan screenshot yang sudah ada):**
- Loop closure hijau di `rtabmap_viz`: **New ID = 2436 ↔ Match ID = 1831** (match diterima).
- `rtabmap-databaseViewer lab_demo_18jun.db` → Graph view (448 pose), 3D cloud, Constraints view.

> *(Simpan kedua screenshot sebagai PNG dan taruh di `docs/img/` lalu tautkan di sini.)*

---

## 5. Konfigurasi mapping (yang menghasilkan peta bagus ini)

Parameter ini ter-baked di dalam `.db` (semua optimal untuk lab low-texture):

```
Reg/Strategy: 2            (Vis + ICP)
Reg/Force3DoF: true        (ground vehicle)
Rtabmap/LoopThr: 0.05      (loop closure agresif)
Rtabmap/DetectionRate: 2.0
Vis/FeatureType: 8         (GFTT/BRIEF)
Vis/MaxFeatures: 1000
Vis/MinInliers: 8
GFTT/QualityLevel: 0.001   (sensitif, utk area minim tekstur)
RGBD/ProximityBySpace: true
RGBD/LocalRadius: 5.0
RGBD/LoopClosureReextractFeatures: true
Optimizer/GravitySigma: 0.3 (IMU gravity aktif)
RGBD/CreateOccupancyGrid: true
```

> ⚠️ **Penting untuk localization:** ambang di mode localization harus disamakan dengan
> nilai mapping di atas (terutama `LoopThr 0.05` & `MinInliers 8`). Kalau localization
> dipasang lebih ketat (mis. LoopThr 0.11, MinInliers 10) → banyak loop rejection padahal
> petanya bagus.

---

## 6. File peta

- **Peta kanonik:** `~/maps/lab_demo_18jun.db`
- **Backup:** `~/maps/lab_demo_18jun_LOCKED_DEMO.db` (jangan ditimpa)
- Folder `~/maps/` dipakai BARENG tim → **jangan dua orang benahi/arsip bareng**. Sepakati
  `lab_demo_18jun.db` = acuan. (peta-peta lama 9–17 Juni boleh diarsip ke `~/maps/_archive/`)

---

## 7. Known issues (saat 18 Juni)

1. **Drift VIO** masih ada (sumber: lab low-texture + IMU RealSense sempat warning). Loop
   closure mengoreksi untuk localization, tapi cloud bisa sedikit ghosting.
2. **Layout ruangan berubah-ubah** → lock kadang tipis. Solusi tuntas: re-map setiap ada
   perubahan layout signifikan.
3. Hardware: jaga LiPo > 22 V, charge joystick (input drift kalau lowbat).

---

## 8. Next steps (yang kemudian dikerjakan 19 Juni)

1. ✅ Jalankan Nav2 di atas peta ini → lihat [HANDOVER_NAV2_AUTONOMOUS_19JUNI](HANDOVER_NAV2_AUTONOMOUS_19JUNI.md).
2. (Opsional) Re-map ulang kalau layout berubah lagi sebelum demo.

**Inti 18 Juni:** fondasi peta yang bersih & tervalidasi sudah ada. Tanpa ini, Nav2
19 Juni tidak akan punya peta yang bisa dipakai untuk planning.
