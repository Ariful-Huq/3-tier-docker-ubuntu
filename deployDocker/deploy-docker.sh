#!/bin/bash

#############################################
# Docker Deployment Script
# Deploys 3-tier BMI Health Tracker
#############################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "BMI Health Tracker - Docker Deployment"
echo "=========================================="

# Check if .env file exists
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo -e "${RED}Error: .env file not found!${NC}"
    echo "Please copy .env.example to .env and configure it:"
    echo "  cp $SCRIPT_DIR/.env.example $SCRIPT_DIR/.env"
    echo "  nano $SCRIPT_DIR/.env"
    exit 1
fi

# Load environment variables
echo ""
echo "Loading environment variables..."
source "$SCRIPT_DIR/.env"

# Verify required variables
if [ -z "$POSTGRES_PASSWORD" ] || [ "$POSTGRES_PASSWORD" = "Change_Me_Strong_Password_123!" ]; then
    echo -e "${YELLOW}Warning: Please change the default POSTGRES_PASSWORD in .env file!${NC}"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Clean up existing containers (optional)
echo ""
read -p "Remove existing containers if they exist? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Stopping and removing existing containers..."
    docker stop $CONTAINER_FRONTEND $CONTAINER_BACKEND $CONTAINER_DB 2>/dev/null || true
    docker rm $CONTAINER_FRONTEND $CONTAINER_BACKEND $CONTAINER_DB 2>/dev/null || true
fi

#############################################
# STEP 1: Create Docker Network
#############################################
echo ""
echo "[STEP 1/4] Creating Docker network..."
if docker network inspect $NETWORK_NAME >/dev/null 2>&1; then
    echo "Network '$NETWORK_NAME' already exists."
else
    docker network create $NETWORK_NAME
    echo -e "${GREEN}✓ Network created: $NETWORK_NAME${NC}"
fi

#############################################
# STEP 2: Start PostgreSQL Database
#############################################
echo ""
echo "[STEP 2/4] Starting PostgreSQL database..."

# Check if volume exists
if docker volume inspect $VOLUME_NAME >/dev/null 2>&1; then
    echo "Volume '$VOLUME_NAME' already exists (data will be preserved)."
else
    docker volume create $VOLUME_NAME
    echo -e "${GREEN}✓ Volume created: $VOLUME_NAME${NC}"
fi

# Verify migration files exist
echo ""
echo "Checking migration files..."
MIGRATION_1="$PROJECT_ROOT/backend/migrations/001_create_measurements.sql"
MIGRATION_2="$PROJECT_ROOT/backend/migrations/002_add_measurement_date.sql"

if [ ! -f "$MIGRATION_1" ]; then
    echo -e "${RED}Error: Migration file not found: $MIGRATION_1${NC}"
    echo "Current directory: $(pwd)"
    echo "Project root: $PROJECT_ROOT"
    exit 1
fi

if [ ! -f "$MIGRATION_2" ]; then
    echo -e "${RED}Error: Migration file not found: $MIGRATION_2${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Migration files found${NC}"

# Run PostgreSQL container
docker run -d \
    --name $CONTAINER_DB \
    --network $NETWORK_NAME \
    -e POSTGRES_DB=$POSTGRES_DB \
    -e POSTGRES_USER=$POSTGRES_USER \
    -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
    -v "$MIGRATION_1:/docker-entrypoint-initdb.d/001_create_measurements.sql:ro" \
    -v "$MIGRATION_2:/docker-entrypoint-initdb.d/002_add_measurement_date.sql:ro" \
    -v $VOLUME_NAME:/var/lib/postgresql/data \
    --restart unless-stopped \
    postgres:15-alpine

echo -e "${GREEN}✓ PostgreSQL container started${NC}"

# Wait for database to be ready
echo ""
echo "Waiting for database to be ready..."
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if docker exec $CONTAINER_DB pg_isready -U $POSTGRES_USER -d $POSTGRES_DB >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Database is ready!${NC}"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Attempt $RETRY_COUNT/$MAX_RETRIES - waiting..."
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}Error: Database failed to start in time!${NC}"
    echo "Check logs: docker logs $CONTAINER_DB"
    exit 1
fi

# Verify migrations ran
echo ""
echo "Verifying database migrations..."
docker exec $CONTAINER_DB psql -U $POSTGRES_USER -d $POSTGRES_DB -c "\dt" | grep measurements >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Database migrations completed successfully${NC}"
else
    echo -e "${YELLOW}Warning: Could not verify migrations. Check manually.${NC}"
fi

#############################################
# STEP 3: Build and Start Backend API
#############################################
echo ""
echo "[STEP 3/4] Building and starting Backend API..."

# Build backend image
cd "$PROJECT_ROOT/backend"
docker build -t bmi-backend:latest .
echo -e "${GREEN}✓ Backend image built${NC}"

# Run backend container
docker run -d \
    --name $CONTAINER_BACKEND \
    --network $NETWORK_NAME \
    -e DATABASE_URL=$DATABASE_URL \
    -e PORT=$PORT \
    -e NODE_ENV=$NODE_ENV \
    -e FRONTEND_URL=$FRONTEND_URL \
    --restart unless-stopped \
    bmi-backend:latest

echo -e "${GREEN}✓ Backend container started${NC}"

# Wait for backend to be ready
echo ""
echo "Waiting for backend to be ready..."
sleep 5

# Check backend health
MAX_RETRIES=15
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if docker exec $CONTAINER_BACKEND wget -q -O- http://localhost:3000/health >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Backend is healthy!${NC}"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Attempt $RETRY_COUNT/$MAX_RETRIES - waiting..."
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${YELLOW}Warning: Could not verify backend health endpoint${NC}"
    echo "Check logs: docker logs $CONTAINER_BACKEND"
fi

#############################################
# STEP 4: Build and Start Frontend Web
#############################################
echo ""
echo "[STEP 4/4] Building and starting Frontend..."

# Build frontend image
cd "$PROJECT_ROOT/frontend"
docker build -t bmi-frontend:latest .
echo -e "${GREEN}✓ Frontend image built${NC}"

# Run frontend container
docker run -d \
    --name $CONTAINER_FRONTEND \
    --network $NETWORK_NAME \
    -p 80:80 \
    --restart unless-stopped \
    bmi-frontend:latest

echo -e "${GREEN}✓ Frontend container started${NC}"

#############################################
# Deployment Complete
#############################################
echo ""
echo "=========================================="
echo -e "${GREEN}Deployment Complete!${NC}"
echo "=========================================="
echo ""
echo "Container Status:"
docker ps --filter "name=$CONTAINER_DB|$CONTAINER_BACKEND|$CONTAINER_FRONTEND" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "Application URLs:"
echo "  - Frontend: http://localhost (or http://<EC2-PUBLIC-IP>)"
echo "  - Backend Health: http://localhost/health"
echo ""
echo "Useful Commands:"
echo "  - View logs: ./logs.sh"
echo "  - Stop containers: ./stop-containers.sh"
echo "  - Restart containers: ./restart-containers.sh"
echo "  - Backup database: ./backup-database.sh"
echo ""
echo "For HTTPS setup with ELB and ACM, see: HTTPS_SETUP.md"
echo ""
