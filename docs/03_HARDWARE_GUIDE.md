# 03 — Hardware Guide

> _SKELETON — lengkapi di Day 20 sesuai PROGRESS.md._
> Berisi detail wiring, BoM, pinout STM32, dan safety procedures.

---

## 1. Bill of Materials (BoM)

| No | Item | Spek | Qty | Estimasi Harga | Sumber |
|---|---|---|---|---|---|
| 1 | Intel NUC 13 i7 | Raptor Lake i7-1360P | 1 | _____ | _____ |
| 2 | STM32F407VGT6 board | Discovery atau equivalent | 1 | _____ | _____ |
| 3 | Motor PG45 | 24V 60W gearbox 1:34 + encoder 11 PPR | 1 | _____ | _____ |
| 4 | Servo DS3225 | 25 kg.cm metal gear | 1 | _____ | _____ |
| 5 | Driver BTS7960 | 43A half-bridge | 1 | _____ | _____ |
| 6 | RPLIDAR C1 | Slamtec | 1 | _____ | _____ |
| 7 | RealSense D455 | Intel | 1 | _____ | _____ |
| 8 | Joystick GX300 | Rexus wireless | 1 | _____ | _____ |
| 9 | Baterai LiPo 6S | Ovonic 5300 mAh 22.2V | 1 | _____ | _____ |
| 10 | Buck converter | 24V → 19V/12V/6V/5V | 1 set | _____ | _____ |
| 11 | Tombol Emergency | Mushroom NC contact | 1 | _____ | _____ |
| 12 | Chassis 4WD | Custom + diff + shaft | 1 set | _____ | _____ |

> _TODO: lengkapi harga & vendor di Day 20._

---

## 2. Wiring Diagram

> _TODO: insert foto wiring fisik dari Image 1 dengan label._

![Wiring Diagram](images/wiring_diagram.jpg)

### Power flow
```
LiPo 6S 22.2V
    └──> Tombol Emergency (NC)
            └──> Modul Power Management
                    ├──> 24V direct → BTS7960 → Motor PG45
                    └──> Buck Converter
                            ├──> 19V → NUC
                            ├──> 6V  → Servo DS3225
                            └──> 5V  → STM32 + sensor logic
```

### Signal flow
```
Joystick GX300 ───[USB Wireless]───> NUC ───[USB CDC]───> STM32
                                       │
                                       ├──[USB Serial]─── RPLIDAR C1
                                       └──[USB 3.0]────── RealSense D455

STM32 ───[PWM TIM3]───> BTS7960 ───> Motor PG45
STM32 ───[PWM TIM12]──> Servo DS3225
STM32 ───[TIM2 Encoder]<── Encoder PG45
```

---

## 3. Pinout STM32F407

> _TODO: lengkapi tabel sesuai firmware aktual._

| Pin | Fungsi | Alt Function | Keterangan |
|---|---|---|---|
| PA0 | TIM2_CH1 | Encoder A | Quadrature decoding |
| PA1 | TIM2_CH2 | Encoder B | Quadrature decoding |
| PA6 | TIM3_CH1 | RPWM motor | Motor PWM forward |
| PA7 | TIM3_CH2 | LPWM motor | Motor PWM reverse |
| PB0 | GPIO output | R_EN BTS7960 | Enable kanan |
| PB1 | GPIO output | L_EN BTS7960 | Enable kiri |
| PB14 | TIM12_CH1 | Servo PWM | 1000-2000 µs pulse |
| ... | ... | ... | ... |

---

## 4. Safety Procedures

### 4.1 Charging Baterai LiPo
- **JANGAN** charge tanpa pengawasan
- Pakai charger LiPo balanced (5A max)
- Jangan over-discharge (<20.0V untuk 6S)
- Simpan di storage voltage 22.2V kalau lama tidak dipakai

### 4.2 First Power-On
1. Pastikan E-stop ditekan (open)
2. Konek baterai
3. Lepas E-stop
4. Tekan power button NUC
5. Tunggu boot OK
6. Test joystick + R1 deadman → motor harus respon

### 4.3 Maintenance Berkala
- [ ] Cek kekencangan baut tiap minggu
- [ ] Bersihkan encoder magnet/gear dari debu
- [ ] Cek visual kabel (jangan ada terkelupas)
- [ ] Re-kalibrasi UMBmark setiap kali ban diganti

---

## 5. Power Budget

| Komponen | Konsumsi | Catatan |
|---|---|---|
| NUC 13 i7 | 25-40 W | Idle 15W, full load 65W |
| Motor PG45 | 30-60 W | Tergantung load |
| Servo DS3225 | 5 W avg | Peak 15W saat steering |
| RealSense D455 | 4 W | Saat depth+RGB stream |
| RPLIDAR C1 | 2.5 W | Konstan |
| STM32 | 0.5 W | Negligible |
| **Total avg** | **~80 W** | **Idle: ~50 W** |

**Autonomy estimation:**
LiPo 6S 5300 mAh = 22.2V × 5.3 Ah = **117.7 Wh**
Discharge ke 20% (safety margin) = 94 Wh usable.
Pada 80W avg: **~70 menit operasi.**
