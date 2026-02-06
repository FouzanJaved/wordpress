#!/bin/bash
set -e

echo "==========================================="
echo "   Installing & Testing Caddy on Ubuntu"
echo "==========================================="

# Update system
echo "[1/6] Updating system..."
sudo apt update -y

# Install dependencies
echo "[2/6] Installing dependencies..."
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl ufw

# Add Caddy GPG key
echo "[3/6] Adding Caddy GPG key..."
curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/gpg.key \
  | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg

# Add Caddy repo
echo "[4/6] Adding Caddy repository..."
curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt \
  | sudo tee /etc/apt/sources.list.d/caddy-stable.list

# Install Caddy
echo "[5/6] Installing Caddy..."
sudo apt update -y
sudo apt install -y caddy

# Enable & start service
sudo systemctl enable caddy
sudo systemctl restart caddy

# Allow firewall if enabled
if sudo ufw status | grep -q "Status: active"; then
  echo "UFW detected — allowing HTTP/HTTPS..."
  sudo ufw allow 80
  sudo ufw allow 443
fi

# Test Caddy locally
echo "[6/6] Testing Caddy..."
sleep 2

HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost)

echo ""
echo "================ TEST RESULT ================"
if [ "$HTTP_RESPONSE" = "200" ]; then
  echo "✅ Caddy is running successfully!"
  echo "🌍 Visit: http://SERVER_IP"
else
  echo "❌ Caddy test failed"
  echo "HTTP status code: $HTTP_RESPONSE"
  echo "Check logs using:"
  echo "  sudo journalctl -u caddy --no-pager"
fi
echo "============================================"
