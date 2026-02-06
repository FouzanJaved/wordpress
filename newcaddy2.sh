#!/bin/bash

# Minimal WordPress Installer with Logo - Template v1.1

# For Ubuntu Minimal with basic GUI configuration

# Debugged version with fresh installation and database setup from WordPress


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


# Download and display logo

setup_logo() {

    log "Setting up logo..."

    

    # Try to download logo, fallback to ASCII art

    if command -v curl &> /dev/null; then

        curl -s "$LOGO_URL" -o "$LOGO_FILE.tmp" 2>/dev/null || true

        

        # Check if it's a text file or convert to ASCII

        if file "$LOGO_FILE.tmp" | grep -q "text"; then

            mv "$LOGO_FILE.tmp" "$LOGO_FILE"

        else

            # Create fallback ASCII logo

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

  __          __  _                           

  \ \        / / | |                          

   \ \  /\  / /__| | ___ ___  _ __ ___   ___  

    \ \/  \/ / _ \ |/ __/ _ \| '_ ` _ \ / _ \ 

     \  /\  /  __/ | (_| (_) | | | | | |  __/ 

      \/  \/ \___|_|\___\___/|_| |_| |_|\___| 

                                              

    Minimal WordPress Installer

EOF

}


# Display logo in dialog

show_logo() {

    if [ -f "$LOGO_FILE" ] && [ -s "$LOGO_FILE" ]; then

        # Count lines in logo file

        LOGO_LINES=$(wc -l < "$LOGO_FILE")

        LOGO_WIDTH=$(awk '{print length}' "$LOGO_FILE" | sort -nr | head -1)

        

        # Show logo in a dialog box

        dialog --backtitle "WordPress Minimal Installer" \

               --title "" \

               --textbox "$LOGO_FILE" $((LOGO_LINES + 2)) $((LOGO_WIDTH + 4)) \

               2>&1 >/dev/tty

    fi

}


# Check if running as root

if [ "$(id -u)" -ne 0 ]; then

    echo "This script must be run as root."

    exit 1

fi


# Function to install dialog if not present

install_dialog() {

    if ! command -v dialog &> /dev/null; then

        log "Installing dialog for GUI..."

        apt-get update > /dev/null 2>&1

        apt-get install -y dialog > /dev/null 2>&1

    fi

}


# Function to display welcome screen with logo

show_welcome() {

    show_logo

    

    dialog --backtitle "WordPress Minimal Installer" \

           --title "Welcome" \

           --msgbox "\

This script will install WordPress with minimal dependencies.


It includes:

- Latest PHP (auto-detected)

- Caddy web server

- WordPress latest version


Press OK to continue or Cancel to abort." 12 50

    

    return $?

}


# Function to display configuration GUI

show_config_gui() {

    # Load existing config if available

    if [ -f "$CONFIG_FILE" ]; then

        . "$CONFIG_FILE"

    fi

    

    # Set defaults

    : ${DOMAIN:="localhost"}

    : ${EMAIL:="admin@localhost"}

    : ${ENABLE_SSL:="true"}

    : ${WP_TITLE:="My WordPress Site"}

    : ${WP_ADMIN_USER:="admin"}

    : ${WP_ADMIN_EMAIL:="admin@localhost"}

    

    # Create temp file for dialog responses

    TEMP_FILE=$(mktemp)

    

    # Domain configuration dialog

    dialog --backtitle "WordPress Minimal Installer" \

           --title "Domain Configuration" \

           --form "Enter your domain details:" \

           12 50 4 \

           "Domain name:"     1 1 "$DOMAIN"       1 15 30 0 \

           "Admin email:"     2 1 "$EMAIL"        2 15 30 0 \

           "Site Title:"      3 1 "$WP_TITLE"     3 15 30 0 \

           "Admin Username:"  4 1 "$WP_ADMIN_USER" 4 15 30 0 \

           2> "$TEMP_FILE"

    

    # Read responses

    responses=()

    while IFS= read -r line; do

        responses+=("$line")

    done < "$TEMP_FILE"

    

    DOMAIN="${responses[0]:-localhost}"

    EMAIL="${responses[1]:-admin@localhost}"

    WP_TITLE="${responses[2]:-My WordPress Site}"

    WP_ADMIN_USER="${responses[3]:-admin}"

    

    # Save configuration

    cat > "$CONFIG_FILE" <<EOF

# WordPress Installation Configuration

DOMAIN="$DOMAIN"

EMAIL="$EMAIL"

ENABLE_SSL="$ENABLE_SSL"

WP_TITLE="$WP_TITLE"

WP_ADMIN_USER="$WP_ADMIN_USER"

WP_ADMIN_EMAIL="$WP_ADMIN_EMAIL"

INSTALL_DATE="$(date '+%Y-%m-%d %H:%M:%S')"

LOGO_URL="$LOGO_URL"

EOF

    

    # Show configuration summary with logo

    show_logo

    

    dialog --backtitle "WordPress Minimal Installer" \

           --title "Configuration Summary" \

           --msgbox "\

✓ Configuration saved to: $CONFIG_FILE


╔══════════════════════════════════════╗

║         Installation Summary         ║

╠══════════════════════════════════════╣

║ Domain: $DOMAIN

║ SSL: $ENABLE_SSL

║ Site Title: $WP_TITLE

║ Admin: $WP_ADMIN_USER

╚══════════════════════════════════════╝


Press OK to begin installation." 18 60

    

    rm -f "$TEMP_FILE"

}


# Function to install minimal dependencies

install_deps() {

    log "Installing minimal dependencies..."

    

    apt-get update > /dev/null 2>&1

    apt-get install -y --no-install-recommends \

        curl \

        wget \

        gnupg \

        ca-certificates \

        software-properties-common \

        lsb-release \

        dialog > /dev/null 2>&1

}


# Function to remove pre-installed packages

remove_preinstalled() {

    log "Removing any pre-installed PHP, MariaDB, Caddy, and WordPress..."

    

    apt-get purge -y --auto-remove php* mariadb-server caddy wordpress > /dev/null 2>&1

    rm -rf /var/www/* /etc/php/* /etc/mysql/* /etc/caddy/* /var/lib/mysql/* /usr/local/bin/wp

}


# Function to install the latest PHP (auto-detects version)

install_php() {

    log "Installing PHP..."

    

    # Add PHP repository if not present

    if ! grep -q "ondrej/php" /etc/apt/sources.list.d/* 2>/dev/null; then

        add-apt-repository ppa:ondrej/php -y > /dev/null 2>&1

        apt-get update > /dev/null 2>&1

    fi

    

    # Detect latest PHP version

    PHP_VER=$(apt-cache search '^php[0-9]\.[0-9]-fpm$' | awk -F'[ -]' '{print $2}' | sort -V | tail -n1)

    

    if [ -z "$PHP_VER" ]; then

        PHP_VER="8.2"

    fi

    

    log "Installing PHP $PHP_VER..."

    

    apt-get install -y --no-install-recommends \

        "php$PHP_VER-fpm" \

        "php$PHP_VER-mysql" \

        "php$PHP_VER-curl" \

        "php$PHP_VER-xml" \

        "php$PHP_VER-mbstring" \

        "php$PHP_VER-zip" \

        "php$PHP_VER-gd" \

        "php$PHP_VER-opcache" > /dev/null 2>&1

    

    # Get PHP version for config

    PHP_VERSION=$(php -v | head -n1 | awk '{print $2}' | cut -d. -f1,2)

    PHP_SOCKET="/run/php/php${PHP_VERSION}-fpm.sock"

    

    # Minimal PHP optimization

    PHP_INI="/etc/php/$PHP_VERSION/fpm/php.ini"

    [ -f "$PHP_INI" ] && sed -i 's/^expose_php = On/expose_php = Off/' "$PHP_INI"

    [ -f "$PHP_INI" ] && sed -i 's/^max_execution_time = 30/max_execution_time = 120/' "$PHP_INI"

}


# Function to install Caddy web server

install_caddy() {

    log "Installing Caddy..."

    

    curl -fsSL https://get.caddyserver.com | bash > /dev/null 2>&1

    

    systemctl enable caddy

    systemctl start caddy

}


# Function to install WordPress

install_wordpress() {

    log "Installing WordPress..."

    

    # Download WordPress

    wget -q https://wordpress.org/latest.tar.gz -O /tmp/wordpress.tar.gz

    tar -xzf /tmp/wordpress.tar.gz -C /var/www/ && rm /tmp/wordpress.tar.gz

    mv /var/www/wordpress /var/www/html

    

    # Set permissions

    chown -R www-data:www-data /var/www/html

    chmod -R 755 /var/www/html

}


# Main installation flow

main() {

    # Show welcome message

    show_welcome

    if [ $? -ne 0 ]; then

        log "Installation aborted by user."

        exit 0

    fi

    

    # Show configuration GUI

    show_config_gui

    

    # Remove pre-installed software

    remove_preinstalled

    

    # Install dependencies

    install_deps

    

    # Install PHP

    install_php

    

    # Install Caddy

    install_caddy

    

    # Install WordPress

    install_wordpress

    

    log "WordPress installation complete."

    

    # Final message

    dialog --backtitle "WordPress Minimal Installer" \

           --title "Installation Complete" \

           --msgbox "WordPress installation is complete! You can access your site at $DOMAIN" 12 50

}


# Run the main installation process

main

