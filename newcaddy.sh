#!/bin/bash
set -e

echo "======================================"
echo " Installing Caddy Web Server on Ubuntu"
echo "======================================"

# Update system
sudo apt update -y
sudo apt upgrade -y

# Install dependencies
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl

# Add Caddy GPG key
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
  | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg

# Add Caddy repository
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
  | sudo tee /etc/apt/sources.list.d/caddy-stable.list

# Update repo list
sudo apt update -y

# Ins
