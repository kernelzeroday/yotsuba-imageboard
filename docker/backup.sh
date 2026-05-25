#!/bin/bash
# ---------------------------------------------------------------------------
# Yotsuba database backup utility
#
# Usage:
#   backup.sh dump [label]    — one-off dump with optional label
#   backup.sh periodic        — run hourly dumps in a loop, keep last 24
#   backup.sh shutdown        — shutdown dump (called from SIGTERM trap)
#   backup.sh pre-rebuild     — pre-rebuild safety dump
#
# All dumps go to /www/backups/ which should be bind-mounted to the host.
# ---------------------------------------------------------------------------

BACKUP_DIR="/www/backups"
DB_DRIVER="${YOTSUBA_DB_DRIVER:-mysql}"
DB_HOST="${YOTSUBA_DB_HOST:-db}"
DB_USER="${YOTSUBA_DB_USER:-yotsuba}"
DB_PASS="${YOTSUBA_DB_PASS:-yotsuba}"
DB_NAME="${YOTSUBA_DB_NAME:-yotsuba_global}"
PG_HOST="${YOTSUBA_PG_HOST:-pgdb}"
PG_PORT="${YOTSUBA_PG_PORT:-5432}"
PG_USER="${YOTSUBA_PG_USER:-yotsuba}"
PG_PASS="${YOTSUBA_PG_PASS:-yotsuba}"
PG_NAME="${YOTSUBA_PG_NAME:-yotsuba_dev}"
MAX_HOURLY=3

mkdir -p "$BACKUP_DIR"

log() {
    echo "[backup] $(date '+%Y-%m-%d %H:%M:%S') $*"
}

db_has_data() {
    local count
    if [ "$DB_DRIVER" = "pgsql" ]; then
        count=$(PGPASSWORD="$PG_PASS" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_NAME" \
            -tAc "SELECT COUNT(*) FROM pg_tables WHERE schemaname='public'" 2>/dev/null)
    else
        count=$(mysql --skip-ssl -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" \
            -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NAME'" 2>/dev/null)
    fi
    [ -n "$count" ] && [ "$count" -gt 0 ]
}

# Perform a mysqldump with a given filename prefix
do_dump() {
    local prefix="$1"
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local filename="${prefix}_${timestamp}.sql.gz"
    local filepath="${BACKUP_DIR}/${filename}"

    if ! db_has_data; then
        log "Database empty or unreachable, skipping dump"
        return 1
    fi

    log "Dumping $DB_NAME to $filepath ..."

    # Use a temp file to avoid corrupting existing backups on failure
    local tmpfile="${filepath}.tmp"

    if [ "$DB_DRIVER" = "pgsql" ]; then
        PGPASSWORD="$PG_PASS" pg_dump -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" "$PG_NAME" | gzip > "$tmpfile"
    else
        /usr/local/bin/backup-dump.sh "$DB_HOST" root rootpass "$DB_NAME" | gzip > "$tmpfile"
    fi

    local size
    size=$(stat -c%s "$tmpfile" 2>/dev/null || stat -f%z "$tmpfile" 2>/dev/null)

    # Minimum viable backup size: schema + data for our DB should be > 100KB
    local MIN_SIZE=50000
    if [ -z "$size" ] || [ "$size" -lt "$MIN_SIZE" ]; then
        log "ERROR: Dump too small ($size bytes < $MIN_SIZE) — likely mysqldump version mismatch. NOT saving."
        rm -f "$tmpfile"
        return 1
    fi

    # Don't overwrite latest if new dump is significantly smaller (>50% shrinkage = data loss)
    local latest_link="${BACKUP_DIR}/${prefix}_latest.sql.gz"
    if [ -L "$latest_link" ] && [ -f "$latest_link" ]; then
        local prev_size
        prev_size=$(stat -c%s "$latest_link" 2>/dev/null || stat -f%z "$latest_link" 2>/dev/null)
        if [ -n "$prev_size" ] && [ "$prev_size" -gt 0 ]; then
            local half_prev=$((prev_size / 2))
            if [ "$size" -lt "$half_prev" ]; then
                log "ERROR: New dump ($size) is less than half of previous ($prev_size) — possible data loss. NOT saving."
                rm -f "$tmpfile"
                return 1
            fi
        fi
    fi

    mv "$tmpfile" "$filepath"
    log "Backup complete: $filename ($size bytes)"
    ln -sf "$filename" "$latest_link"
    return 0
}

# Rotate old hourly backups, keep only MAX_HOURLY most recent
rotate_hourly() {
    local count
    count=$(ls -1 "$BACKUP_DIR"/hourly_*.sql.gz 2>/dev/null | wc -l)
    if [ "$count" -gt "$MAX_HOURLY" ]; then
        local to_remove=$((count - MAX_HOURLY))
        ls -1t "$BACKUP_DIR"/hourly_*.sql.gz | tail -n "$to_remove" | while read -r f; do
            log "Rotating old backup: $(basename "$f")"
            rm -f "$f"
        done
    fi
}

case "${1:-dump}" in
    dump)
        label="${2:-manual}"
        do_dump "$label"
        ;;

    shutdown)
        log "=== SHUTDOWN BACKUP ==="
        do_dump "shutdown"
        log "Shutdown backup complete. Data is safe on host filesystem."
        ;;

    pre-rebuild)
        log "=== PRE-REBUILD SAFETY BACKUP ==="
        do_dump "pre-rebuild"
        ;;

    periodic)
        log "Starting periodic backup loop (every 3600s, keeping last $MAX_HOURLY)"
        while true; do
            sleep 3600
            do_dump "hourly"
            rotate_hourly
        done
        ;;

    *)
        echo "Usage: $0 {dump [label]|periodic|shutdown|pre-rebuild}"
        exit 1
        ;;
esac
