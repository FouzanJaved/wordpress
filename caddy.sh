#!/bin/bash

# ========= CONFIG (EDIT THESE) =========
DB_NAME="wordpress"
DB_USER="wpuser"
DB_PASS="strongpassword"
WP_DIR="/var/www/wordpress"
SERVER_NAME=":80"   # use domain.com later for HTTPS
# ======================================

echo "Updating system..."
sudo apt update && sudo apt upgrade -y

echo "Installing MySQL..."
sudo apt install mysql-server -y

echo "Securing MySQL..."
sudo mysql -e "DELETE FROM mysql.user WHERE User='';"
sudo mysql -e "DROP DATABASE IF EXISTS test;"
sudo mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
sudo mysql -e "FLUSH PRIVILEGES;"

echo "Creating WordPress database..."
sudo mysql -e "CREATE DATABASE ${DB_NAME};"
sudo mysql -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
sudo mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

echo "Installing PHP and extensions..."
sudo apt install php-fpm php-mysql php-curl php-gd php-mbstring php-xml php-zip php-cli unzip -y

echo "Installing Caddy..."
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo tee /usr/share/keyrings/caddy-stable-archive-keyring.gpg > /dev/null
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy -y

echo "Downloading WordPress..."
sudo mkdir -p ${WP_DIR}
cd /tmp || exit
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
sudo mv wordpress/* ${WP_DIR}
sudo rm -rf wordpress latest.tar.gz

echo "Setting permissions..."
sudo chown -R www-data:www-data ${WP_DIR}
sudo find ${WP_DIR} -type d -exec chmod 755 {} \;
sudo find ${WP_DIR} -type f -exec chmod 644 {} \;

echo "Configuring Caddy..."
sudo tee /etc/caddy/Caddyfile > /dev/null <<EOF
${SERVER_NAME} {
    root * ${WP_DIR}
    php_fastcgi unix//run/php/php8.1-fpm.sock
    file_server
}
EOF

echo "Restarting services..."
sudo systemctl restart php8.1-fpm
sudo systemctl restart caddy

echo "Allowing firewall..."
sudo ufw allow 80 || true
sudo ufw allow 443 || true

echo "======================================"
echo " WordPress installed with Caddy!"
echo " Open your browser:"
echo " http://YOUR_SERVER_IP"
echo "======================================"
