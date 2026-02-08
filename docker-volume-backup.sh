#!/bin/bash
# docker-volume-backup.sh - Run this inside each LXC container with Docker
# This creates backups of all Docker volumes

set -e

BACKUP_DIR="/tmp/docker-volume-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "🐳 Backing up Docker volumes..."
echo "Backup directory: $BACKUP_DIR"

# Get all volumes
volumes=$(docker volume ls -q)

for volume in $volumes; do
    echo "  - Backing up volume: $volume"
    docker run --rm \
        -v "$volume":/source:ro \
        -v "$BACKUP_DIR":/backup \
        alpine:latest \
        tar czf "/backup/${volume}.tar.gz" -C /source .
done

echo ""
echo "✅ Backup complete!"
echo "Volumes backed up to: $BACKUP_DIR"
echo ""
echo "To transfer to new machine:"
echo "  scp -r $BACKUP_DIR user@new-ubuntu-machine:/tmp/"
