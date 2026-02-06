#!/bin/bash

#############################################
# Restart All Containers
# Uses existing images and data
#############################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Restarting containers..."

# Stop first
$SCRIPT_DIR/stop-containers.sh

echo ""
echo "Starting containers with existing data..."

# Start with existing images
$SCRIPT_DIR/deploy-docker.sh

echo ""
echo "Restart complete!"
echo ""
