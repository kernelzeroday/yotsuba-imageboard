#!/bin/bash
# Migrate data from MySQL to PostgreSQL (consolidated schema)
# All board tables → single "posts" table
#
# Usage: Run from host or on d.local directly
#   ./docker/migrate-mysql-to-pg.sh              # dev (default)
#   ./docker/migrate-mysql-to-pg.sh --prod       # prod

set -uo pipefail

if [ "${1:-}" = "--prod" ]; then
    MYSQL_CONTAINER="yotsuba-db"
    PG_CONTAINER="yotsuba-pgdb"
    PG_DB="yotsuba"
    echo "=== PROD Migration: MySQL → PostgreSQL ==="
else
    MYSQL_CONTAINER="yotsuba-db"
    PG_CONTAINER="yotsuba-dev-pgdb"
    PG_DB="yotsuba_dev"
    echo "=== DEV Migration: MySQL → PostgreSQL ==="
fi

MYSQL_USER="yotsuba"
MYSQL_PASS="yotsuba"
MYSQL_DB="yotsuba_global"

PG_USER="yotsuba"

DUMP_DIR="/tmp/yotsuba-migrate"

echo "=== Yotsuba MySQL → PostgreSQL Data Migration ==="
echo "    (consolidated schema: per-board tables → single posts table)"
echo ""

mkdir -p "$DUMP_DIR"

# Step 1: Get list of all tables from prod MySQL
echo "[1/6] Getting table list from prod MySQL..."
TABLES=$(docker exec "$MYSQL_CONTAINER" mysql --skip-ssl -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" -BNe \
    "SELECT table_name FROM information_schema.tables WHERE table_schema='$MYSQL_DB' AND table_type='BASE TABLE' ORDER BY table_name" 2>/dev/null)

echo "  Found $(echo "$TABLES" | wc -l | tr -d ' ') tables"

# Step 2: Classify tables
echo ""
echo "[2/6] Classifying tables..."

BOARD_TABLES=""
SYSTEM_TABLES=""
SKIP_TABLES="schema_migrations"

for tbl in $TABLES; do
    if echo "$SKIP_TABLES" | grep -qw "$tbl"; then
        echo "  SKIP: $tbl (migration tracking)"
        continue
    fi

    if echo "$tbl" | grep -q '_md5$'; then
        echo "  SKIP: $tbl (md5 lookup)"
        continue
    fi

    has_no=$(docker exec "$MYSQL_CONTAINER" mysql --skip-ssl -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" -BNe \
        "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='$MYSQL_DB' AND table_name='$tbl' AND column_name='no'" 2>/dev/null || echo "0")

    has_resto=$(docker exec "$MYSQL_CONTAINER" mysql --skip-ssl -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" -BNe \
        "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='$MYSQL_DB' AND table_name='$tbl' AND column_name='resto'" 2>/dev/null || echo "0")

    if [ "$has_no" -gt 0 ] && [ "$has_resto" -gt 0 ]; then
        BOARD_TABLES="$BOARD_TABLES $tbl"
    else
        SYSTEM_TABLES="$SYSTEM_TABLES $tbl"
    fi
done

echo "  Board tables: $(echo $BOARD_TABLES | wc -w | tr -d ' ')"
echo "  System tables: $(echo $SYSTEM_TABLES | wc -w | tr -d ' ')"

# Step 3: Reset PG database
echo ""
echo "[3/6] Resetting PostgreSQL schema..."
docker exec "$PG_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" -c "
    DO \$\$ DECLARE r RECORD;
    BEGIN
        FOR r IN (SELECT viewname FROM pg_views WHERE schemaname = 'public') LOOP
            EXECUTE 'DROP VIEW IF EXISTS \"' || r.viewname || '\" CASCADE';
        END LOOP;
        FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
            EXECUTE 'DROP TABLE IF EXISTS \"' || r.tablename || '\" CASCADE';
        END LOOP;
    END \$\$;
" > /dev/null 2>&1 || true

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/init_pg.sql" ]; then
    docker cp "$SCRIPT_DIR/init_pg.sql" "$PG_CONTAINER":/tmp/init_pg.sql
elif [ -f "/tmp/init_pg.sql" ]; then
    docker cp "/tmp/init_pg.sql" "$PG_CONTAINER":/tmp/init_pg.sql
else
    echo "ERROR: init_pg.sql not found"; exit 1
fi
docker exec "$PG_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" -f /tmp/init_pg.sql > /dev/null 2>&1
echo "  Schema loaded (consolidated posts table + board views)"

# Step 4: Migrate system tables
echo ""
echo "[4/6] Migrating system tables..."

for tbl in $SYSTEM_TABLES; do
    count=$(docker exec "$MYSQL_CONTAINER" mysql --skip-ssl -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" -BNe \
        "SELECT COUNT(*) FROM \`$tbl\`" 2>/dev/null || echo "0")

    if [ "$count" -eq 0 ]; then
        continue
    fi

    pg_exists=$(docker exec "$PG_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" -tAc \
        "SELECT COUNT(*) FROM pg_tables WHERE schemaname='public' AND tablename='$tbl'" 2>/dev/null || echo "0")

    if [ "$pg_exists" -eq 0 ]; then
        echo "  SKIP: $tbl (no PG table)"
        continue
    fi

    # Get MySQL columns
    mysql_cols=$(docker exec "$MYSQL_CONTAINER" mysql --skip-ssl -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" -BNe \
        "SELECT GROUP_CONCAT(column_name ORDER BY ordinal_position) FROM information_schema.columns WHERE table_schema='$MYSQL_DB' AND table_name='$tbl'" 2>/dev/null)

    # Get PG columns
    pg_cols=$(docker exec "$PG_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" -tAc \
        "SELECT string_agg(column_name, ',' ORDER BY ordinal_position) FROM information_schema.columns WHERE table_schema='public' AND table_name='$tbl'" 2>/dev/null)

    # Find common columns
    common_cols=""
    IFS=',' read -ra mysql_arr <<< "$mysql_cols"
    for col in "${mysql_arr[@]}"; do
        if echo ",$pg_cols," | grep -q ",$col,"; then
            if [ -z "$common_cols" ]; then
                common_cols="$col"
            else
                common_cols="$common_cols,$col"
            fi
        fi
    done

    if [ -z "$common_cols" ]; then
        echo "  SKIP: $tbl (no common columns)"
        continue
    fi

    mysql_select=$(echo "$common_cols" | sed 's/,/`,`/g; s/^/`/; s/$/`/')
    pg_col_list=$(echo "$common_cols" | sed 's/,/","/g; s/^/"/; s/$/"/')

    docker exec "$MYSQL_CONTAINER" mysql --skip-ssl -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" -BNe \
        "SELECT $mysql_select FROM \`$tbl\`" 2>/dev/null | iconv -f WINDOWS-1252 -t UTF-8//TRANSLIT 2>/dev/null > "$DUMP_DIR/${tbl}.tsv" || true

    if [ ! -s "$DUMP_DIR/${tbl}.tsv" ]; then
        continue
    fi

    docker exec "$PG_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" -c "DELETE FROM \"$tbl\"" > /dev/null 2>&1 || true
    docker cp "$DUMP_DIR/${tbl}.tsv" "$PG_CONTAINER":/tmp/load.tsv
    docker exec "$PG_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" -c \
        "\\COPY \"$tbl\" ($pg_col_list) FROM '/tmp/load.tsv' WITH (FORMAT text, NULL '\\N')" > /dev/null 2>&1 && \
        echo "  $tbl: $count rows" || \
        echo "  FAIL: $tbl (column mismatch)"

    docker exec "$PG_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" -c \
        "SELECT setval(pg_get_serial_sequence('\"$tbl\"', 'id'), COALESCE((SELECT MAX(id) FROM \"$tbl\"), 0) + 1, false)" > /dev/null 2>&1 || true
done

# Step 5: Migrate board tables → consolidated posts table
echo ""
echo "[5/6] Migrating board tables → posts..."

# PG posts columns (minus board, which we prepend)
PG_POST_COLS="no,resto,root,now,time,last_modified,name,sub,com,host,pwd,4pass_id,email,filename,ext,w,h,tn_w,tn_h,tim,md5,tmd5,fsize,filedeleted,id,capcode,country,sticky,permasage,permaage,closed,archived,undead,since4pass,m_img,board_flag,source_filename,source_ext,source_fsize,upvotes,downvotes"

total_board_rows=0
migrated_boards=0
failed_boards=0

for tbl in $BOARD_TABLES; do
    count=$(docker exec "$MYSQL_CONTAINER" mysql --skip-ssl -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" -BNe \
        "SELECT COUNT(*) FROM \`$tbl\`" 2>/dev/null || echo "0")

    if [ "$count" -eq 0 ]; then
        continue
    fi

    # Get MySQL columns for this board table
    mysql_cols=$(docker exec "$MYSQL_CONTAINER" mysql --skip-ssl -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" -BNe \
        "SELECT GROUP_CONCAT(column_name ORDER BY ordinal_position) FROM information_schema.columns WHERE table_schema='$MYSQL_DB' AND table_name='$tbl'" 2>/dev/null)

    # Find common columns with PG posts schema (excluding board, clip_nsfw, clip_desc)
    common_cols=""
    IFS=',' read -ra mysql_arr <<< "$mysql_cols"
    IFS=',' read -ra pg_arr <<< "$PG_POST_COLS"
    for col in "${mysql_arr[@]}"; do
        for pg_col in "${pg_arr[@]}"; do
            if [ "$col" = "$pg_col" ]; then
                if [ -z "$common_cols" ]; then
                    common_cols="$col"
                else
                    common_cols="$common_cols,$col"
                fi
                break
            fi
        done
    done

    if [ -z "$common_cols" ]; then
        echo "  SKIP: $tbl (no common columns)"
        continue
    fi

    mysql_select=$(echo "$common_cols" | sed 's/,/`,`/g; s/^/`/; s/$/`/')

    # Dump MySQL board data, prepending board name as first column
    docker exec "$MYSQL_CONTAINER" mysql --skip-ssl -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" -BNe \
        "SELECT '$tbl' AS board, $mysql_select FROM \`$tbl\`" 2>/dev/null | iconv -f WINDOWS-1252 -t UTF-8//TRANSLIT 2>/dev/null > "$DUMP_DIR/${tbl}.tsv" || true

    if [ ! -s "$DUMP_DIR/${tbl}.tsv" ]; then
        continue
    fi

    # Build PG column list: board + common columns
    pg_col_list="\"board\",$(echo "$common_cols" | sed 's/,/","/g; s/^/"/; s/$/"/')"

    docker cp "$DUMP_DIR/${tbl}.tsv" "$PG_CONTAINER":/tmp/load.tsv
    if docker exec "$PG_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" -c \
        "\\COPY \"posts\" ($pg_col_list) FROM '/tmp/load.tsv' WITH (FORMAT text, NULL '\\N')" > /dev/null 2>&1; then
        source_count=$(docker exec "$MYSQL_CONTAINER" mysql --skip-ssl -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" -BNe \
            "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='$MYSQL_DB' AND table_name='$tbl' AND column_name='source_data'" 2>/dev/null || echo "0")
        if [ "$source_count" -gt 0 ]; then
            docker exec "$MYSQL_CONTAINER" mysql --skip-ssl -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" -BNe \
                "SELECT no, HEX(source_data) FROM \`$tbl\` WHERE source_data IS NOT NULL" \
                > "$DUMP_DIR/${tbl}_source.tsv" 2>/dev/null || true
            if [ -s "$DUMP_DIR/${tbl}_source.tsv" ]; then
                docker cp "$DUMP_DIR/${tbl}_source.tsv" "$PG_CONTAINER":/tmp/source.tsv
                docker exec "$PG_CONTAINER" chmod 0644 /tmp/source.tsv
                docker exec "$PG_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" -v ON_ERROR_STOP=1 -c "
                    CREATE TEMP TABLE source_import (no INTEGER, data TEXT);
                    COPY source_import FROM '/tmp/source.tsv' WITH (FORMAT text, DELIMITER E'\\t');
                    UPDATE posts AS p
                    SET source_data = decode(s.data, 'hex')
                    FROM source_import AS s
                    WHERE p.board = '$tbl' AND p.no = s.no;
                " > /dev/null 2>&1 || echo "  WARN: /$tbl/ source attachment data failed"
            fi
        fi
        echo "  /$tbl/: $count rows"
        total_board_rows=$((total_board_rows + count))
        migrated_boards=$((migrated_boards + 1))
    else
        echo "  FAIL: /$tbl/ ($count rows)"
        failed_boards=$((failed_boards + 1))
    fi
done

echo ""
echo "  Boards migrated: $migrated_boards, failed: $failed_boards, total rows: $total_board_rows"

# Update board_sequences from migrated data
echo ""
echo "  Syncing per-board sequences..."
docker exec "$PG_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" -c "
    INSERT INTO board_sequences (board, current_no)
    SELECT board, COALESCE(MAX(\"no\"), 0)
    FROM posts
    GROUP BY board
    ON CONFLICT (board) DO UPDATE SET current_no = EXCLUDED.current_no;
" > /dev/null 2>&1

# Step 6: Verify
echo ""
echo "[6/6] Verification..."

pg_tables=$(docker exec "$PG_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" -tAc \
    "SELECT COUNT(*) FROM pg_tables WHERE schemaname='public'")
pg_views=$(docker exec "$PG_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" -tAc \
    "SELECT COUNT(*) FROM pg_views WHERE schemaname='public'")
pg_post_count=$(docker exec "$PG_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" -tAc \
    "SELECT COUNT(*) FROM posts")
pg_boards=$(docker exec "$PG_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" -tAc \
    "SELECT COUNT(DISTINCT board) FROM posts")

echo "  PG tables: $pg_tables (system) + 1 posts table"
echo "  PG views: $pg_views (board views)"
echo "  Posts: $pg_post_count across $pg_boards boards"
echo ""

echo "  Top boards by post count:"
docker exec "$PG_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" -c \
    "SELECT board, COUNT(*) AS posts FROM posts GROUP BY board ORDER BY posts DESC LIMIT 15"

echo ""
echo "  System tables:"
docker exec "$PG_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" -c \
    "SELECT relname AS table, n_live_tup AS rows FROM pg_stat_user_tables WHERE n_live_tup > 0 AND relname != 'posts' ORDER BY n_live_tup DESC LIMIT 10"

# Cleanup
rm -rf "$DUMP_DIR"

echo ""
echo "=== Migration complete ==="
echo ""
echo "Schema: 82 MySQL board tables → 1 PG posts table + ${pg_views} board views"
echo "Board views provide transparent compatibility (SELECT/INSERT/UPDATE/DELETE)"
