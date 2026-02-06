#!/bin/bash

#############################################
# Stop All Containers
# Preserves data volume
#############################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
else
    echo "Error: .env file not found!"
    exit 1
fi

echo "Stopping containers..."

docker stop $CONTAINER_FRONTEND 2>/dev/null || echo "Frontend already stopped"
docker stop $CONTAINER_BACKEND 2>/dev/null || echo "Backend already stopped"
docker stop $CONTAINER_DB 2>/dev/null || echo "Database already stopped"

echo ""
echo "Removing containers..."

docker rm $CONTAINER_FRONTEND 2>/dev/null || echo "Frontend already removed"
docker rm $CONTAINER_BACKEND 2>/dev/null || echo "Backend already removed"
docker rm $CONTAINER_DB 2>/dev/null || echo "Database already removed"

echo ""
echo "Containers stopped and removed."
echo "Data volume preserved: $VOLUME_NAME"
echo ""
echo "To start again: ./deploy-docker.sh"
echo "To remove volume (DELETE DATA): docker volume rm $VOLUME_NAME"
echo ""
