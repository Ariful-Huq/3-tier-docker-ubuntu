#!/bin/bash

#############################################
# Cleanup All Resources
# WARNING: This removes everything including data!
#############################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
else
    echo "Error: .env file not found!"
    exit 1
fi

echo "=========================================="
echo "⚠️  WARNING: Complete Cleanup ⚠️"
echo "=========================================="
echo ""
echo "This will remove:"
echo "  - All containers"
echo "  - All images"
echo "  - Network: $NETWORK_NAME"
echo "  - Volume: $VOLUME_NAME (ALL DATA WILL BE LOST!)"
echo ""
read -p "Are you sure? Type 'yes' to continue: " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "Stopping and removing containers..."
docker stop $CONTAINER_FRONTEND $CONTAINER_BACKEND $CONTAINER_DB 2>/dev/null || true
docker rm $CONTAINER_FRONTEND $CONTAINER_BACKEND $CONTAINER_DB 2>/dev/null || true

echo "Removing images..."
docker rmi bmi-frontend:latest bmi-backend:latest 2>/dev/null || true

echo "Removing network..."
docker network rm $NETWORK_NAME 2>/dev/null || true

echo "Removing volume (deleting all data)..."
docker volume rm $VOLUME_NAME 2>/dev/null || true

echo ""
echo "✓ Cleanup complete!"
echo ""
echo "To redeploy: ./deploy-docker.sh"
echo "-----------"
