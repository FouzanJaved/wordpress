#!/bin/bash

# ====== CONFIG (CHANGE THESE) ======
DB_NAME="wordpress"
DB_USER="wpuser"
DB_PASS="strongpassword"
WP_DIR="/var/www/html/wordpress"
SERVER_NAME="localhost"
# ==================================

echo "Updating system..."
sudo apt update && sudo apt upgrade -y

echo "Installing Apache..."
sudo apt install apache2 -y

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
sudo apt install php php-mysql php-curl php-gd php-mbstring php-xml php-zip php-cli -y

echo "Restarting Apache..."
sudo systemctl restart apache2

echo "Downloading WordPress..."
cd /var/www/html || exit
sudo wget https://wordpress.org/latest.tar.gz
sudo tar -xzf latest.tar.gz
sudo rm latest.tar.gz

echo "Setting permissions..."
sudo chown -R www-data:www-data ${WP_DIR}
sudo chmod -R 755 ${WP_DIR}

echo "Creating Apache Virtual Host..."
sudo tee /etc/apache2/sites-available/wordpress.conf > /dev/null <<EOF
<VirtualHost *:80>
    ServerName ${SERVER_NAME}
    DocumentRoot ${WP_DIR}

    <Directory ${WP_DIR}>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/wp_error.log
    CustomLog \${APACHE_LOG_DIR}/wp_access.log combined
</VirtualHost>
EOF

echo "Enabling site and rewrite module..."
sudo a2ensite wordpress.conf
sudo a2enmod rewrite
sudo systemctl reload apache2

echo "Allowing firewall rules..."
sudo ufw allow 'Apache Full' || true

echo "======================================"
echo " WordPress files installed successfully"
echo " Open your browser and visit:"
echo " http://YOUR_SERVER_IP/wordpress"
echo "======================================"
