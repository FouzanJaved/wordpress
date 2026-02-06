#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

# ===== CONFIGURATION =====
DOMAIN="sahmcore.com.sa"      # Change this to your domain
EMAIL="a.saeed@sahmcore.com.sa" # Change this to your email for Let's Encrypt notifications
WEBROOT="/var/www/html"   # Your website folder root
# ==========================

echo "======================================="
echo " Installing Let's Encrypt SSL for $DOMAIN"
echo "======================================="

# 1️⃣ Update system
sudo apt update -y

# 2️⃣ Install Certbot + Nginx plugin
sudo apt install -y certbot python3-certbot-nginx

# 3️⃣ Test Nginx config before SSL
sudo nginx -t

# 4️⃣ Obtain SSL certificate
sudo certbot --nginx --non-interactive \
  --agree-tos \
  --redirect \
  --domains $DOMAIN \
  --email $EMAIL

# 5️⃣ Test automatic renewal
sudo certbot renew --dry-run

echo "======================================="
echo " ✅ SSL Certificate Installed Successfully!"
echo " Your site https://$DOMAIN is now secure"
echo " Certificates are automatically renewed by Certbot"
echo "======================================="
