#!/bin/bash

#############################################
# Backup Database
# Creates timestamped SQL dump
#############################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
else
    echo "Error: .env file not found!"
    exit 1
fi

# Create backup directory
BACKUP_DIR="$SCRIPT_DIR/backups"
mkdir -p "$BACKUP_DIR"

# Generate timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/bmi_health_db_backup_$TIMESTAMP.sql"

echo "=========================================="
echo "Database Backup"
echo "=========================================="
echo ""
echo "Backing up database: $POSTGRES_DB"
echo "Container: $CONTAINER_DB"
echo "Output file: $BACKUP_FILE"
echo ""

# Check if container is running
if ! docker ps | grep -q $CONTAINER_DB; then
    echo "Error: Database container is not running!"
    exit 1
fi

# Create backup using pg_dump
docker exec $CONTAINER_DB pg_dump -U $POSTGRES_USER -d $POSTGRES_DB > "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "✓ Backup completed successfully!"
    echo ""
    echo "Backup file: $BACKUP_FILE"
    echo "File size: $(du -h "$BACKUP_FILE" | cut -f1)"
    echo ""
    echo "To restore this backup:"
    echo "  docker exec -i $CONTAINER_DB psql -U $POSTGRES_USER -d $POSTGRES_DB < $BACKUP_FILE"
    echo ""
else
    echo "✗ Backup failed!"
    exit 1
fi
