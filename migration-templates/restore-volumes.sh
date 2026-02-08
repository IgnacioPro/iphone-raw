#!/bin/bash
# restore-volumes.sh - Run on new Ubuntu machine to restore Docker volumes
# Usage: ./restore-volumes.sh /path/to/backup/directory

set -e

BACKUP_DIR="${1:-/tmp/docker-volume-backup}"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "Error: Backup directory $BACKUP_DIR not found"
    echo "Usage: $0 /path/to/backup/directory"
    exit 1
fi

echo "🔄 Restoring Docker volumes from $BACKUP_DIR"

cd "$BACKUP_DIR"

for backup in *.tar.gz; do
    if [ -f "$backup" ]; then
        volume_name=$(basename "$backup" .tar.gz)
        echo "  - Restoring volume: $volume_name"
        
        # Create volume if it doesn't exist
        docker volume create "$volume_name" 2>/dev/null || true
        
        # Extract backup into volume
        docker run --rm \
            -v "$volume_name":/target \
            -v "$BACKUP_DIR":/backup \
            alpine:latest \
            tar xzf "/backup/$backup" -C /target
    fi
done

echo ""
echo "✅ Volume restoration complete!"
