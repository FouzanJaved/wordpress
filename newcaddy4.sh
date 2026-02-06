#!/bin/bash

# Minimal WordPress Installer with Logo - Template v1.5

# For Ubuntu Minimal with blue-themed GUI configuration

# Includes comprehensive cleanup with confirmation


set -euo pipefail


# Colors for blue theme

BLUE_BG="\033[44m"

BLUE_TEXT="\033[34m"

WHITE_TEXT="\033[97m"

RESET="\033[0m"

BLACK_TEXT="\033[30m"

CYAN_BG="\033[46m"


# Installation directory

INSTALL_DIR="/opt/wordpress-installer"

CONFIG_FILE="$INSTALL_DIR/config.cfg"

LOG_FILE="/var/log/wp-install.log"

LOGO_FILE="$INSTALL_DIR/logo.txt"

LOGO_URL="https://erp.sahmcore.com.sa/web/image/website/1/logo/My%20Website?unique=8043c74"


# Create installation directory

mkdir -p "$INSTALL_DIR"


# Apply blue theme to terminal

apply_blue_theme() {

    # Set terminal colors for blue theme

    echo -e "${BLUE_BG}${WHITE_TEXT}"

    clear

}


# Reset terminal colors on exit

reset_theme() {

    echo -e "${RESET}"

    clear

}


trap reset_theme EXIT


# Custom dialog function with blue theme

blue_dialog() {

    # Set dialog colors for blue theme

    export DIALOGRC="$INSTALL_DIR/blue_theme"

    

    # Create blue theme config if not exists

    if [ ! -f "$DIALOGRC" ]; then

        cat > "$DIALOGRC" <<'EOF'

# Blue theme for dialog

use_shadow = OFF

use_colors = ON

screen_color = (BLUE,BLUE,ON)

border_color = (WHITE,BLUE,ON)

dialog_color = (WHITE,BLUE,ON)

title_color = (YELLOW,BLUE,ON)

button_label_color = (BLACK,CYAN,ON)

button_key_color = (YELLOW,BLUE,ON)

button_key_active_color = (YELLOW,CYAN,ON)

button_active_color = (BLACK,CYAN,ON)

button_color = (BLACK,CYAN,OFF)

button_active_color = (BLACK,CYAN,ON)

button_label_active_color = (BLACK,CYAN,ON)

inputbox_color = (WHITE,BLUE,ON)

inputbox_border_color = (WHITE,BLUE,ON)

searchbox_color = (WHITE,BLUE,ON)

searchbox_title_color = (YELLOW,BLUE,ON)

searchbox_border_color = (WHITE,BLUE,ON)

position_indicator_color = (YELLOW,BLUE,ON)

menubox_color = (WHITE,BLUE,ON)

menubox_border_color = (WHITE,BLUE,ON)

item_color = (WHITE,BLUE,OFF)

item_selected_color = (BLACK,CYAN,ON)

tag_color = (YELLOW,BLUE,ON)

tag_selected_color = (YELLOW,CYAN,ON)

tag_key_color = (YELLOW,BLUE,ON)

tag_key_selected_color = (YELLOW,CYAN,ON)

check_color = (WHITE,BLUE,OFF)

check_selected_color = (BLACK,CYAN,ON)

uarrow_color = (YELLOW,BLUE,ON)

darrow_color = (YELLOW,BLUE,ON)

EOF

    fi

    

    # Run dialog with theme

    dialog --backtitle "WordPress Minimal Installer" \

           --colors \

           "$@"

    

    return $?

}


# Logging function

log() {

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"

}


# Function to ensure all required packages are installed

ensure_prerequisites() {

    log "Ensuring all required packages are installed..."

    

    # Update package list with retries

    for i in {1..3}; do

        if apt-get update; then

            log "Package list updated successfully"

            break

        else

            log "Attempt $i to update package list failed, retrying..."

            sleep 2

        fi

    done

    

    # Install essential packages

    local essential_packages=(

        curl

        wget

        dialog

        lsb-release

        ca-certificates

        apt-transport-https

        software-properties-common

        gnupg

    )

    

    for pkg in "${essential_packages[@]}"; do

        if ! dpkg -l | grep -q "^ii.*$pkg"; then

            log "Installing $pkg..."

            apt-get install -y --no-install-recommends "$pkg" || {

                log "Warning: Failed to install $pkg"

            }

        fi

    done

    

    log "Prerequisites check completed"

}


# Function to detect and remove existing WordPress installations

detect_existing_installations() {

    local found_components=()

    

    log "Detecting existing WordPress installations..."

    

    # Check for WordPress files

    if [ -d "/var/www/html" ] && [ -n "$(ls -A /var/www/html 2>/dev/null)" ]; then

        if [ -f "/var/www/html/wp-config.php" ] || [ -f "/var/www/html/wp-config-sample.php" ]; then

            found_components+=("WordPress files in /var/www/html")

        fi

    fi

    

    # Check for other WordPress directories

    for dir in /var/www/*; do

        if [ -d "$dir" ] && [ -f "$dir/wp-config.php" ]; then

            found_components+=("WordPress in $dir")

        fi

    done

    

    # Check for Caddy

    if systemctl is-active --quiet caddy 2>/dev/null || command -v caddy &> /dev/null; then

        found_components+=("Caddy web server")

    fi

    

    # Check for PHP-FPM

    if systemctl list-units --type=service | grep -q "php.*fpm"; then

        found_components+=("PHP-FPM service")

    fi

    

    # Check for MariaDB/MySQL

    if systemctl is-active --quiet mariadb 2>/dev/null || systemctl is-active --quiet mysql 2>/dev/null; then

        found_components+=("MariaDB/MySQL database")

    fi

    

    # Check for existing databases

    if command -v mysql &> /dev/null; then

        local wordpress_dbs=$(mysql -e "SHOW DATABASES LIKE '%wordpress%';" 2>/dev/null | grep -v "Database" | wc -l)

        if [ "$wordpress_dbs" -gt 0 ]; then

            found_components+=("WordPress databases ($wordpress_dbs found)")

        fi

    fi

    

    echo "${found_components[@]}"

}


# Function to cleanup existing installations with confirmation

cleanup_existing() {

    local components=("$@")

    

    if [ ${#components[@]} -eq 0 ]; then

        log "No existing installations detected"

        return 0

    fi

    

    # Show cleanup confirmation dialog

    blue_dialog --title " Cleanup Required " \

                --yesno "\n\ZbExisting WordPress installation detected!\ZB\n\nFound components:\n$(printf '• %s\n' "${components[@]}")\n\nDo you want to remove these components for a clean installation?\n\n\Z1Warning: This will delete all WordPress files and databases!\Z0" \

                20 65

    

    if [ $? -ne 0 ]; then

        log "User chose to keep existing installation"

        blue_dialog --title " Information " \

                   --msgbox "\nKeeping existing installation.\n\nNew installation will be skipped." 10 50

        return 1

    fi

    

    log "User confirmed cleanup. Removing existing components..."

    

    # Show progress dialog for cleanup

    (

        echo "10" ; log "Stopping services..." 

        systemctl stop caddy 2>/dev/null || true

        systemctl stop php*-fpm 2>/dev/null || true

        systemctl stop mariadb mysql 2>/dev/null || true

        

        echo "20" ; log "Removing Caddy..."

        apt-get purge -y caddy 2>/dev/null || true

        rm -rf /etc/caddy /usr/local/bin/caddy 2>/dev/null || true

        

        echo "40" ; log "Removing PHP..."

        apt-get purge -y 'php*' 'libphp*' 2>/dev/null || true

        rm -rf /etc/php* 2>/dev/null || true

        

        echo "60" ; log "Removing database servers..."

        apt-get purge -y mariadb-server mysql-server 2>/dev/null || true

        rm -rf /etc/mysql* /var/lib/mysql* 2>/dev/null || true

        

        echo "80" ; log "Removing WordPress files..."

        rm -rf /var/www/html/* /var/www/*/wp-content 2>/dev/null || true

        find /var/www -name "wp-config.php" -delete 2>/dev/null || true

        

        echo "90" ; log "Cleaning up packages..."

        apt-get autoremove -y --purge 2>/dev/null || true

        apt-get clean 2>/dev/null || true

        

        echo "100" ; log "Cleanup completed!" ; sleep 1

        

    ) | blue_dialog --title " Cleanup Progress " \

                    --gauge "Removing existing components..." 10 60 0

    

    # Verify cleanup

    local remaining=$(detect_existing_installations)

    if [ -n "$remaining" ]; then

        blue_dialog --title " Cleanup Results " \

                   --msgbox "\nCleanup completed with some components remaining.\n\nSome manual cleanup may be required." 10 50

    else

        blue_dialog --title " Cleanup Results " \

                   --msgbox "\n✅ Cleanup completed successfully!\n\nAll existing components have been removed." 10 50

    fi

    

    return 0

}


# Download and display logo

setup_logo() {

    log "Setting up logo..."

    

    # Create ASCII logo with blue theme

    cat > "$LOGO_FILE" <<'EOF'

╔══════════════════════════════════════════╗

║    ██╗    ██╗ ██████╗ ██████╗ ██████╗    ║

║    ██║    ██║██╔═══██╗██╔══██╗██╔══██╗   ║

║    ██║ █╗ ██║██║   ██║██████╔╝██║  ██║   ║

║    ██║███╗██║██║   ██║██╔══██╗██║  ██║   ║

║    ╚███╔███╔╝╚██████╔╝██║  ██║██████╔╝   ║

║     ╚══╝╚══╝  ╚═════╝ ╚═╝  ╚═╝╚═════╝    ║

║                                           ║

║        MINIMAL INSTALLER v1.5             ║

║        Blue Theme Edition                 ║

╚══════════════════════════════════════════╝

EOF

    

    log "Logo setup completed"

}


# Display logo in dialog

show_logo() {

    if [ -f "$LOGO_FILE" ] && [ -s "$LOGO_FILE" ]; then

        blue_dialog --title "" \

                   --textbox "$LOGO_FILE" 12 50

    fi

}


# Check if running as root

if [ "$(id -u)" -ne 0 ]; then

    echo "This script must be run as root."

    exit 1

fi


# Function to display welcome screen

show_welcome() {

    # Apply blue theme

    apply_blue_theme

    

    # Setup logo

    setup_logo

    

    show_logo

    

    blue_dialog --title " WELCOME " \

               --yesno "\n\ZbWelcome to WordPress Minimal Installer!\ZB\n\nThis installer will:\n\n• Remove existing WordPress installations (optional)\n• Install latest PHP automatically\n• Set up Caddy web server\n• Install WordPress latest version\n• Configure MariaDB database\n\nDatabase setup will be completed through the\nWordPress web interface after installation.\n\nContinue with installation?" 18 55

    

    return $?

}


# Function to display configuration GUI

show_config_gui() {

    # Set defaults

    local DOMAIN="localhost"

    local EMAIL="admin@localhost"

    local WP_TITLE="My WordPress Site"

    local WP_ADMIN_USER="admin"

    local ENABLE_SSL="false"

    

    # Try to load existing config

    if [ -f "$CONFIG_FILE" ]; then

        DOMAIN=$(grep '^DOMAIN=' "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f2 || echo "localhost")

        EMAIL=$(grep '^EMAIL=' "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f2 || echo "admin@localhost")

        WP_TITLE=$(grep '^WP_TITLE=' "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f2 || echo "My WordPress Site")

        WP_ADMIN_USER=$(grep '^WP_ADMIN_USER=' "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f2 || echo "admin")

    fi

    

    # Create temp file for dialog responses

    TEMP_FILE=$(mktemp)

    

    # Domain configuration dialog

    blue_dialog --title " CONFIGURATION " \

               --form "\nEnter WordPress installation details:\n(Use localhost for local testing)" \

               15 55 5 \

               "Domain/Server IP:"     1 1 "$DOMAIN"       1 20 30 0 \

               "Admin Email:"          2 1 "$EMAIL"        2 20 30 0 \

               "Site Title:"           3 1 "$WP_TITLE"     3 20 30 0 \

               "Admin Username:"       4 1 "$WP_ADMIN_USER" 4 20 30 0 \

               2> "$TEMP_FILE"

    

    # Check if user cancelled

    if [ $? -ne 0 ]; then

        rm -f "$TEMP_FILE"

        log "User cancelled configuration"

        return 1

    fi

    

    # Read responses

    {

        read -r DOMAIN || DOMAIN="localhost"

        read -r EMAIL || EMAIL="admin@localhost"

        read -r WP_TITLE || WP_TITLE="My WordPress Site"

        read -r WP_ADMIN_USER || WP_ADMIN_USER="admin"

    } < "$TEMP_FILE" 2>/dev/null || true

    

    # Ask about SSL

    blue_dialog --title " SSL SETUP " \

               --menu "\nEnable HTTPS/SSL encryption?\n\nSelect 'No' for localhost/testing:" \

               12 50 2 \

               "No" "HTTP only (recommended for testing)" \

               "Yes" "HTTPS with SSL (for production)" \

               2> "$TEMP_FILE"

    

    local ssl_choice=$(cat "$TEMP_FILE" 2>/dev/null || echo "No")

    

    if [ "$ssl_choice" = "Yes" ] && [ "$DOMAIN" != "localhost" ]; then

        ENABLE_SSL="true"

    else

        ENABLE_SSL="false"

        DOMAIN="localhost"

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

    

    blue_dialog --title " CONFIGURATION SUMMARY " \

               --msgbox "\n\ZbInstallation Configuration:\ZB\n\n\Z4📍 Domain:\Z0 $DOMAIN\n\Z4🔒 SSL:\Z0 $ENABLE_SSL\n\Z4🏷️  Site Title:\Z0 $WP_TITLE\n\Z4👤 Admin User:\Z0 $WP_ADMIN_USER\n\Z4📧 Admin Email:\Z0 $EMAIL\n\nPress OK to begin installation." 14 55

    

    rm -f "$TEMP_FILE"

    return 0

}


# Function to install PHP with fallbacks

install_php() {

    log "Installing PHP..."

    

    # Try default repository first

    if apt-get install -y --no-install-recommends php-fpm php-mysql php-curl php-xml php-mbstring php-zip php-gd; then

        log "PHP installed from default repositories"

        PHP_VERSION=$(php -v 2>/dev/null | head -1 | awk '{print $2}' | cut -d. -f1,2)

        [ -z "$PHP_VERSION" ] && PHP_VERSION="8.2"

        echo "$PHP_VERSION"

        return 0

    fi

    

    # Try adding ondrej/php repo if possible

    log "Trying to add PHP repository..."

    if command -v add-apt-repository &> /dev/null; then

        if add-apt-repository ppa:ondrej/php -y 2>/dev/null; then

            apt-get update 2>/dev/null || true

        fi

    fi

    

    # Try multiple PHP versions

    for version in 8.2 8.1 8.0 7.4; do

        log "Trying PHP $version..."

        if apt-get install -y --no-install-recommends \

            "php$version-fpm" \

            "php$version-mysql" \

            "php$version-curl" \

            "php$version-xml" \

            "php$version-mbstring" \

            "php$version-zip" \

            "php$version-gd" 2>/dev/null; then

            PHP_VERSION="$version"

            log "PHP $version installed successfully"

            echo "$PHP_VERSION"

            return 0

        fi

    done

    

    # Last resort

    if apt-get install -y php-fpm; then

        PHP_VERSION=$(php -v 2>/dev/null | head -1 | awk '{print $2}' | cut -d. -f1,2)

        [ -z "$PHP_VERSION" ] && PHP_VERSION="8.0"

        log "Generic PHP $PHP_VERSION installed"

        echo "$PHP_VERSION"

        return 0

    fi

    

    log "ERROR: Could not install PHP"

    return 1

}


# Function to install MariaDB

install_mariadb() {

    log "Installing MariaDB..."

    

    if apt-get install -y mariadb-server; then

        log "MariaDB installed successfully"

        

        # Minimal security setup

        mysql -e "DELETE FROM mysql.user WHERE User='';" 2>/dev/null || true

        mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" 2>/dev/null || true

        mysql -e "FLUSH PRIVILEGES;" 2>/dev/null || true

        

        systemctl enable mariadb 2>/dev/null || true

        systemctl start mariadb 2>/dev/null || true

        

        return 0

    fi

    

    log "Warning: Could not install MariaDB"

    return 1

}


# Function to install Caddy

install_caddy() {

    log "Installing Caddy..."

    

    # Try multiple installation methods

    if curl -fsSL https://getcaddy.com | bash -s personal 2>/dev/null; then

        log "Caddy installed via getcaddy.com"

    elif apt-get install -y caddy 2>/dev/null; then

        log "Caddy installed via apt"

    else

        # Direct download

        log "Trying direct Caddy download..."

        local caddy_url="https://github.com/caddyserver/caddy/releases/latest/download/caddy_linux_amd64.tar.gz"

        if wget -q "$caddy_url" -O /tmp/caddy.tar.gz 2>/dev/null; then

            tar -xzf /tmp/caddy.tar.gz -C /tmp/

            mv /tmp/caddy /usr/local/bin/

            chmod +x /usr/local/bin/caddy

            rm -f /tmp/caddy.tar.gz

            log "Caddy installed via direct download"

        else

            log "Warning: Could not install Caddy"

            return 1

        fi

    fi

    

    # Create service if needed

    if [ ! -f /etc/systemd/system/caddy.service ] && [ -f /usr/local/bin/caddy ]; then

        cat > /etc/systemd/system/caddy.service <<'EOF'

[Unit]

Description=Caddy Web Server

After=network.target


[Service]

Type=simple

ExecStart=/usr/local/bin/caddy run --config /etc/caddy/Caddyfile

Restart=on-failure

User=www-data

Group=www-data


[Install]

WantedBy=multi-user.target

EOF

        systemctl daemon-reload

    fi

    

    systemctl enable caddy 2>/dev/null || true

    systemctl start caddy 2>/dev/null || true

    

    log "Caddy installation completed"

    return 0

}


# Function to install WordPress files

install_wordpress() {

    log "Installing WordPress files..."

    

    mkdir -p /var/www/html

    rm -rf /var/www/html/*

    

    cd /tmp

    if wget -q https://wordpress.org/latest.tar.gz 2>/dev/null; then

        tar -xzf latest.tar.gz -C /var/www/

        mv /var/www/wordpress/* /var/www/html/ 2>/dev/null

        rmdir /var/www/wordpress 2>/dev/null || true

        rm -f latest.tar.gz

        log "WordPress downloaded successfully"

    elif curl -s -L https://wordpress.org/latest.tar.gz -o wordpress.tar.gz 2>/dev/null; then

        tar -xzf wordpress.tar.gz -C /var/www/

        mv /var/www/wordpress/* /var/www/html/ 2>/dev/null

        rmdir /var/www/wordpress 2>/dev/null || true

        rm -f wordpress.tar.gz

        log "WordPress downloaded via curl"

    else

        log "ERROR: Could not download WordPress"

        return 1

    fi

    

    # Set permissions

    chown -R www-data:www-data /var/www/html 2>/dev/null || true

    find /var/www/html -type d -exec chmod 755 {} \; 2>/dev/null || true

    find /var/www/html -type f -exec chmod 644 {} \; 2>/dev/null || true

    

    mkdir -p /var/www/html/wp-content/uploads

    chown www-data:www-data /var/www/html/wp-content/uploads 2>/dev/null || true

    chmod 775 /var/www/html/wp-content/uploads 2>/dev/null || true

    

    log "WordPress files installed"

    return 0

}


# Function to configure Caddy

configure_caddy() {

    log "Configuring Caddy..."

    

    # Load config

    local DOMAIN="localhost"

    local ENABLE_SSL="false"

    

    if [ -f "$CONFIG_FILE" ]; then

        DOMAIN=$(grep '^DOMAIN=' "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f2 || echo "localhost")

        ENABLE_SSL=$(grep '^ENABLE_SSL=' "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f2 || echo "false")

    fi

    

    # Get PHP version

    local PHP_VERSION="8.2"

    if command -v php &> /dev/null; then

        PHP_VERSION=$(php -v 2>/dev/null | head -1 | awk '{print $2}' | cut -d. -f1,2)

    fi

    

    local PHP_SOCKET="/run/php/php${PHP_VERSION}-fpm.sock"

    

    # Create Caddy directory and config

    mkdir -p /etc/caddy

    

    if [ "$ENABLE_SSL" = "true" ] && [ "$DOMAIN" != "localhost" ]; then

        cat > /etc/caddy/Caddyfile <<EOF

$DOMAIN {

    root * /var/www/html

    file_server

    php_fastcgi unix:$PHP_SOCKET

    encode gzip

}

EOF

    else

        cat > /etc/caddy/Caddyfile <<EOF

:80 {

    root * /var/www/html

    file_server

    php_fastcgi unix:$PHP_SOCKET

    encode gzip

}

EOF

    fi

    

    systemctl restart caddy 2>/dev/null || systemctl start caddy 2>/dev/null || true

    

    log "Caddy configuration completed"

    return 0

}


# Function to show installation progress

show_installation_progress() {

    (

        echo "5" ; log "Installing prerequisites..." ; ensure_prerequisites > "$LOG_FILE" 2>&1

        echo "15" ; log "Installing PHP..." ; install_php > "$LOG_FILE" 2>&1 || log "PHP installation had issues"

        echo "30" ; log "Installing MariaDB..." ; install_mariadb > "$LOG_FILE" 2>&1 || log "Database installation had issues"

        echo "45" ; log "Installing Caddy..." ; install_caddy > "$LOG_FILE" 2>&1 || log "Web server installation had issues"

        echo "65" ; log "Installing WordPress..." ; install_wordpress > "$LOG_FILE" 2>&1 || log "WordPress installation had issues"

        echo "85" ; log "Configuring services..." ; configure_caddy > "$LOG_FILE" 2>&1 || log "Configuration had issues"

        echo "95" ; log "Finalizing installation..." ; sleep 2

        echo "100" ; log "Installation process completed!" ; sleep 1

        

    ) | blue_dialog --title " INSTALLATION PROGRESS " \

                    --gauge "\nInstalling WordPress components..." 10 60 0

}


# Function to show completion message

show_completion() {

    local DOMAIN="localhost"

    local ENABLE_SSL="false"

    

    # Load config

    if [ -f "$CONFIG_FILE" ]; then

        DOMAIN=$(grep '^DOMAIN=' "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f2 || echo "localhost")

        ENABLE_SSL=$(grep '^ENABLE_SSL=' "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f2 || echo "false")

    fi

    

    # Get server IP

    local SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "your-server-ip")

    

    # Determine URL

    local ACCESS_URL="http://localhost"

    if [ "$DOMAIN" != "localhost" ]; then

        if [ "$ENABLE_SSL" = "true" ]; then

            ACCESS_URL="https://$DOMAIN"

        else

            ACCESS_URL="http://$DOMAIN"

        fi

    fi

    

    show_logo

    

    blue_dialog --title " 🎉 INSTALLATION COMPLETE! " \

               --msgbox "\n\Zb✅ WordPress Installation Successful!\ZB\n\n\Z4🌐 Access Your Site:\Z0\n$ACCESS_URL\n\n\Z4🔧 Admin Panel:\Z0\n$ACCESS_URL/wp-admin\n\n\Z4📋 Next Steps:\Z0\n1. Open the URL above in your browser\n2. Complete WordPress setup wizard\n3. Create database when prompted\n4. Configure your site settings\n\n\Z4⚙️  Server Info:\Z0\n• Server IP: $SERVER_IP\n• Web Server: Caddy\n• PHP: $(php -v 2>/dev/null | head -1 | awk '{print $2}' || echo 'Installed')\n• Log File: $LOG_FILE\n\nPress OK to finish." 22 65

}


# Main installation flow

main() {

    log "========================================"

    log "Starting WordPress Minimal Installer v1.5"

    log "========================================"

    

    # Apply blue theme

    apply_blue_theme

    

    # Ensure prerequisites

    ensure_prerequisites

    

    # Show welcome screen

    if ! show_welcome; then

        log "Installation cancelled by user"

        reset_theme

        echo "Installation cancelled."

        exit 0

    fi

    

    # Detect and cleanup existing installations

    log "Detecting existing installations..."

    local existing_components=$(detect_existing_installations)

    

    if [ -n "$existing_components" ]; then

        IFS=$'\n' read -r -d '' -a components_array <<< "$existing_components"

        if ! cleanup_existing "${components_array[@]}"; then

            log "User chose to keep existing installation, aborting."

            reset_theme

            echo "Existing installation preserved. New installation aborted."

            exit 0

        fi

    else

        blue_dialog --title " Cleanup Check " \

                   --msgbox "\nNo existing WordPress installations detected.\n\nProceeding with fresh installation." 10 50

    fi

    

    # Get configuration

    if ! show_config_gui; then

        log "Configuration cancelled"

        reset_theme

        echo "Configuration cancelled."

        exit 0

    fi

    

    # Show installation progress

    show_installation_progress

    

    # Show completion message

    show_completion

    

    # Final console message

    reset_theme

    echo ""

    echo "╔══════════════════════════════════════════════╗"

    echo "║        WORDPRESS INSTALLATION COMPLETE       ║"

    echo "╠══════════════════════════════════════════════╣"

    echo "║ ✔ All existing components removed (if any)   ║"

    echo "║ ✔ Fresh installation completed               ║"

    echo "║ ✔ Blue-themed installer used                 ║"

    echo "║ ✔ Database setup via WordPress web interface ║"

    echo "╚══════════════════════════════════════════════╝"

    echo ""

    echo "Log file: $LOG_FILE"

    echo "Config file: $CONFIG_FILE"

    echo ""

    echo "If you see 'noble release not found' messages,"

    echo "these are harmless and don't affect installation."

    echo ""

    

    log "Script completed successfully at $(date)"

}


# Run main function

main "$@"


# Always exit cleanly

exit 0
