#!/usr/bin/env bash
# reset_odom.sh — reset VIO odom ke (0,0,0).
# Pakai SEBELUM kirim goal Nav2, terutama kalau robot baru diangkat fisik.
#
# Akar masalah malam 20 Juni: robot diangkat balik ke start tapi odom-nya
# udah accumulate ke x=10. Goal "+0.5m base_link" jadi target x=10.5 di odom
# -> robot lari 7m+ supaya nyampe target imaginer itu.
#
# Output:
#   - OK    -> service /reset_odom merespons
#   - FAIL  -> service belum ada (T2 belum hidup) atau ada error
set -e
echo "[reset_odom] memanggil /reset_odom..."
ros2 service call /reset_odom std_srvs/srv/Empty
sleep 0.3
echo
echo "[reset_odom] verifikasi pose:"
ros2 topic echo /odom --field pose.pose.position --once
