#!/bin/bash

DB_DRIVER="${YOTSUBA_DB_DRIVER:-mysql}"
MIGRATIONS_DIR="/var/www/html/docker/migrations"

echo "[migrations] Checking for pending migrations ($DB_DRIVER)..."

if [ "$DB_DRIVER" = "pgsql" ]; then
    PG_HOST="${YOTSUBA_PG_HOST:-pgdb}"
    PG_PORT="${YOTSUBA_PG_PORT:-5432}"
    PG_USER="${YOTSUBA_PG_USER:-yotsuba}"
    PG_PASS="${YOTSUBA_PG_PASS:-yotsuba}"
    PG_NAME="${YOTSUBA_PG_NAME:-yotsuba_dev}"
    export PGPASSWORD="$PG_PASS"
    psql_cmd="psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_NAME -q"

    if ! $psql_cmd -c "SELECT 1" >/dev/null 2>&1; then
        echo "[migrations] Cannot connect to PostgreSQL, skipping."
        exit 0
    fi

    $psql_cmd -c "CREATE TABLE IF NOT EXISTS schema_migrations (version VARCHAR(255) PRIMARY KEY, applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)" 2>/dev/null || true

    applied=0
    skipped=0

    for migration in "$MIGRATIONS_DIR"/*.sql; do
        [ -f "$migration" ] || continue
        version=$(basename "$migration")

        already_run=$($psql_cmd -t -A -c "SELECT COUNT(*) FROM schema_migrations WHERE version='$version'" 2>/dev/null || echo "0")
        already_run=$(echo "$already_run" | tr -d '[:space:]')

        if [ "$already_run" = "0" ]; then
            echo "[migrations] Applying: $version"
            if $psql_cmd -f "$migration" 2>/dev/null; then
                $psql_cmd -c "INSERT INTO schema_migrations (version) VALUES ('$version')" 2>/dev/null || true
                applied=$((applied + 1))
            else
                echo "[migrations] FAILED: $version"
            fi
        else
            skipped=$((skipped + 1))
        fi
    done

    echo "[migrations] Done: $applied applied, $skipped skipped"
else
    DB_HOST="${YOTSUBA_DB_HOST:-db}"
    DB_USER="${YOTSUBA_DB_USER:-yotsuba}"
    DB_PASS="${YOTSUBA_DB_PASS:-yotsuba}"
    DB_NAME="${YOTSUBA_DB_NAME:-yotsuba_global}"

    mysql_cmd="mysql --skip-ssl -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME"

    if ! $mysql_cmd -e "SELECT 1" >/dev/null 2>&1; then
        echo "[migrations] Cannot connect to database, skipping."
        exit 0
    fi

    $mysql_cmd < "$MIGRATIONS_DIR/001_create_migrations_table.sql" 2>/dev/null || true

    applied=0
    skipped=0

    for migration in "$MIGRATIONS_DIR"/*.sql; do
        [ -f "$migration" ] || continue
        version=$(basename "$migration")

        already_run=$($mysql_cmd -N -e "SELECT COUNT(*) FROM schema_migrations WHERE version='$version'" 2>/dev/null || echo "0")

        if [ "$already_run" = "0" ]; then
            echo "[migrations] Applying: $version"
            if $mysql_cmd < "$migration" 2>/dev/null; then
                $mysql_cmd -e "INSERT INTO schema_migrations (version) VALUES ('$version')" 2>/dev/null || true
                applied=$((applied + 1))
            else
                echo "[migrations] FAILED: $version"
            fi
        else
            skipped=$((skipped + 1))
        fi
    done

    echo "[migrations] Done: $applied applied, $skipped skipped"
fi
