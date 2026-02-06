#!/bin/bash

# Minimal WordPress Installer with Logo - Template v1.1

# For Ubuntu Minimal with basic GUI configuration


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

        # Try to get logo as text/image

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

- MariaDB database

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

    : ${DB_NAME:="wordpress"}

    : ${DB_USER:="wpuser"}

    : ${REVERSE_PROXY_ENABLE:="false"}

    : ${PROXY_IP:=""}

    : ${PROXY_PORT:=""}

    

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

    

    # Database configuration

    dialog --backtitle "WordPress Minimal Installer" \

           --title "Database Configuration" \

           --form "Database settings:" \

           10 45 2 \

           "Database Name:"  1 1 "$DB_NAME"  1 15 20 0 \

           "Database User:"  2 1 "$DB_USER"  2 15 20 0 \

           2> "$TEMP_FILE"

    

    db_responses=()

    while IFS= read -r line; do

        db_responses+=("$line")

    done < "$TEMP_FILE"

    

    DB_NAME="${db_responses[0]:-wordpress}"

    DB_USER="${db_responses[1]:-wpuser}"

    

    # SSL configuration

    dialog --backtitle "WordPress Minimal Installer" \

           --title "SSL Configuration" \

           --menu "Enable SSL (HTTPS)?" 10 30 3 \

           1 "Yes, enable SSL" \

           2 "No, HTTP only" \

           3 "Auto-detect" \

           2> "$TEMP_FILE"

    

    ssl_choice=$(cat "$TEMP_FILE")

    case $ssl_choice in

        1) ENABLE_SSL="true" ;;

        2) ENABLE_SSL="false" ;;

        3) 

            if [[ "$DOMAIN" != "localhost" && "$DOMAIN" != *".local" ]]; then

                ENABLE_SSL="true"

            else

                ENABLE_SSL="false"

            fi

            ;;

        *) ENABLE_SSL="true" ;;

    esac

    

    # Reverse Proxy configuration

    dialog --backtitle "WordPress Minimal Installer" \

           --title "Reverse Proxy" \

           --yesno "Enable Reverse Proxy (for load balancers/CDN)?" 8 45

    

    if [ $? -eq 0 ]; then

        REVERSE_PROXY_ENABLE="true"

        dialog --backtitle "WordPress Minimal Installer" \

               --title "Reverse Proxy Details" \

               --form "Enter proxy server details:" \

               10 50 3 \

               "Proxy IP/URL:"   1 1 "$PROXY_IP"   1 15 30 0 \

               "Proxy Port:"     2 1 "$PROXY_PORT" 2 15 10 0 \

               "Admin Email:"    3 1 "$WP_ADMIN_EMAIL" 3 15 30 0 \

               2> "$TEMP_FILE"

        

        proxy_responses=()

        while IFS= read -r line; do

            proxy_responses+=("$line")

        done < "$TEMP_FILE"

        

        PROXY_IP="${proxy_responses[0]}"

        PROXY_PORT="${proxy_responses[1]}"

        WP_ADMIN_EMAIL="${proxy_responses[2]:-admin@localhost}"

    else

        REVERSE_PROXY_ENABLE="false"

        PROXY_IP=""

        PROXY_PORT=""

        

        # Get admin email separately

        dialog --backtitle "WordPress Minimal Installer" \

               --title "Admin Email" \

               --inputbox "Enter WordPress admin email:" \

               8 45 "$WP_ADMIN_EMAIL" \

               2> "$TEMP_FILE"

        WP_ADMIN_EMAIL=$(cat "$TEMP_FILE")

    fi

    

    # Generate random passwords

    DB_PASSWORD=$(openssl rand -base64 12 | tr -d '/+=' | cut -c1-16)

    WP_ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d '/+=' | cut -c1-12)

    

    # Save configuration

    cat > "$CONFIG_FILE" <<EOF

# WordPress Installation Configuration

DOMAIN="$DOMAIN"

EMAIL="$EMAIL"

ENABLE_SSL="$ENABLE_SSL"

WP_TITLE="$WP_TITLE"

WP_ADMIN_USER="$WP_ADMIN_USER"

WP_ADMIN_PASSWORD="$WP_ADMIN_PASSWORD"

WP_ADMIN_EMAIL="$WP_ADMIN_EMAIL"

DB_NAME="$DB_NAME"

DB_USER="$DB_USER"

DB_PASSWORD="$DB_PASSWORD"

REVERSE_PROXY_ENABLE="$REVERSE_PROXY_ENABLE"

PROXY_IP="$PROXY_IP"

PROXY_PORT="$PROXY_PORT"

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

║ DB Name: $DB_NAME

║ Reverse Proxy: $REVERSE_PROXY_ENABLE

${PROXY_IP:+║ Proxy: $PROXY_IP:$PROXY_PORT║}

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

        lsb-release > /dev/null 2>&1

}


# Function to install latest PHP (auto-detects version)

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

    [ -f "$PHP_INI" ] && sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 64M/' "$PHP_INI"

    

    systemctl restart "php$PHP_VERSION-fpm"

    

    echo "$PHP_VERSION"

}


# Function to install Caddy

install_caddy() {

    log "Installing Caddy..."
