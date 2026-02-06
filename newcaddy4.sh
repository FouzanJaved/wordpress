#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

DOMAIN="example.com"
EMAIL="admin@example.com"
WEBROOT="/var/www/wordpress"

echo "=============================================="
echo " HARD RESET WEB STACK + CADDY + WORDPRESS"
echo "=============================================="

echo "[1/10] Stopping services..."
sudo systemctl stop apache2 nginx mysql php*-fpm caddy || true

echo "[2/10] Removing Apache / Nginx / PHP / MySQL..."
sudo apt purge -y apache2* nginx* php* mysql* mariadb* || true
sudo apt autoremove -y
sudo apt autoclean -y

echo "[3/10] Cleaning web root..."
sudo rm -rf /var/www/*
sudo mkdir -p $WEBROOT

echo "[4/10] Installing base packages..."
sudo apt update
sudo apt install -y curl unzip ufw debian-keyring debian-archive-keyring apt-transport-https

echo "[5/10] Installing Caddy (Jammy repo for Noble)..."
curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/gpg.key \
| sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] \
https://dl.cloudsmith.io/public/caddy/stable/deb/ubuntu jammy main" \
| sudo tee /etc/apt/sources.list.d/caddy-stable.list

sudo apt update
sudo apt install -y caddy

echo "[6/10] Installing PHP 8.3..."
sudo apt install -y php8.3-fpm php8.3-mysql php8.3-curl php8.3-gd php8.3-xml php8.3-mbstring php8.3-zip php8.3-intl

sudo systemctl enable php8.3-fpm
sudo systemctl start php8.3-fpm

echo "[7/10] Installing MySQL..."
sudo apt install -y mysql-server
sudo systemctl enable mysql
sudo systemctl start mysql

echo "[8/10] Installing WordPress..."
cd /tmp
curl -O https://wordpress.org/latest.zip
unzip latest.zip
sudo mv wordpress/* $WEBROOT

sudo chown -R www-data:www-data $WEBROOT
sudo chmod -R 755 $WEBROOT

echo "[9/10] Creating Caddyfile..."
sudo tee /etc/caddy/Caddyfile > /dev/null <<EOF
$DOMAIN {
    root * $WEBROOT
    php_fastcgi unix//run/php/php8.3-fpm.sock
    file_server
    encode gzip
    tls $EMAIL
}
EOF

echo "[10/10] Firewall & restart..."
sudo ufw allow 80
sudo ufw allow 443
sudo ufw --force enable

sudo systemctl restart caddy

echo "=============================================="
echo " ✅ INSTALL COMPLETE"
echo "=============================================="
echo " Visit: http://$DOMAIN"
echo " HTTPS will activate automatically"
