#!/usr/bin/env python3
"""
calibrate_wheel.py
===================
Kalibrasi diameter roda dengan metode lintasan lurus 5 meter.

Procedure:
    1. Tempel meteran lurus di lantai sepanjang 5 meter.
    2. Posisikan robot dengan as roda belakang pas di garis 0 m.
    3. Jalankan script ini -> akan reset counter dan mulai recording.
    4. Drive robot lurus 5 m manual via joystick.
    5. Tekan Ctrl+C saat robot mencapai 5 m.
    6. Script akan print:
        - Total ticks
        - Distance assumed (dari parameter)
        - Diameter aktual yang dihitung balik

Usage:
    ros2 run amr_controller calibrate_wheel.py        # default 5 m, PPR 1496
    # atau dengan parameter custom:
    python3 calibrate_wheel.py --distance 5.0 --ppr 1496

Rumus:
    diameter_actual = (distance_traveled * PPR) / (pi * total_ticks)
"""
import argparse
import math
import sys

import rclpy
from rclpy.node import Node
from std_msgs.msg import Int32


class WheelCalibrator(Node):
    def __init__(self, distance_m: float, ppr: int):
        super().__init__('wheel_calibrator')
        self.distance_m = distance_m
        self.ppr = ppr
        self.total_ticks = 0
        self.last_value = None
        self.encoder_mode = None
        self.first_samples = []

        self.create_subscription(Int32, '/encoder', self.cb, 50)

        self.get_logger().info(
            f'Calibration started. Drive robot LURUS {distance_m} m '
            f'lalu Ctrl+C.'
        )
        self.get_logger().info(
            f'Subscribing to /encoder. Detecting encoder mode...'
        )

    def cb(self, msg: Int32):
        # Auto-detect cumulative vs delta dari 20 sampel pertama
        if self.encoder_mode is None:
            self.first_samples.append(msg.data)
            if len(self.first_samples) >= 20:
                avg_abs = sum(abs(s) for s in self.first_samples) / 20
                # Cek monotonic (kumulatif)
                diffs = [self.first_samples[i+1] - self.first_samples[i]
                         for i in range(19)]
                n_inc = sum(1 for d in diffs if d > 0)
                if n_inc > 14 and avg_abs > 500:
                    self.encoder_mode = 'cumulative'
                    self.last_value = self.first_samples[-1]
                else:
                    self.encoder_mode = 'delta'
                    self.total_ticks = sum(self.first_samples)
                self.get_logger().info(f'Mode detected: {self.encoder_mode}')
            return

        if self.encoder_mode == 'cumulative':
            d = msg.data - self.last_value
            self.last_value = msg.data
            self.total_ticks += d
        else:
            self.total_ticks += msg.data

    def report(self):
        if self.total_ticks == 0:
            self.get_logger().error('No encoder ticks recorded!')
            return
        # Asumsi gear ratio sudah included di PPR (1496 = 11*4*34)
        ticks_per_rev = self.ppr
        diameter_m = (self.distance_m * ticks_per_rev) / (math.pi * abs(self.total_ticks))
        radius_m = diameter_m / 2.0

        print('\n' + '=' * 50)
        print('  WHEEL CALIBRATION REPORT')
        print('=' * 50)
        print(f'  Distance traveled : {self.distance_m:.3f} m')
        print(f'  PPR (per rev roda): {ticks_per_rev}')
        print(f'  Total ticks       : {self.total_ticks}')
        print(f'  Diameter actual   : {diameter_m*1000:.2f} mm')
        print(f'  Radius actual     : {radius_m*1000:.2f} mm')
        print('-' * 50)
        print(f'  Untuk URDF / odometry, set:')
        print(f'      wheel_radius = {radius_m:.4f}  # meter')
        print('=' * 50)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--distance', type=float, default=5.0,
                        help='Jarak lurus tempuh dalam meter (default 5.0)')
    parser.add_argument('--ppr', type=int, default=1496,
                        help='Pulses per revolution roda (default 1496 = 11*4*34)')
    args, unknown = parser.parse_known_args()

    rclpy.init(args=unknown)
    node = WheelCalibrator(args.distance, args.ppr)
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        node.report()
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
