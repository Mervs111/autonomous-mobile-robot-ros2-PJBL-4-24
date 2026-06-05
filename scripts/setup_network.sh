#!/bin/bash
# =====================================================================
# AMR Network Setup - Fix WiFi/Bluetooth auto-reconnect
# =====================================================================
# Memastikan NUC otomatis reconnect ke WiFi & Bluetooth setelah reboot
# tanpa intervensi manual. Penting untuk demo dosen.
#
# Usage:
#   sudo bash scripts/setup_network.sh "WiFi-Kampus-ITS"
# =====================================================================

set -e

PROFILE="${1:-WiFi-Kampus-ITS}"

if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] Jalankan dengan sudo: sudo bash $0 \"$PROFILE\""
    exit 1
fi

echo "=================================================="
echo "  AMR Network Auto-Reconnect Setup"
echo "  Profile: $PROFILE"
echo "=================================================="

# ---- 1. NetworkManager autoconnect ----
echo ""
echo "[1/5] Setting NetworkManager autoconnect..."
if nmcli connection show "$PROFILE" &>/dev/null; then
    nmcli connection modify "$PROFILE" \
        connection.autoconnect yes \
        connection.autoconnect-priority 10 \
        connection.autoconnect-retries 0 \
        802-1x.password-flags 0 || true
    echo "[OK] Profile $PROFILE configured."
else
    echo "[WARN] Profile $PROFILE belum ada. Connect manual dulu via GUI/nmcli, lalu jalankan ulang script ini."
fi

# ---- 2. Disable WiFi power saving ----
echo ""
echo "[2/5] Disabling WiFi power saving..."
cat > /etc/NetworkManager/conf.d/wifi-powersave-off.conf <<'EOF'
[connection]
wifi.powersave = 2
EOF
systemctl restart NetworkManager
echo "[OK] WiFi power saving disabled."

# ---- 3. Enable wait-online ----
echo ""
echo "[3/5] Enabling NetworkManager-wait-online..."
systemctl unmask NetworkManager-wait-online.service || true
systemctl enable NetworkManager-wait-online.service || true
echo "[OK]."

# ---- 4. Bluetooth auto-enable ----
echo ""
echo "[4/5] Configuring Bluetooth auto-enable..."
if ! grep -q '^AutoEnable=true' /etc/bluetooth/main.conf; then
    cat >> /etc/bluetooth/main.conf <<'EOF'

[Policy]
AutoEnable=true
ReconnectAttempts=7
ReconnectIntervals=1,2,4,8,16,32,64
EOF
fi
systemctl enable bluetooth.service
systemctl restart bluetooth.service
echo "[OK] Bluetooth auto-enable configured."

# ---- 5. WiFi watchdog systemd service ----
echo ""
echo "[5/5] Installing WiFi watchdog..."

cat > /usr/local/bin/amr-wifi-watchdog.sh <<EOF
#!/bin/bash
# AMR WiFi watchdog - reconnect kalau ping gagal
GATEWAY=\$(ip route | awk '/default/ {print \$3; exit}')
PROFILE="$PROFILE"
INTERVAL=15
FAIL_THRESHOLD=2
fail=0
while true; do
    if ping -c 1 -W 2 "\${GATEWAY:-8.8.8.8}" > /dev/null 2>&1; then
        fail=0
    else
        fail=\$((fail + 1))
        echo "\$(date -Iseconds) ping fail #\$fail to \$GATEWAY"
        if [ "\$fail" -ge "\$FAIL_THRESHOLD" ]; then
            echo "\$(date -Iseconds) reconnecting \$PROFILE"
            nmcli connection down  "\$PROFILE" || true
            sleep 2
            nmcli connection up    "\$PROFILE" || true
            fail=0
        fi
    fi
    sleep "\$INTERVAL"
done
EOF
chmod +x /usr/local/bin/amr-wifi-watchdog.sh

cat > /etc/systemd/system/amr-wifi-watchdog.service <<'EOF'
[Unit]
Description=AMR WiFi Connectivity Watchdog
After=NetworkManager.service

[Service]
Type=simple
ExecStart=/usr/local/bin/amr-wifi-watchdog.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now amr-wifi-watchdog.service
echo "[OK] Watchdog service installed."

echo ""
echo "=================================================="
echo "  DONE. Reboot NUC sekarang untuk verify."
echo "=================================================="
