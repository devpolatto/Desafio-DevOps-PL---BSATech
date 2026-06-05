#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

BACKUP_FILE="${1:-}"

if [ -z "$BACKUP_FILE" ]; then
    echo "ERROR: backup file required." >&2
    echo "Usage: $0 <backup-file.sql.gz>" >&2
    echo "Example: $0 backups/backup-2026-06-05-103000.sql.gz" >&2
    exit 1
fi

# Resolve relative paths from project root
if [[ "$BACKUP_FILE" != /* ]]; then
    BACKUP_FILE="$PROJECT_ROOT/$BACKUP_FILE"
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "ERROR: file not found: $BACKUP_FILE" >&2
    exit 1
fi

echo "Restoring from: $BACKUP_FILE"
echo "Target database: $MYSQL_DATABASE"
echo ""

gunzip -c "$BACKUP_FILE" | docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T mysql \
    mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"

echo "Restore complete."
