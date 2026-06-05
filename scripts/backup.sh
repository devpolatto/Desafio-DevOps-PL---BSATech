#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
BACKUP_DIR="$PROJECT_ROOT/backups"
BACKUP_FILE="$BACKUP_DIR/backup-$TIMESTAMP.sql.gz"

mkdir -p "$BACKUP_DIR"

echo "Starting backup..."

if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T mysql \
    mysqldump -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
    | gzip > "$BACKUP_FILE"; then
    echo "Backup created: $BACKUP_FILE"
else
    rm -f "$BACKUP_FILE"
    echo "ERROR: Backup failed" >&2
    exit 1
fi
