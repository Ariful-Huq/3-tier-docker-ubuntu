#!/bin/bash

#############################################
# View Container Logs
# Shows logs for all containers
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
echo "Container Logs"
echo "=========================================="
echo ""
echo "Available containers:"
echo "  1) Database ($CONTAINER_DB)"
echo "  2) Backend ($CONTAINER_BACKEND)"
echo "  3) Frontend ($CONTAINER_FRONTEND)"
echo "  4) All containers"
echo ""
read -p "Select (1-4): " choice

case $choice in
    1)
        echo ""
        echo "=== Database Logs ==="
        docker logs --tail 100 -f $CONTAINER_DB
        ;;
    2)
        echo ""
        echo "=== Backend Logs ==="
        docker logs --tail 100 -f $CONTAINER_BACKEND
        ;;
    3)
        echo ""
        echo "=== Frontend Logs ==="
        docker logs --tail 100 -f $CONTAINER_FRONTEND
        ;;
    4)
        echo ""
        echo "=== Database Logs (last 50 lines) ==="
        docker logs --tail 50 $CONTAINER_DB
        echo ""
        echo "=== Backend Logs (last 50 lines) ==="
        docker logs --tail 50 $CONTAINER_BACKEND
        echo ""
        echo "=== Frontend Logs (last 50 lines) ==="
        docker logs --tail 50 $CONTAINER_FRONTEND
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac
