#!/bin/bash
# Host-side PostgreSQL backup with atomic writes and integrity verification.
#
# Usage:
#   ./backup-db.sh [--prod|--dev]
#   ./backup-db.sh [--prod|--dev] --watch

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/docker/backups"
ENVIRONMENT="prod"
WATCH=0
MAX_KEEP=24

for arg in "$@"; do
    case "$arg" in
        --prod) ENVIRONMENT="prod" ;;
        --dev) ENVIRONMENT="dev" ;;
        --watch) WATCH=1 ;;
        *)
            echo "Usage: $0 [--prod|--dev] [--watch]" >&2
            exit 2
            ;;
    esac
done

if [ "$ENVIRONMENT" = "prod" ]; then
    DB_CONTAINER="yotsuba-prod-pgdb"
    DB_NAME="yotsuba"
else
    DB_CONTAINER="yotsuba-dev-pgdb"
    DB_NAME="yotsuba_dev"
fi

mkdir -p "$BACKUP_DIR"

do_backup() {
    local label="$1"
    local timestamp
    local final_path
    local temp_path
    local size
    local old_backup
    local -a old_backups

    timestamp=$(date '+%Y%m%d_%H%M%S')
    final_path="$BACKUP_DIR/${ENVIRONMENT}_${label}_${timestamp}.sql.gz"
    temp_path=$(mktemp "$BACKUP_DIR/.${ENVIRONMENT}_${label}_${timestamp}.tmp.XXXXXX")

    if ! docker exec "$DB_CONTAINER" pg_isready -U yotsuba -d "$DB_NAME" >/dev/null 2>&1; then
        echo "[backup] $DB_CONTAINER is unavailable or unhealthy" >&2
        rm -f "$temp_path"
        return 1
    fi

    echo "[backup] Dumping $ENVIRONMENT database to $(basename "$final_path") ..."
    if ! docker exec "$DB_CONTAINER" pg_dump \
        --username=yotsuba \
        --dbname="$DB_NAME" \
        --format=plain \
        --no-owner \
        --no-privileges | gzip -9 > "$temp_path"; then
        echo "[backup] pg_dump failed; no backup was saved" >&2
        rm -f "$temp_path"
        return 1
    fi

    if ! gzip -t "$temp_path"; then
        echo "[backup] gzip verification failed; no backup was saved" >&2
        rm -f "$temp_path"
        return 1
    fi

    size=$(wc -c < "$temp_path" | tr -d '[:space:]')
    if [ "$size" -lt 1024 ]; then
        echo "[backup] dump is unexpectedly small ($size bytes); no backup was saved" >&2
        rm -f "$temp_path"
        return 1
    fi

    mv "$temp_path" "$final_path"
    echo "[backup] Complete: $(basename "$final_path") ($size bytes)"

    old_backups=()
    while IFS= read -r old_backup; do
        old_backups+=("$old_backup")
    done < <(
        find "$BACKUP_DIR" -maxdepth 1 -type f \
            -name "${ENVIRONMENT}_${label}_*.sql.gz" -print | sort -r
    )
    if [ "${#old_backups[@]}" -gt "$MAX_KEEP" ]; then
        for old_backup in "${old_backups[@]:$MAX_KEEP}"; do
            echo "[backup] Rotating $(basename "$old_backup")"
            rm -f -- "$old_backup"
        done
    fi
}

if [ "$WATCH" -eq 1 ]; then
    echo "[backup] Starting hourly $ENVIRONMENT backups (keeping $MAX_KEEP)"
    while true; do
        do_backup "hourly"
        sleep 3600
    done
else
    do_backup "manual"
fi
