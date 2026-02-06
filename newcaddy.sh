#!/bin/bash


# Ensure the script is running as root

if [ "$(id -u)" -ne 0 ]; then

  echo "This script must be run as root."

  exit 1

fi


# Update and upgrade packages

echo "Updating and upgrading the system..."

apt update && apt upgrade -y


# Install essential dependencies

echo "Installing dependencies..."

apt install -y \

  curl \

  unzip \

  software-properties-common \

  gnupg2 \

  lsb-release \

  sudo \

  ca-certificates \

  apt-transport-https \

  dialog \

  ufw


# Install the latest PHP (from Ondřej Surý's PPA)

echo "Adding PHP repository and installing the latest PHP..."

add-apt-repository ppa:ondrej/php -y

apt update


# Install the latest PHP version (it will grab the latest available version from the repository)

apt install -y \

  php-fpm \

  php-mysql \

  php-cli \

  php-curl \

  php-xml \

  php-mbstring \

  php-zip \

  php-gd \

  php-opcache


# Check the installed PHP version

PHP_VERSION=$(php -v | head -n 1 | awk '{print $2}')

echo "Installed PHP version: $PHP_VERSION"


# Check if the installed PHP version is the latest and restart PHP-FPM service if necessary

INSTALLED_PHP_VERSION=$(php -v | head -n 1 | awk '{print $2}')

LATEST_PHP_VERSION=$(apt-cache show php | grep 'Version:' | head -n 1 | cut -d' ' -f2)


if [[ "$INSTALLED_PHP_VERSION" != "$LATEST_PHP_VERSION" ]]; then

  echo "Installed PHP version ($INSTALLED_PHP_VERSION) is not the latest ($LATEST_PHP_VERSION). Restarting PHP-FPM service."

  systemctl restart php$PHP_VERSION-fpm

else

  echo "PHP is up-to-date."

fi


# Install Caddy

echo "Installing Caddy..."

curl -fsSL https://dl.cloudsmith.io/public/caddy/stable/ubuntu/gpg.key | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/caddy-archive-keyring.gpg

echo "deb [signed-by=/etc/apt/trusted.gpg.d/caddy-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/ubuntu/deb/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/caddy-stable.list

apt update

apt install -y caddy


# Enable and start Caddy

systemctl enable caddy

systemctl start caddy


# Install MySQL (MariaDB)

echo "Installing MySQL/MariaDB..."

apt install -y mariadb-server mariadb-client


# Secure MariaDB installation

echo "Securing MariaDB..."

mysql_secure_installation


# Download and configure WordPress

echo "Downloading WordPress..."

cd /var/www

curl -O https://wordpress.org/latest.tar.gz

tar -xvzf latest.tar.gz

rm latest.tar.gz


# Configure permissions for WordPress

echo "Setting proper permissions for WordPress..."

chown -R www-data:www-data /var/www/wordpress

chmod -R 755 /var/www/wordpress


# Request for future domain and email (for SSL and reverse proxy)

# This will only be uncommented and used after domain is configured.

# You will set your domain and email for SSL once you are ready to use SSL.


# Uncomment the lines below when you have a domain set up and are ready to configure SSL.

#

# echo "For future domain and SSL setup, please provide your domain and email:"

# read -p "Enter your domain (e.g., example.com): " DOMAIN

# read -p "Enter your email address for SSL (e.g., youremail@example.com): " EMAIL


# Set up a temporary Caddyfile for testing

# This will be used for testing with just HTTP on port 80.

# Later, we will modify it for your domain and enable SSL.

echo "Setting up Caddy configuration..."

cat > /etc/caddy/Caddyfile <<EOL

# Temporary Caddyfile for testing without domain

# Remove this section and uncomment the reverse proxy section when you have a domain.


# Caddy will serve WordPress over HTTP (port 80) for now

:80 {

    root * /var/www/wordpress

    php_fastcgi unix//run/php/php$PHP_VERSION-fpm.sock

    file_server

    encode gzip


    log {

        output file /var/log/caddy/access.log

    }

}


# Uncomment the following section and modify it once you have a domain

#

# For future domain and reverse proxy setup:

# Uncomment and replace the placeholders when you have your domain and email for SSL.

#

# $DOMAIN {

#     root * /var/www/wordpress

#     php_fastcgi unix//run/php/php$PHP_VERSION-fpm.sock

#     file_server

#     encode gzip

#     

#     tls $EMAIL

#

#     reverse_proxy /wp-admin 127.0.0.1:80

#

#     log {

#         output file /var/log/caddy/access.log

#     }

# }

EOL


# Restart Caddy to apply the configuration

systemctl restart caddy


# Set up firewall rules

echo "Configuring firewall..."


# Allow OpenSSH (for SSH access) and HTTP (for web traffic)

ufw allow OpenSSH

ufw allow 80/tcp


# Enable UFW firewall if it's not enabled yet

ufw --force enable


# Show firewall status to confirm the changes

ufw status


# Finalizing WordPress setup

echo "WordPress is now installed. Please complete the setup by visiting your server's IP address!"

echo "You can access the WordPress site at http://<your-server-ip>/"

echo "Once you have a domain, replace the Caddyfile and run 'systemctl restart caddy' to enable SSL and reverse proxy."

