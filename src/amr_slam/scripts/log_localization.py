#!/usr/bin/env python3
"""
log_localization.py
===================
Ambil data lokalisasi RTAB-Map secara real-time via terminal.
Subscribe ke:
  - /rtabmap/localization_pose  → posisi (x, y, yaw) di frame map
  - /info                       → loop_closure_id, covariance
  - /odom                       → wheel odometry (x, y, yaw)

Output: print terminal + simpan CSV ke ~/localization_log.csv

Usage:
  python3 log_localization.py              # print + simpan CSV
  python3 log_localization.py --no-csv     # print saja
  python3 log_localization.py --hz 2       # sample rate 2 Hz (default 1 Hz)
"""

import rclpy
from rclpy.node import Node
from geometry_msgs.msg import PoseWithCovarianceStamped
from nav_msgs.msg import Odometry
from rtabmap_msgs.msg import Info
import math
import time
import csv
import os
import argparse
import sys


def quat_to_yaw(q):
    siny = 2.0 * (q.w * q.z + q.x * q.y)
    cosy = 1.0 - 2.0 * (q.y * q.y + q.z * q.z)
    return math.atan2(siny, cosy)


class LocalizationLogger(Node):
    def __init__(self, save_csv=True, hz=1.0):
        super().__init__('localization_logger')

        self.save_csv = save_csv
        self.interval = 1.0 / hz
        self.last_print = 0.0

        # State
        self.loc_x    = None
        self.loc_y    = None
        self.loc_yaw  = None
        self.loc_cov  = None   # covariance[0] = xx
        self.lc_id    = 0
        self.odom_x   = None
        self.odom_y   = None
        self.odom_yaw = None
        self.count    = 0

        # CSV setup
        if self.save_csv:
            self.csv_path = os.path.expanduser('~/localization_log.csv')
            self.csv_file = open(self.csv_path, 'w', newline='')
            self.writer   = csv.writer(self.csv_file)
            self.writer.writerow([
                'timestamp_s', 'elapsed_s',
                'loc_x_m', 'loc_y_m', 'loc_yaw_deg',
                'loc_cov_xx', 'lock_status',
                'loop_closure_id',
                'odom_x_m', 'odom_y_m', 'odom_yaw_deg',
            ])
            self.get_logger().info(f'CSV disimpan ke: {self.csv_path}')

        self.t0 = time.time()

        # Subscriptions
        # CATATAN: topik RTAB-Map di setup ini TANPA prefix /rtabmap
        # (cek: ros2 topic list | grep pose). Jadi /localization_pose, /info.
        self.create_subscription(
            PoseWithCovarianceStamped,
            '/localization_pose',
            self.cb_loc, 10)

        self.create_subscription(
            Info, '/info', self.cb_info, 10)

        self.create_subscription(
            Odometry, '/odom', self.cb_odom, 10)

        # Print timer
        self.create_timer(self.interval, self.print_status)

        print('\033[2J\033[H', end='')   # clear screen
        print('=' * 60)
        print('  AMR LOCALIZATION LOGGER')
        print(f'  Sample rate : {hz} Hz')
        print(f'  CSV         : {"~/localization_log.csv" if save_csv else "OFF"}')
        print('  Ctrl+C untuk berhenti')
        print('=' * 60)

    def cb_loc(self, msg):
        p = msg.pose.pose
        self.loc_x   = p.position.x
        self.loc_y   = p.position.y
        self.loc_yaw = math.degrees(quat_to_yaw(p.orientation))
        self.loc_cov = msg.pose.covariance[0]

    def cb_info(self, msg):
        self.lc_id = msg.loop_closure_id

    def cb_odom(self, msg):
        p = msg.pose.pose
        self.odom_x   = p.position.x
        self.odom_y   = p.position.y
        self.odom_yaw = math.degrees(quat_to_yaw(p.orientation))

    def print_status(self):
        now     = time.time()
        elapsed = now - self.t0
        self.count += 1

        # Lock status
        if self.loc_cov is None:
            lock = '⏳ WAITING'
        elif self.loc_cov < 1.0:
            lock = '🟢 LOCK'
        elif self.loc_cov < 100.0:
            lock = '🟡 WEAK'
        else:
            lock = '🔴 LOST'

        # Terminal output
        print(f'\033[H', end='')   # cursor ke atas
        print(f'{"=" * 60}')
        print(f'  [#{self.count:04d}]  t={elapsed:7.1f}s   {time.strftime("%H:%M:%S")}')
        print(f'{"=" * 60}')
        print(f'  LOKALISASI (frame: map)')
        if self.loc_x is not None:
            print(f'    x   : {self.loc_x:+8.4f} m')
            print(f'    y   : {self.loc_y:+8.4f} m')
            print(f'    yaw : {self.loc_yaw:+8.2f} deg')
            print(f'    cov : {self.loc_cov:.2e}')
        else:
            print('    (belum ada data /rtabmap/localization_pose)')
            print(); print(); print()

        print(f'  STATUS    : {lock}')
        print(f'  Loop ID   : {self.lc_id}')
        print()
        print(f'  ODOM (frame: odom / wheel)')
        if self.odom_x is not None:
            print(f'    x   : {self.odom_x:+8.4f} m')
            print(f'    y   : {self.odom_y:+8.4f} m')
            print(f'    yaw : {self.odom_yaw:+8.2f} deg')
        else:
            print('    (belum ada data /odom)')
            print(); print()
        print(f'{"=" * 60}')

        # CSV write
        if self.save_csv:
            self.writer.writerow([
                f'{now:.3f}',
                f'{elapsed:.2f}',
                f'{self.loc_x:.4f}' if self.loc_x is not None else '',
                f'{self.loc_y:.4f}' if self.loc_y is not None else '',
                f'{self.loc_yaw:.2f}' if self.loc_yaw is not None else '',
                f'{self.loc_cov:.2e}' if self.loc_cov is not None else '',
                lock.replace('\U0001f7e2','').replace('\U0001f7e1','').replace('\U0001f534','').strip(),
                self.lc_id,
                f'{self.odom_x:.4f}' if self.odom_x is not None else '',
                f'{self.odom_y:.4f}' if self.odom_y is not None else '',
                f'{self.odom_yaw:.2f}' if self.odom_yaw is not None else '',
            ])
            self.csv_file.flush()

    def destroy_node(self):
        if self.save_csv:
            self.csv_file.close()
            print(f'\nCSV disimpan: {self.csv_path}  ({self.count} baris)')
        super().destroy_node()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--no-csv', action='store_true', help='Jangan simpan CSV')
    parser.add_argument('--hz', type=float, default=1.0, help='Sample rate Hz (default 1)')
    args = parser.parse_args()

    rclpy.init()
    node = LocalizationLogger(save_csv=not args.no_csv, hz=args.hz)
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
