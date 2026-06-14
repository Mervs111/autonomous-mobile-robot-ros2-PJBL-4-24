# Kalibrasi Odometri (Jarak) — 14 Juni 2026

Uji korelasi **jarak odometri** vs **jarak sebenarnya** (meteran), sekaligus tugas
korelasi mata kuliah **Metode Numerik** (regresi linier kuadrat terkecil).

## Metode
Robot diperintah maju lurus pada 5 jarak odometri acuan (perintah `F:` via
`amr_loop_patrol.py`), tiap jarak 3× ulangan → 15 data. Odom dibaca dari selisih
`/odom` (`pose.position.x`); jarak nyata diukur meteran terhadap perpindahan
**poros roda belakang** (titik acuan model bicycle).

## Data (15 titik)

| F | Odom (m) — 3 trial | Real (cm) — 3 trial |
|---|---|---|
| 0.5 | 0.5511 / 0.5507 / 0.5231 | 21.0 / 21.5 / 21.0 |
| 1.0 | 1.0501 / 1.0465 / 1.0426 | 41.8 / 41.6 / 41.5 |
| 1.5 | 1.5696 / 1.5412 / 1.5370 | 61.5 / 59.0 / 62.0 |
| 2.0 | 2.0578 / 2.0559 / 2.0272 | 82.0 / 80.5 / 81.0 |
| 2.5 | 2.5197 / 2.5483 / 2.5483 | 96.5 / 97.2 / 95.8 |

## Hasil regresi (x, y dalam cm)

```
y = 1,444 + 0,3808 x        (y = real, x = odom)
r   = 0,9986     R² = 0,9973
MAE  = 1,1584 cm
MSE  = 1,9653 cm²
RMSE = 1,4019 cm
galat relatif rata-rata = 1,92 %
```

## Kesimpulan & penerapan
- Odometri **over-read 2,626×** terhadap jarak nyata; bersifat **sistematis-linier**
  (R²≈1) → dapat dikoreksi satu faktor skala.
- **Faktor koreksi = 1/2,626 = 0,3808.** Diterapkan sebagai default param
  `dist_scale = 0.3808` di [`odometry_publisher.py`](../src/amr_controller/scripts/odometry_publisher.py).
- Live tuning: `ros2 param set /odometry_publisher dist_scale 0.3808`
- Sumber penyimpangan kemungkinan kalibrasi `dist_per_tick` (jari-jari roda
  efektif / PPR) + slip. Saran lanjut: koreksi `pulses_per_revolution` atau
  `wheel_radius`, tambah IMU untuk jarak pendek.

> Lampiran perhitungan: `Perhitungan ODOMETRI vs REALTIME.xlsx` (di luar repo).
