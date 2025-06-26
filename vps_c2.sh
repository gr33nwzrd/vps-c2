#!/bin/bash

set -e

echo "[*] Updating package list..."
sudo apt update

echo "[*] Installing socat..."
sudo apt install -y socat

echo "[*] Enabling IP forwarding (just in case)..."
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

echo "[*] Setting up systemd service to forward port 443 → 4444..."

sudo tee /etc/systemd/system/c2-proxy.service > /dev/null <<EOF
[Unit]
Description=C2 TCP Proxy (443 → 4444)
After=network.target

[Service]
ExecStart=/usr/bin/socat TCP-LISTEN:443,fork TCP:localhost:4444
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

echo "[*] Enabling and starting the service..."
sudo systemctl daemon-reload
sudo systemctl enable c2-proxy
sudo systemctl start c2-proxy

echo "[*] Verifying socat listener is up..."
sleep 2
sudo ss -tuln | grep ":443" || echo "[!] Warning: socat not listening on port 443"

echo "[*] (Optional) Adding UFW rule to allow port 443..."
if command -v ufw &> /dev/null; then
    sudo ufw allow 443/tcp || echo "[!] UFW may be inactive"
else
    echo "[!] Skipping UFW (not installed)"
fi

echo -e "\n✅ Done! This VPS is now acting as a C2 redirector."
echo "Any TCP connection to port 443 will be forwarded to localhost:4444"
echo "From your local machine, open a reverse tunnel using:"
echo "  ssh -N -R 4444:localhost:4444 <you>@<vps-ip>"
