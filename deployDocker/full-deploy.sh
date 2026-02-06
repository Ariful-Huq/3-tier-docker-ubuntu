#!/bin/bash

#############################################
# Full Automated Deployment Script
# Complete setup from fresh Ubuntu to running application
#############################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=========================================="
echo "BMI Health Tracker - Full Deployment"
echo "=========================================="
echo ""
echo "This script will:"
echo "  1. Install Docker and Git"
echo "  2. Configure environment variables"
echo "  3. Deploy all containers"
echo "  4. Verify deployment"
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

#############################################
# STEP 1: Install Docker and Git
#############################################
echo ""
echo "=========================================="
echo "[STEP 1/4] Installing Docker and Git"
echo "=========================================="

if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓ Docker already installed${NC}"
    docker --version
else
    echo "Installing Docker..."
    bash "$SCRIPT_DIR/setup-ubuntu.sh"
    
    echo ""
    echo -e "${YELLOW}Important: Group changes applied${NC}"
    echo "You may need to log out and log back in, or run: newgrp docker"
fi

if command -v git &> /dev/null; then
    echo -e "${GREEN}✓ Git already installed${NC}"
    git --version
fi

#############################################
# STEP 2: Configure Environment
#############################################
echo ""
echo "=========================================="
echo "[STEP 2/4] Configuring Environment"
echo "=========================================="

# Check if .env already exists
if [ -f "$SCRIPT_DIR/.env" ]; then
    echo -e "${YELLOW}.env file already exists${NC}"
    read -p "Use existing .env? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo "Using existing .env file"
    else
        rm "$SCRIPT_DIR/.env"
    fi
fi

# Create .env if it doesn't exist
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo "Creating .env file..."
    echo ""
    
    # Get EC2 public IP automatically
    EC2_PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
    
    echo -e "${BLUE}Please provide the following information:${NC}"
    echo ""
    
    # Database name
    read -p "Database name [bmi_health_db]: " DB_NAME
    DB_NAME=${DB_NAME:-bmi_health_db}
    
    # Database user
    read -p "Database user [bmi_user]: " DB_USER
    DB_USER=${DB_USER:-bmi_user}
    
    # Database password
    while true; do
        read -s -p "Database password (min 8 characters): " DB_PASSWORD
        echo
        if [ ${#DB_PASSWORD} -ge 8 ]; then
            read -s -p "Confirm password: " DB_PASSWORD_CONFIRM
            echo
            if [ "$DB_PASSWORD" = "$DB_PASSWORD_CONFIRM" ]; then
                break
            else
                echo -e "${RED}Passwords do not match. Try again.${NC}"
            fi
        else
            echo -e "${RED}Password must be at least 8 characters. Try again.${NC}"
        fi
    done
    
    # Frontend URL
    echo ""
    echo "Detected EC2 Public IP: $EC2_PUBLIC_IP"
    read -p "Frontend URL [http://$EC2_PUBLIC_IP]: " FRONTEND_URL
    FRONTEND_URL=${FRONTEND_URL:-http://$EC2_PUBLIC_IP}
    
    # Ensure URL has http:// or https:// prefix
    if [[ ! "$FRONTEND_URL" =~ ^https?:// ]]; then
        FRONTEND_URL="http://$FRONTEND_URL"
    fi
    
    # Create .env file
    cat > "$SCRIPT_DIR/.env" << EOF
# PostgreSQL Database Configuration
POSTGRES_DB=$DB_NAME
POSTGRES_USER=$DB_USER
POSTGRES_PASSWORD=$DB_PASSWORD

# Backend Database Connection
DATABASE_URL=postgresql://$DB_USER:$DB_PASSWORD@postgres-db:5432/$DB_NAME

# Backend Server Configuration
PORT=3000
NODE_ENV=production

# CORS Configuration
FRONTEND_URL=$FRONTEND_URL

# Container Names
CONTAINER_DB=postgres-db
CONTAINER_BACKEND=backend-api
CONTAINER_FRONTEND=frontend-web

# Docker Network
NETWORK_NAME=bmi-health-network

# Docker Volume
VOLUME_NAME=postgres-data
EOF
    
    echo ""
    echo -e "${GREEN}✓ .env file created${NC}"
    echo ""
    echo "Configuration:"
    echo "  Database: $DB_NAME"
    echo "  User: $DB_USER"
    echo "  Frontend URL: $FRONTEND_URL"
    echo ""
fi

#############################################
# STEP 3: Deploy Docker Containers
#############################################
echo ""
echo "=========================================="
echo "[STEP 3/4] Deploying Docker Containers"
echo "=========================================="

# Make deploy script executable
chmod +x "$SCRIPT_DIR/deploy-docker.sh"

# Run deployment
bash "$SCRIPT_DIR/deploy-docker.sh"

#############################################
# STEP 4: Verify Deployment
#############################################
echo ""
echo "=========================================="
echo "[STEP 4/4] Verifying Deployment"
echo "=========================================="

# Source environment
source "$SCRIPT_DIR/.env"

echo ""
echo "Checking container status..."
sleep 3

# Check containers
RUNNING_CONTAINERS=$(docker ps --filter "name=$CONTAINER_DB|$CONTAINER_BACKEND|$CONTAINER_FRONTEND" --format "{{.Names}}" | wc -l)

if [ $RUNNING_CONTAINERS -eq 3 ]; then
    echo -e "${GREEN}✓ All 3 containers are running${NC}"
else
    echo -e "${YELLOW}⚠️  Only $RUNNING_CONTAINERS/3 containers running${NC}"
fi

echo ""
echo "Testing endpoints..."

# Test health endpoint
if curl -s -f http://localhost/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Health endpoint responding${NC}"
else
    echo -e "${YELLOW}⚠️  Health endpoint not responding (may need a moment to start)${NC}"
fi

# Test frontend
if curl -s -f http://localhost/ > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Frontend responding${NC}"
else
    echo -e "${YELLOW}⚠️  Frontend not responding (may need a moment to start)${NC}"
fi

# Get EC2 public IP
EC2_PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "")

#############################################
# Deployment Summary
#############################################
echo ""
echo "=========================================="
echo -e "${GREEN}Deployment Complete!${NC}"
echo "=========================================="
echo ""
echo "Application Information:"
echo "------------------------"

if [ -n "$EC2_PUBLIC_IP" ]; then
    echo "  Public URL: http://$EC2_PUBLIC_IP"
else
    echo "  Local URL: http://localhost"
fi

echo "  Health Check: http://localhost/health"
echo ""

echo "Container Status:"
echo "-----------------"
docker ps --filter "name=$CONTAINER_DB|$CONTAINER_BACKEND|$CONTAINER_FRONTEND" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "Volume Information:"
echo "-------------------"
docker volume inspect $VOLUME_NAME --format "  Name: {{.Name}}\n  Mountpoint: {{.Mountpoint}}\n  Driver: {{.Driver}}"

echo ""
echo "Management Scripts:"
echo "-------------------"
echo "  View logs:        cd $SCRIPT_DIR && ./logs.sh"
echo "  Stop containers:  cd $SCRIPT_DIR && ./stop-containers.sh"
echo "  Restart:          cd $SCRIPT_DIR && ./restart-containers.sh"
echo "  Backup database:  cd $SCRIPT_DIR && ./backup-database.sh"
echo "  Cleanup all:      cd $SCRIPT_DIR && ./cleanup-all.sh"

echo ""
echo "AWS Security Group Check:"
echo "-------------------------"
echo "  ⚠️  Ensure port 80 (HTTP) is open in your EC2 Security Group"
echo "  1. Go to EC2 Console → Security Groups"
echo "  2. Select your instance's security group"
echo "  3. Add inbound rule: HTTP (80) from 0.0.0.0/0"

echo ""
echo "Next Steps:"
echo "-----------"
echo "  1. Access application: http://$EC2_PUBLIC_IP"
echo "  2. Test adding a BMI measurement"
echo "  3. For HTTPS setup, see: $SCRIPT_DIR/HTTPS_SETUP.md"
echo "  4. For manual deployment steps, see: $SCRIPT_DIR/MANUAL_DEPLOYMENT.md"

echo ""
echo "Troubleshooting:"
echo "----------------"
echo "  If application is not accessible:"
echo "    - Check container logs: docker logs <container-name>"
echo "    - Verify containers are running: docker ps"
echo "    - Check AWS Security Group (port 80 must be open)"
echo "    - Wait 30 seconds for containers to fully start"

echo ""
echo "=========================================="
echo -e "${GREEN}🎉 Setup Complete! 🎉${NC}"
echo "=========================================="
echo ""

# Offer to view logs
read -p "View container logs now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "=== Backend Logs (last 20 lines) ==="
    docker logs --tail 20 $CONTAINER_BACKEND
    echo ""
    echo "=== Frontend Logs (last 20 lines) ==="
    docker logs --tail 20 $CONTAINER_FRONTEND
fi

echo ""
echo "Deployment finished at: $(date)"
echo ""
