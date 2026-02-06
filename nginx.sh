#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

### CHANGE THESE ###
DOMAIN="example.com"
DB_NAME="wordpress"
DB_USER="wpuser"
DB_PASS="StrongPassword123"
WEBROOT="/var/www/wordpress"
###################

echo "=============================================="
echo " Installing Nginx + WordPress on Ubuntu"
echo "=============================================="

echo "[1/9] Updating system..."
apt update -y

echo "[2/9] Installing Nginx..."
apt install -y nginx
systemctl enable nginx
systemctl start nginx

echo "[3/9] Installing PHP 8.3..."
apt install -y \
  php8.3-fpm php8.3-mysql php8.3-curl php8.3-gd \
  php8.3-mbstring php8.3-xml php8.3-zip php8.3-intl

systemctl enable php8.3-fpm
systemctl start php8.3-fpm

echo "[4/9] Installing MySQL..."
apt install -y mysql-server
systemctl enable mysql
systemctl start mysql

echo "[5/9] Creating database..."
mysql <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME} DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

echo "[6/9] Installing WordPress..."
mkdir -p ${WEBROOT}
cd /tmp
curl -LO https://wordpress.org/latest.tar.gz
tar xzf latest.tar.gz
cp -r wordpress/* ${WEBROOT}

chown -R www-data:www-data ${WEBROOT}
chmod -R 755 ${WEBROOT}

cp ${WEBROOT}/wp-config-sample.php ${WEBROOT}/wp-config.php

sed -i "s/database_name_here/${DB_NAME}/" ${WEBROOT}/wp-config.php
sed -i "s/username_here/${DB_USER}/" ${WEBROOT}/wp-config.php
sed -i "s/password_here/${DB_PASS}/" ${WEBROOT}/wp-config.php

echo "[7/9] Configuring Nginx..."
cat > /etc/nginx/sites-available/wordpress <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    root ${WEBROOT};
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)\$ {
        expires max;
        log_not_found off;
    }
}
EOF

ln -sf /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

echo "[8/9] Testing & restarting Nginx..."
nginx -t
systemctl reload nginx

echo "[9/9] Firewall..."
ufw allow 'Nginx Full' || true

echo "=============================================="
echo " ✅ INSTALL COMPLETE"
echo "=============================================="
echo " Open: http://${DOMAIN}"
echo " Finish WordPress setup in browser"
