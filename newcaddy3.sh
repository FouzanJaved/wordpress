#!/bin/bash

# Minimal WordPress Installer with Logo - Template v1.3

# For Ubuntu Minimal with basic GUI configuration

# Uses WordPress web interface for database setup


set -e


# Installation directory

INSTALL_DIR="/opt/wordpress-installer"

CONFIG_FILE="$INSTALL_DIR/config.cfg"

LOG_FILE="/var/log/wp-install.log"

LOGO_FILE="$INSTALL_DIR/logo.txt"

LOGO_URL="https://erp.sahmcore.com.sa/web/image/website/1/logo/My%20Website?unique=8043c74"


# Create installation directory

mkdir -p "$INSTALL_DIR"


# Logging function

log() {

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"

}


# Function to ensure all required packages are installed

ensure_prerequisites() {

    log "Ensuring all required packages are installed..."

    

    # Update package list

    apt-get update || {

        echo "Failed to update package list" >&2

        return 1

    }

    

    # Install absolutely essential packages first

    apt-get install -y --no-install-recommends \

        curl \

        wget \

        dialog \

        lsb-release \

        ca-certificates \

        apt-transport-https \

        software-properties-common \

        gnupg || {

        echo "Failed to install essential packages" >&2

        return 1

    }

    

    # Now install dialog for GUI (already installed above, but just in case)

    if ! command -v dialog &> /dev/null; then

        apt-get install -y dialog || {

            echo "Failed to install dialog" >&2

            return 1

        }

    fi

    

    log "Prerequisites installed successfully"

}


# Download and display logo

setup_logo() {

    log "Setting up logo..."

    

    # Ensure curl is available

    if ! command -v curl &> /dev/null; then

        apt-get install -y curl > /dev/null 2>&1

    fi

    

    # Try to download logo

    if curl -s "$LOGO_URL" --max-time 10 -o "$LOGO_FILE.tmp" 2>/dev/null; then

        # Check if downloaded file has content

        if [ -s "$LOGO_FILE.tmp" ]; then

            mv "$LOGO_FILE.tmp" "$LOGO_FILE"

            log "Logo downloaded successfully"

        else

            create_ascii_logo

            rm -f "$LOGO_FILE.tmp"

        fi

    else

        create_ascii_logo

    fi

    

    # Ensure logo file exists

    if [ ! -f "$LOGO_FILE" ]; then

        create_ascii_logo

    fi

}


# Create ASCII logo fallback

create_ascii_logo() {

    cat > "$LOGO_FILE" << 'EOF'

╔══════════════════════════════════════╗

║      WordPress Minimal Installer     ║

╚══════════════════════════════════════╝

EOF

}


# Display logo in dialog

show_logo() {

    if [ -f "$LOGO_FILE" ] && [ -s "$LOGO_FILE" ]; then

        # Simple display without complex calculations

        dialog --backtitle "WordPress Minimal Installer" \

               --title "" \

               --textbox "$LOGO_FILE" 8 50 \

               2>&1 >/dev/tty || true

    fi

}


# Check if running as root

if [ "$(id -u)" -ne 0 ]; then

    echo "This script must be run as root."

    exit 1

fi


# Function to display welcome screen

show_welcome() {

    # Setup logo first

    setup_logo

    

    show_logo

    

    dialog --backtitle "WordPress Minimal Installer" \

           --title "Welcome" \

           --yesno "\

This script will install WordPress with minimal dependencies.


It includes:

✓ Latest PHP (auto-detected)

✓ Caddy web server

✓ WordPress latest version


The database setup will be done through WordPress

web interface after installation.


Continue with installation?" 14 50

    

    return $?

}


# Function to display configuration GUI

show_config_gui() {

    # Load existing config if available

    if [ -f "$CONFIG_FILE" ]; then

        # Safely source config file

        DOMAIN="localhost"

        EMAIL="admin@localhost"

        WP_TITLE="My WordPress Site"

        WP_ADMIN_USER="admin"

        

        # Try to load existing values

        if grep -q "DOMAIN=" "$CONFIG_FILE" 2>/dev/null; then

            DOMAIN=$(grep "DOMAIN=" "$CONFIG_FILE" | cut -d'"' -f2)

        fi

        if grep -q "EMAIL=" "$CONFIG_FILE" 2>/dev/null; then

            EMAIL=$(grep "EMAIL=" "$CONFIG_FILE" | cut -d'"' -f2)

        fi

        if grep -q "WP_TITLE=" "$CONFIG_FILE" 2>/dev/null; then

            WP_TITLE=$(grep "WP_TITLE=" "$CONFIG_FILE" | cut -d'"' -f2)

        fi

        if grep -q "WP_ADMIN_USER=" "$CONFIG_FILE" 2>/dev/null; then

            WP_ADMIN_USER=$(grep "WP_ADMIN_USER=" "$CONFIG_FILE" | cut -d'"' -f2)

        fi

    else

        # Set defaults

        DOMAIN="localhost"

        EMAIL="admin@localhost"

        WP_TITLE="My WordPress Site"

        WP_ADMIN_USER="admin"

    fi

    

    # Create temp file for dialog responses

    TEMP_FILE=$(mktemp)

    

    # Domain configuration dialog

    dialog --backtitle "WordPress Minimal Installer" \

           --title "Configuration" \

           --form "Enter your WordPress details:\n\nLeave as localhost for testing" \

           14 55 4 \

           "Domain/Server IP:"     1 1 "$DOMAIN"       1 20 30 0 \

           "Admin Email:"          2 1 "$EMAIL"        2 20 30 0 \

           "Site Title:"           3 1 "$WP_TITLE"     3 20 30 0 \

           "Admin Username:"       4 1 "$WP_ADMIN_USER" 4 20 30 0 \

           2> "$TEMP_FILE"

    

    # Check if user cancelled

    if [ $? -ne 0 ]; then

        rm -f "$TEMP_FILE"

        log "Installation cancelled by user"

        exit 0

    fi

    

    # Read responses

    {

        read -r DOMAIN

        read -r EMAIL

        read -r WP_TITLE

        read -r WP_ADMIN_USER

    } < "$TEMP_FILE" || true

    

    # Set defaults if empty

    DOMAIN="${DOMAIN:-localhost}"

    EMAIL="${EMAIL:-admin@localhost}"

    WP_TITLE="${WP_TITLE:-My WordPress Site}"

    WP_ADMIN_USER="${WP_ADMIN_USER:-admin}"

    

    # Ask about SSL

    dialog --backtitle "WordPress Minimal Installer" \

           --title "SSL Configuration" \

           --menu "Configure SSL for production?\n\nSelect 'No' for localhost/testing:" \

           12 50 2 \

           "Yes" "Enable SSL (for real domains)" \

           "No" "HTTP only (for localhost/testing)" \

           2> "$TEMP_FILE"

    

    ssl_choice=$(cat "$TEMP_FILE" 2>/dev/null || echo "No")

    

    if [ "$ssl_choice" = "Yes" ] && [ "$DOMAIN" != "localhost" ]; then

        ENABLE_SSL="true"

    else

        ENABLE_SSL="false"

        # Force localhost if no SSL

        if [ "$DOMAIN" = "localhost" ]; then

            DOMAIN="localhost"

        fi

    fi

    

    # Save configuration

    cat > "$CONFIG_FILE" <<EOF

# WordPress Installation Configuration

DOMAIN="$DOMAIN"

EMAIL="$EMAIL"

ENABLE_SSL="$ENABLE_SSL"

WP_TITLE="$WP_TITLE"

WP_ADMIN_USER="$WP_ADMIN_USER"

INSTALL_DATE="$(date '+%Y-%m-%d %H:%M:%S')"

EOF

    

    # Show configuration summary

    show_logo

    

    dialog --backtitle "WordPress Minimal Installer" \

           --title "Configuration Summary" \

           --msgbox "\

Configuration Summary:


📍 Domain: $DOMAIN

🔒 SSL: $ENABLE_SSL

🏷️  Site Title: $WP_TITLE

👤 Admin User: $WP_ADMIN_USER

📧 Admin Email: $EMAIL


Database will be configured through

WordPress web interface after installation.


Press OK to begin installation." 16 50

    

    rm -f "$TEMP_FILE"

}


# Function to clean any existing installations

clean_existing() {

    log "Cleaning any existing installations..."

    

    # Stop services

    systemctl stop caddy 2>/dev/null || true

    systemctl stop php*-fpm 2>/dev/null || true

    systemctl stop apache2 nginx 2>/dev/null || true

    

    # Remove web files

    rm -rf /var/www/html/* 2>/dev/null || true

    

    log "Cleanup completed"

}


# Function to install PHP

install_php() {

    log "Installing PHP..."

    

    # Add PHP repository

    if ! grep -q "ondrej/php" /etc/apt/sources.list.d/* 2>/dev/null; then

        log "Adding PHP repository..."

        apt-get install -y software-properties-common

        add-apt-repository ppa:ondrej/php -y

        apt-get update

    fi

    

    # Detect and install latest PHP

    PHP_PKG=$(apt-cache search '^php[0-9]\.[0-9]-fpm$' | head -1 | awk '{print $1}')

    

    if [ -z "$PHP_PKG" ]; then

        PHP_PKG="php8.2-fpm"

    fi

    

    PHP_VERSION=$(echo "$PHP_PKG" | grep -o '[0-9]\.[0-9]')

    

    log "Installing PHP $PHP_VERSION..."

    

    apt-get install -y --no-install-recommends \

        "$PHP_PKG" \

        "php$PHP_VERSION-mysql" \

        "php$PHP_VERSION-curl" \

        "php$PHP_VERSION-xml" \

        "php$PHP_VERSION-mbstring" \

        "php$PHP_VERSION-zip" \

        "php$PHP_VERSION-gd" \

        "php$PHP_VERSION-opcache" || {

        log "PHP installation failed"

        return 1

    }

    

    # Get actual PHP version

    ACTUAL_VERSION=$(php -v 2>/dev/null | head -1 | awk '{print $2}' | cut -d. -f1,2)

    if [ -z "$ACTUAL_VERSION" ]; then

        ACTUAL_VERSION="$PHP_VERSION"

    fi

    

    # Configure PHP

    PHP_INI="/etc/php/$ACTUAL_VERSION/fpm/php.ini"

    if [ -f "$PHP_INI" ]; then

        sed -i 's/^max_execution_time = .*/max_execution_time = 300/' "$PHP_INI"

        sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 64M/' "$PHP_INI"

        sed -i 's/^post_max_size = .*/post_max_size = 64M/' "$PHP_INI"

    fi

    

    # Start PHP-FPM

    systemctl enable "php$ACTUAL_VERSION-fpm"

    systemctl start "php$ACTUAL_VERSION-fpm"

    

    log "PHP $ACTUAL_VERSION installed successfully"

    echo "$ACTUAL_VERSION"

}


# Function to install Caddy

install_caddy() {

    log "Installing Caddy..."

    

    # Install using official repository

    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg

    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list

    

    apt-get update

    apt-get install -y caddy

    

    # Ensure Caddy service is properly set up

    systemctl enable caddy

    systemctl start caddy

    

    log "Caddy installed successfully"

}


# Function to install MariaDB (just the server, no WordPress db setup)

install_mariadb() {

    log "Installing MariaDB server..."

    

    apt-get install -y mariadb-server

    

    # Minimal security setup

    mysql -e "DELETE FROM mysql.user WHERE User='';" 2>/dev/null || true

    mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" 2>/dev/null || true

    mysql -e "FLUSH PRIVILEGES;" 2>/dev/null || true

    

    # Ensure MariaDB is running

    systemctl enable mariadb

    systemctl start mariadb

    

    log "MariaDB installed (WordPress will create its own database)"

}


# Function to install WordPress files

install_wordpress() {

    log "Installing WordPress files..."

    

    # Clean directory

    rm -rf /var/www/html/*

    

    # Download WordPress

    cd /tmp

    wget -q https://wordpress.org/latest.tar.gz

    tar -xzf latest.tar.gz -C /var/www/

    mv /var/www/wordpress/* /var/www/html/

    rmdir /var/www/wordpress

    rm -f latest.tar.gz

    

    # Set permissions

    chown -R www-data:www-data /var/www/html

    find /var/www/html -type d -exec chmod 755 {} \;

    find /var/www/html -type f -exec chmod 644 {} \;

    

    # Create uploads directory

    mkdir -p /var/www/html/wp-content/uploads

    chown www-data:www-data /var/www/html/wp-content/uploads

    chmod 775 /var/www/html/wp-content/uploads

    

    log "WordPress files installed"

}


# Function to configure Caddy

configure_caddy() {

    log "Configuring Caddy..."

    

    . "$CONFIG_FILE"

    

    # Get PHP version

    PHP_VERSION=$(php -v 2>/dev/null | head -1 | awk '{print $2}' | cut -d. -f1,2)

    if [ -z "$PHP_VERSION" ]; then

        PHP_VERSION="8.2"

    fi

    

    PHP_SOCKET="/run/php/php${PHP_VERSION}-fpm.sock"

    

    # Create Caddyfile

    if [ "$ENABLE_SSL" = "true" ] && [ "$DOMAIN" != "localhost" ]; then

        # Production with domain

        cat > /etc/caddy/Caddyfile <<EOF

$DOMAIN {

    root * /var/www/html

    file_server

    

    php_fastcgi unix:$PHP_SOCKET {

        resolve_root_symlink

        index index.php

    }

    

    encode gzip

}

EOF

    else

        # Development/localhost

        cat > /etc/caddy/Caddyfile <<EOF

:80 {

    root * /var/www/html

    file_server

    

    php_fastcgi unix:$PHP_SOCKET {

        resolve_root_symlink

        index index.php

    }

    

    encode gzip

}

EOF

    fi

    

    # Restart Caddy

    systemctl restart caddy

    

    log "Caddy configured"

}


# Function to show installation progress

show_progress() {

    (

        echo "10" ; log "Installing prerequisites..." ; ensure_prerequisites > "$LOG_FILE" 2>&1

        echo "20" ; log "Cleaning existing installations..." ; clean_existing > "$LOG_FILE" 2>&1

        echo "30" ; log "Installing PHP..." ; install_php > "$LOG_FILE" 2>&1

        echo "40" ; log "Installing MariaDB..." ; install_mariadb > "$LOG_FILE" 2>&1

        echo "50" ; log "Installing Caddy..." ; install_caddy > "$LOG_FILE" 2>&1

        echo "70" ; log "Installing WordPress..." ; install_wordpress > "$LOG_FILE" 2>&1

        echo "85" ; log "Configuring Caddy..." ; configure_caddy > "$LOG_FILE" 2>&1

        echo "95" ; log "Finalizing..." ; sleep 2

        echo "100" ; log "Installation complete!" ; sleep 1

    ) | dialog --backtitle "WordPress Minimal Installer" \

               --title "Installation Progress" \

               --gauge "Setting up WordPress..." 10 60 0

}


# Function to show completion message

show_completion() {

    . "$CONFIG_FILE"

    

    # Determine access URL

    if [ "$DOMAIN" = "localhost" ]; then

        ACCESS_URL="http://localhost"

        ACCESS_MSG="Access your site at: http://localhost"

    elif [ "$ENABLE_SSL" = "true" ]; then

        ACCESS_URL="https://$DOMAIN"

        ACCESS_MSG="Access your site at: https://$DOMAIN"

    else

        ACCESS_URL="http://$DOMAIN"

        ACCESS_MSG="Access your site at: http://$DOMAIN"

    fi

    

    # Get server IP for alternative access

    SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "your-server-ip")

    

    show_logo

    

    dialog --backtitle "WordPress Minimal Installer" \

           --title "🎉 Installation Complete!" \

           --msgbox "\

✅ WordPress has been successfully installed!


$ACCESS_MSG

Admin panel: $ACCESS_URL/wp-admin


📋 Next Steps:

1. Open $ACCESS_URL in your browser

2. WordPress installation wizard will start

3. Follow the prompts to:

   - Select language

   - Enter database details

   - Configure site settings

   - Create admin account


🔧 Server Information:

- Server IP: $SERVER_IP (if accessing remotely)

- Web Server: Caddy

- PHP: $(php -v 2>/dev/null | head -1 | awk '{print $2}' || echo "Unknown")

- Log file: $LOG_FILE


⚠️  Database Setup:

You will need to create a MariaDB database

through the WordPress web interface.


Press OK to exit." 22 65

}


# Main installation flow

main() {

    log "Starting WordPress installation..."

    

    # Install prerequisites first

    ensure_prerequisites

    

    # Show welcome screen

    if ! show_welcome; then

        log "Installation cancelled by user"

        exit 0

    fi

    

    # Show configuration GUI

    show_config_gui

    

    # Show progress

    show_progress

    

    # Show completion message

    show_completion

    

    log "Installation process completed"

    echo ""

    echo "========================================"

    echo "WordPress installation is complete!"

    echo "========================================"

    echo ""

    echo "Open your browser and visit:"

    if [ "$DOMAIN" = "localhost" ]; then

        echo "  http://localhost"

    elif [ "$ENABLE_SSL" = "true" ]; then

        echo "  https://$DOMAIN"

    else

        echo "  http://$DOMAIN"

    fi

    echo ""

    echo "Follow the WordPress setup wizard to complete installation."

    echo "========================================"

}


# Run the main installation process

main "$@"
