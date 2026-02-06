#!/bin/bash

#############################################
# Ubuntu EC2 Setup Script for Docker
# This script installs Docker and Git
#############################################

set -e  # Exit on error

echo "=========================================="
echo "Starting Ubuntu EC2 Setup for Docker"
echo "=========================================="

# Update package index
echo ""
echo "[1/6] Updating package index..."
sudo apt-get update -y

# Install prerequisites
echo ""
echo "[2/6] Installing prerequisites..."
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git

# Add Docker's official GPG key
echo ""
echo "[3/6] Adding Docker's official GPG key..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up Docker repository
echo ""
echo "[4/6] Setting up Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index again
sudo apt-get update -y

# Install Docker Engine
echo ""
echo "[5/6] Installing Docker Engine..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker
echo ""
echo "[6/6] Starting and enabling Docker service..."
sudo systemctl start docker
sudo systemctl enable docker

# Add current user to docker group
echo ""
echo "Adding user to docker group..."
sudo usermod -aG docker $USER

# Verify installation
echo ""
echo "=========================================="
echo "Verifying Docker installation..."
echo "=========================================="
sudo docker --version
sudo docker info | grep "Server Version"

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "IMPORTANT: You need to log out and log back in for group changes to take effect."
echo "Or run: newgrp docker"
echo ""
echo "Next steps:"
echo "1. Clone the repository: git clone https://github.com/sarowar-alam/3-tier-docker-ubuntu.git"
echo "2. cd 3-tier-docker-ubuntu/deployDocker"
echo "3. Copy and edit .env: cp .env.example .env && nano .env"
echo "4. Run deployment: ./deploy-docker.sh"
echo ""
