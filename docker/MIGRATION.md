# Yotsuba MySQL-to-PostgreSQL Production Migration Guide

This guide covers migrating the production Yotsuba instance from MariaDB 10.1 to PostgreSQL 16.

**Current state:** The DBAL migration is complete. All 758 `mysql_*_call()` sites have been
replaced with `YotsubaDB` DBAL calls using prepared statements (`lib/dbal.php`). The dev
environment has been tested on both MySQL and PostgreSQL. Switching backends is controlled by
the `YOTSUBA_DB_DRIVER` env var.

---

## 1. Pre-Migration Checklist

Before touching anything, verify all of the following:

```bash
# Confirm you are working with the CORRECT containers
# PROD: yotsuba-web + yotsuba-db (port 8082)
# DEV:  yotsuba-dev-web + yotsuba-dev-db + yotsuba-dev-pgdb (port 8084)
docker ps --format '{{.Names}}\t{{.Ports}}' | grep yotsuba
```

- [ ] **Dev PG backend works end-to-end.** Switch dev to `YOTSUBA_DB_DRIVER=pgsql` and run the
      test harness:
      ```bash
      # In docker-compose.dev.yml, set YOTSUBA_DB_DRIVER=pgsql, then:
      docker compose -f docker-compose.dev.yml up --build -d
      bash docker/test-dual-db.sh
      ```
      All tests must pass. Fix any failures before proceeding.

- [ ] **PG schema matches MySQL.** Compare table counts:
      ```bash
      # MySQL table count (prod)
      docker exec yotsuba-db mysql --skip-ssl -u root -prootpass yotsuba_global \
        -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='yotsuba_global'"

      # PG table count (dev)
      docker exec yotsuba-dev-pgdb psql -U yotsuba -d yotsuba_dev \
        -t -A -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'"
      ```
      Both should report ~116 tables (83 board tables + ~33 system tables).

- [ ] **Prod is healthy.** Spot-check a few boards:
      ```bash
      curl -s -o /dev/null -w '%{http_code}' http://d.local:8082/b/
      curl -s -o /dev/null -w '%{http_code}' http://d.local:8082/g/
      curl -s -o /dev/null -w '%{http_code}' http://d.local:8082/a/catalog
      ```

- [ ] **Disk space.** The MySQL dump + PG data will temporarily coexist. Check free space:
      ```bash
      ssh d.local df -h /
      ```

- [ ] **`$use_pdo` is false.** This must stay false. The DBAL manages its own PDO internally.
      Verify in `docker/entrypoint.sh` line 62:
      ```
      \$use_pdo = false;
      ```

- [ ] **No active users.** If this is a shared instance, announce maintenance downtime.

---

## 2. Data Export from MySQL

### 2a. Pre-migration backup (MANDATORY)

```bash
# Create a labeled backup inside the prod container
docker exec yotsuba-web /usr/local/bin/backup.sh dump pre-pg-migration

# Verify it exists and has reasonable size
docker exec yotsuba-web ls -lh /www/backups/pre-pg-migration_*.sql.gz
```

### 2b. Full data dump for migration

The built-in `backup-dump.sh` generates MySQL-compatible SQL. For PG migration we need a
clean CSV or SQL export. Two approaches:

**Option A: mysqldump to a local file (recommended)**

```bash
# Dump from the prod DB container directly
docker exec yotsuba-db mysqldump --skip-ssl -u root -prootpass \
  --single-transaction --routines --triggers --hex-blob \
  --default-character-set=utf8mb4 \
  yotsuba_global > /tmp/yotsuba_mysql_full.sql

# Verify size (should be >100KB for a populated instance, potentially much larger)
ls -lh /tmp/yotsuba_mysql_full.sql
```

**Option B: Per-table CSV export (for pgloader or custom script)**

```bash
# Run inside yotsuba-db container
docker exec yotsuba-db bash -c '
DB="yotsuba_global"
OUTDIR="/tmp/csv_export"
mkdir -p "$OUTDIR"

for tbl in $(mysql --skip-ssl -u root -prootpass "$DB" -N -e "SHOW TABLES"); do
    echo "Exporting $tbl..."
    mysql --skip-ssl -u root -prootpass "$DB" -N -B \
      -e "SELECT * FROM \`$tbl\`" > "$OUTDIR/$tbl.tsv"
done
echo "Done. Files in $OUTDIR"
'

# Copy to host
docker cp yotsuba-db:/tmp/csv_export /tmp/yotsuba_csv_export
```

---

## 3. Schema Preparation

The PG schema already exists at `docker/init_pg.sql`. It was hand-translated from
`docker/init.sql` during the DBAL migration and has been validated in dev.

### Verify schema parity

```bash
# List MySQL tables
docker exec yotsuba-db mysql --skip-ssl -u root -prootpass yotsuba_global \
  -N -e "SHOW TABLES" | sort > /tmp/mysql_tables.txt

# List PG tables (from dev)
docker exec yotsuba-dev-pgdb psql -U yotsuba -d yotsuba_dev \
  -t -A -c "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename" \
  > /tmp/pg_tables.txt

# Diff (should be empty or show only schema_migrations)
diff /tmp/mysql_tables.txt /tmp/pg_tables.txt
```

### Compare column definitions for a sample table

```bash
# MySQL columns for board table 'a'
docker exec yotsuba-db mysql --skip-ssl -u root -prootpass yotsuba_global \
  -e "DESCRIBE \`a\`"

# PG columns for board table 'a'
docker exec yotsuba-dev-pgdb psql -U yotsuba -d yotsuba_dev \
  -c "SELECT column_name, data_type, column_default FROM information_schema.columns WHERE table_name='a' ORDER BY ordinal_position"
```

Key type mappings already handled in `init_pg.sql`:

| MySQL              | PostgreSQL         |
|--------------------|--------------------|
| `int(11) AUTO_INCREMENT` | `SERIAL`    |
| `tinyint(1)`       | `SMALLINT`         |
| `bigint(20)`       | `BIGINT`           |
| `float`            | `REAL`             |
| `text`             | `TEXT`             |
| `varchar(N)`       | `VARCHAR(N)`       |
| `timestamp`        | `TIMESTAMP`        |
| `datetime`         | `TIMESTAMP`        |
| `enum(...)`        | `VARCHAR(16)`      |

---

## 4. Data Migration

### Option A: pgloader (recommended for large datasets)

pgloader handles type conversion, quoting, and reserved-word table names automatically.

**Install pgloader on the Docker host:**

```bash
# On Debian/Ubuntu (d.local)
sudo apt install pgloader

# Or via Docker
docker pull dimitri/pgloader
```

**Create pgloader configuration** (`/tmp/yotsuba_pgloader.conf`):

```
LOAD DATABASE
  FROM mysql://root:rootpass@localhost:3306/yotsuba_global
  INTO postgresql://yotsuba:yotsuba@localhost:5432/yotsuba_global

WITH include drop,
     create tables,
     create indexes,
     reset sequences,
     workers = 4,
     concurrency = 2,
     batch rows = 1000

SET PostgreSQL PARAMETERS
    maintenance_work_mem to '128MB',
    work_mem to '12MB'

-- Do NOT let pgloader create its own schema; we use init_pg.sql
-- Instead, load data only into existing tables:
-- WITH create no tables, create no indexes

CAST type tinyint to smallint,
     type int to integer,
     type bigint to bigint,
     type float to real,
     type datetime to timestamp,
     type enum to text

-- Board tables with reserved-word names need quoting
-- pgloader handles this automatically when targeting PG

BEFORE LOAD DO
  $$ SET client_encoding TO 'UTF8'; $$;
```

**If using pre-created schema (recommended):**

Change pgloader to data-only mode. First create the PG database and load schema:

```bash
# Create the prod PG database (run on d.local or wherever PG will run)
docker exec yotsuba-prod-pgdb createdb -U yotsuba yotsuba_global 2>/dev/null || true
docker exec -i yotsuba-prod-pgdb psql -U yotsuba -d yotsuba_global < docker/init_pg.sql
```

Then use pgloader in data-only mode:

```
LOAD DATABASE
  FROM mysql://root:rootpass@localhost:3306/yotsuba_global
  INTO postgresql://yotsuba:yotsuba@localhost:5432/yotsuba_global

WITH data only,
     reset sequences,
     workers = 4,
     concurrency = 2

CAST type tinyint to smallint,
     type datetime to timestamp;
```

**Run pgloader:**

```bash
# Port-forward both databases to d.local first (if not already exposed)
# MySQL is on 3306, PG needs to be accessible

pgloader /tmp/yotsuba_pgloader.conf
```

### Option B: Shell script (mysqldump + sed + psql)

For smaller datasets or if pgloader is unavailable. This script exports each table from
MySQL and imports into PostgreSQL.

```bash
#!/bin/bash
# migrate_data.sh — Move data from MySQL to PostgreSQL table by table
set -euo pipefail

MYSQL_HOST="localhost"
MYSQL_PORT="3306"
MYSQL_USER="root"
MYSQL_PASS="rootpass"
MYSQL_DB="yotsuba_global"

PG_HOST="localhost"
PG_PORT="5432"
PG_USER="yotsuba"
PG_PASS="yotsuba"
PG_DB="yotsuba_global"

export PGPASSWORD="$PG_PASS"

mysql_cmd="mysql --skip-ssl -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p$MYSQL_PASS $MYSQL_DB"
psql_cmd="psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DB"

# Get all tables
tables=$($mysql_cmd -N -e "SHOW TABLES")

total=0
failed=0

for tbl in $tables; do
    count=$($mysql_cmd -N -e "SELECT COUNT(*) FROM \`$tbl\`")
    if [ "$count" -eq 0 ]; then
        echo "SKIP $tbl (empty)"
        continue
    fi

    echo -n "Migrating $tbl ($count rows)... "

    # Export as tab-separated, import via COPY
    # COPY handles quoting of reserved-word table names when double-quoted
    tmpfile="/tmp/migrate_${tbl}.tsv"

    $mysql_cmd -N -B -e "SELECT * FROM \`$tbl\`" > "$tmpfile" 2>/dev/null

    if [ ! -s "$tmpfile" ]; then
        echo "EMPTY FILE, skipping"
        rm -f "$tmpfile"
        continue
    fi

    # Get column list for the COPY command
    cols=$($psql_cmd -t -A -c "
        SELECT string_agg('\"' || column_name || '\"', ', ' ORDER BY ordinal_position)
        FROM information_schema.columns
        WHERE table_name = '$tbl' AND table_schema = 'public'
    ")

    # Clear existing data in PG table
    $psql_cmd -c "TRUNCATE \"$tbl\" CASCADE" 2>/dev/null || true

    # Import
    if $psql_cmd -c "\\COPY \"$tbl\" ($cols) FROM '$tmpfile' WITH (FORMAT text, NULL '\\N')" 2>/dev/null; then
        echo "OK ($count rows)"
        total=$((total + count))
    else
        echo "FAILED"
        failed=$((failed + 1))
    fi

    rm -f "$tmpfile"
done

echo ""
echo "Migration complete: $total rows transferred, $failed tables failed"

# Reset all sequences to max(id) + 1
echo "Resetting sequences..."
$psql_cmd -t -A -c "
    SELECT 'SELECT setval(pg_get_serial_sequence(''\"' || table_name || '\"'', ''' || column_name || '''), COALESCE(MAX(\"' || column_name || '\"), 1)) FROM \"' || table_name || '\";'
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND column_default LIKE 'nextval%'
" | while read -r stmt; do
    $psql_cmd -c "$stmt" 2>/dev/null || true
done

echo "Sequences reset. Migration done."
```

### Option C: Python script with psycopg2 (for complex transformations)

Use this if you need to transform data during migration (e.g., fixing charset issues,
converting IP formats):

```bash
pip install mysql-connector-python psycopg2-binary
```

```python
#!/usr/bin/env python3
"""migrate_yotsuba.py — MySQL to PostgreSQL data migration"""
import mysql.connector
import psycopg2
import sys

MYSQL = dict(host='localhost', port=3306, user='root', password='rootpass', database='yotsuba_global')
PG = dict(host='localhost', port=5432, user='yotsuba', password='yotsuba', dbname='yotsuba_global')

my = mysql.connector.connect(**MYSQL)
pg = psycopg2.connect(**PG)
pg.autocommit = False

mycur = my.cursor()
pgcur = pg.cursor()

mycur.execute("SHOW TABLES")
tables = [r[0] for r in mycur.fetchall()]

for tbl in tables:
    mycur.execute(f"SELECT COUNT(*) FROM `{tbl}`")
    count = mycur.fetchone()[0]
    if count == 0:
        print(f"SKIP {tbl} (empty)")
        continue

    print(f"Migrating {tbl} ({count} rows)...", end=" ", flush=True)

    # Get columns
    mycur.execute(f"SELECT * FROM `{tbl}` LIMIT 0")
    cols = [desc[0] for desc in mycur.description]
    col_list = ', '.join(f'"{c}"' for c in cols)
    placeholders = ', '.join(['%s'] * len(cols))

    # Truncate PG table
    pgcur.execute(f'TRUNCATE "{tbl}" CASCADE')

    # Batch insert
    mycur.execute(f"SELECT * FROM `{tbl}`")
    batch = []
    for row in mycur:
        # Convert bytestrings to str, None stays None
        clean = []
        for val in row:
            if isinstance(val, bytes):
                clean.append(val.decode('utf-8', errors='replace'))
            else:
                clean.append(val)
        batch.append(tuple(clean))
        if len(batch) >= 1000:
            pgcur.executemany(f'INSERT INTO "{tbl}" ({col_list}) VALUES ({placeholders})', batch)
            batch = []
    if batch:
        pgcur.executemany(f'INSERT INTO "{tbl}" ({col_list}) VALUES ({placeholders})', batch)

    pg.commit()
    print(f"OK ({count})")

# Reset sequences
pgcur.execute("""
    SELECT 'SELECT setval(pg_get_serial_sequence(''"' || table_name || '"'', ''' || column_name || '''), COALESCE(MAX("' || column_name || '"), 1)) FROM "' || table_name || '"'
    FROM information_schema.columns
    WHERE table_schema = 'public' AND column_default LIKE 'nextval%'
""")
for (stmt,) in pgcur.fetchall():
    pgcur.execute(stmt)
pg.commit()

print("All sequences reset. Migration complete.")
my.close()
pg.close()
```

---

## 5. Validation

After data migration, verify integrity before cutover.

### 5a. Row count comparison

```bash
#!/bin/bash
# validate_counts.sh — Compare row counts between MySQL and PostgreSQL
MYSQL_CMD="docker exec yotsuba-db mysql --skip-ssl -u root -prootpass yotsuba_global -N"
PG_CMD="docker exec yotsuba-prod-pgdb psql -U yotsuba -d yotsuba_global -t -A"

echo "Table                    | MySQL  | PG     | Match"
echo "-------------------------|--------|--------|------"

tables=$($MYSQL_CMD -e "SHOW TABLES")
mismatches=0

for tbl in $tables; do
    my_count=$($MYSQL_CMD -e "SELECT COUNT(*) FROM \`$tbl\`" 2>/dev/null || echo "ERR")
    pg_count=$($PG_CMD -c "SELECT COUNT(*) FROM \"$tbl\"" 2>/dev/null || echo "ERR")
    pg_count=$(echo "$pg_count" | tr -d '[:space:]')

    if [ "$my_count" = "$pg_count" ]; then
        match="OK"
    else
        match="MISMATCH"
        mismatches=$((mismatches + 1))
    fi
    printf "%-25s| %-7s| %-7s| %s\n" "$tbl" "$my_count" "$pg_count" "$match"
done

echo ""
if [ "$mismatches" -eq 0 ]; then
    echo "All tables match."
else
    echo "WARNING: $mismatches table(s) have mismatched row counts!"
fi
```

### 5b. Spot-check specific data

```bash
# Compare a specific thread's data
BOARD="g"
THREAD_NO=1  # adjust to an actual thread number

# MySQL
docker exec yotsuba-db mysql --skip-ssl -u root -prootpass yotsuba_global \
  -e "SELECT no, resto, name, sub, LEFT(com, 50) FROM \`$BOARD\` WHERE no=$THREAD_NO OR resto=$THREAD_NO ORDER BY no"

# PostgreSQL
docker exec yotsuba-prod-pgdb psql -U yotsuba -d yotsuba_global \
  -c "SELECT no, resto, name, sub, LEFT(com, 50) FROM \"$BOARD\" WHERE no=$THREAD_NO OR resto=$THREAD_NO ORDER BY no"
```

### 5c. Verify sequences are correct

After importing data, auto-increment sequences must be set higher than the max existing ID,
otherwise the next INSERT will fail with a duplicate key error.

```bash
docker exec yotsuba-prod-pgdb psql -U yotsuba -d yotsuba_global -c "
    SELECT schemaname, sequencename, last_value
    FROM pg_sequences
    WHERE schemaname = 'public'
    ORDER BY sequencename
    LIMIT 20;
"
```

For any board table, verify the sequence is ahead of max `no`:

```bash
docker exec yotsuba-prod-pgdb psql -U yotsuba -d yotsuba_global -c "
    SELECT
        'Board: g' AS board,
        MAX(no) AS max_no,
        (SELECT last_value FROM pg_sequences WHERE sequencename = 'g_no_seq') AS seq_val;
    SELECT
        'Board: b' AS board,
        MAX(no) AS max_no,
        (SELECT last_value FROM pg_sequences WHERE sequencename = 'b_no_seq') AS seq_val;
"
```

### 5d. Test posting on dev with migrated data

Before cutting over prod, load the migrated data into the dev PG instance and test posting:

```bash
# Post a test thread
curl -X POST http://d.local:8084/b/imgboard.php \
  -F "mode=regist" \
  -F "name=MigrationTest" \
  -F "sub=Test Post" \
  -F "com=Testing after PG migration" \
  -H "Referer: http://d.local:8084/b/"

# Check it appears
curl -s http://d.local:8084/b/catalog.json | python3 -m json.tool | head -20
```

---

## 6. Cutover Procedure

This is the point of no return. Follow each step exactly.

### Step 1: Create final backup of MySQL prod

```bash
docker exec yotsuba-web /usr/local/bin/backup.sh dump pre-pg-cutover
```

### Step 2: Stop prod

```bash
cd /Users/kod/code/yotsuba-board
docker compose down
```

### Step 3: Add PostgreSQL service to docker-compose.yml

Edit `docker-compose.yml` to add the PG container and update the web service:

```yaml
name: yotsuba-prod

services:
  web:
    build: .
    container_name: yotsuba-web
    ports:
      - "8082:80"
    environment:
      - YOTSUBA_DB_DRIVER=pgsql
      - YOTSUBA_DB_HOST=db
      - YOTSUBA_DB_PORT=3306
      - YOTSUBA_DB_USER=yotsuba
      - YOTSUBA_DB_PASS=yotsuba
      - YOTSUBA_DB_NAME=yotsuba_global
      - YOTSUBA_PG_HOST=pgdb
      - YOTSUBA_PG_PORT=5432
      - YOTSUBA_PG_USER=yotsuba
      - YOTSUBA_PG_PASS=yotsuba
      - YOTSUBA_PG_NAME=yotsuba_global
      - YOTSUBA_MEMCACHED_HOST=memcached
      - YOTSUBA_MEMCACHED_PORT=11211
    depends_on:
      pgdb:
        condition: service_healthy
      memcached:
        condition: service_started
    # ... rest stays the same

  # Keep MySQL around for rollback (remove after migration is confirmed)
  db:
    build:
      context: ./docker
      dockerfile: Dockerfile.db
    container_name: yotsuba-db
    environment:
      MYSQL_ROOT_PASSWORD: rootpass
      MYSQL_USER: yotsuba
      MYSQL_PASSWORD: yotsuba
      MYSQL_DATABASE: yotsuba_global
    volumes:
      - db_data:/var/lib/mysql
      - backups_data:/backups
    networks:
      - lab-net
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-prootpass"]
      interval: 5s
      timeout: 5s
      retries: 20
    restart: unless-stopped

  pgdb:
    image: postgres:16-alpine
    container_name: yotsuba-prod-pgdb
    environment:
      POSTGRES_USER: yotsuba
      POSTGRES_PASSWORD: yotsuba
      POSTGRES_DB: yotsuba_global
    ports:
      - "5432:5432"
    volumes:
      - pg_data:/var/lib/postgresql/data
    networks:
      - lab-net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U yotsuba -d yotsuba_global"]
      interval: 5s
      timeout: 5s
      retries: 20
    restart: unless-stopped

  # ... memcached and adminer stay the same

volumes:
  db_data:        # keep for rollback
  pg_data:        # new PG volume
  uploads_data:
  thumbs_data:
  boards_data:
  backups_data:
  logs_data:
```

### Step 4: Start PG container only, load schema and data

```bash
# Start just the PG container
docker compose up -d pgdb

# Wait for it to be healthy
docker compose exec pgdb pg_isready -U yotsuba -d yotsuba_global

# Load the schema
docker exec -i yotsuba-prod-pgdb psql -U yotsuba -d yotsuba_global < docker/init_pg.sql

# Run the data migration (using whichever method from Section 4)
# If using the shell script:
bash /tmp/migrate_data.sh

# Or if using pgloader:
pgloader /tmp/yotsuba_pgloader.conf
```

### Step 5: Validate (run Section 5 checks)

```bash
bash /tmp/validate_counts.sh
```

### Step 6: Start the full stack

```bash
docker compose up --build -d
```

### Step 7: Smoke test

```bash
# Board pages load
curl -s -o /dev/null -w '%{http_code}' http://d.local:8082/b/
curl -s -o /dev/null -w '%{http_code}' http://d.local:8082/g/
curl -s -o /dev/null -w '%{http_code}' http://d.local:8082/a/catalog

# JSON API works
curl -s http://d.local:8082/g/catalog.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'Catalog OK: {len(d)} pages')"

# Admin panel loads
curl -s -o /dev/null -w '%{http_code}' http://d.local:8082/admin.php

# Test posting
curl -X POST http://d.local:8082/test/imgboard.php \
  -F "mode=regist" \
  -F "name=CutoverTest" \
  -F "sub=PG Migration Complete" \
  -F "com=First post on PostgreSQL" \
  -H "Referer: http://d.local:8082/test/"
```

### Step 8: Verify entrypoint detected the driver correctly

```bash
docker logs yotsuba-web 2>&1 | head -5
# Should show: [entrypoint] Database driver: pgsql
```

---

## 7. Rollback Plan

If something goes wrong after cutover, revert to MySQL in under 2 minutes.

### Quick rollback

```bash
# Stop everything
cd /Users/kod/code/yotsuba-board
docker compose down

# In docker-compose.yml, change:
#   YOTSUBA_DB_DRIVER=pgsql  -->  YOTSUBA_DB_DRIVER=mysql
# Remove or comment out the pgdb dependency from the web service's depends_on
# Restore db to depends_on

# Restart with MySQL
docker compose up --build -d

# Verify
curl -s -o /dev/null -w '%{http_code}' http://d.local:8082/b/
docker logs yotsuba-web 2>&1 | grep "Database driver"
# Should show: [entrypoint] Database driver: mysql
```

### If MySQL data was lost

Restore from the pre-cutover backup:

```bash
# The backup was created in Step 1 of cutover
docker exec yotsuba-db bash -c '
  zcat /backups/pre-pg-cutover_*.sql.gz | mysql --skip-ssl -u root -prootpass yotsuba_global
'
```

### Keeping both databases in sync (belt and suspenders)

During the first 24-48 hours after cutover, you can keep MySQL running alongside PG.
The MySQL data is frozen at the cutover point. If PG fails, you only lose posts made
after cutover. The structured post log at `/www/logs/posts.jsonl` can help replay
those lost posts.

---

## 8. Post-Migration Cleanup

After running on PostgreSQL successfully for at least 48 hours:

### Remove MySQL from prod compose

Edit `docker-compose.yml`:
- Remove the `db` service entirely
- Remove `db_data` from volumes
- Remove any `YOTSUBA_DB_HOST/PORT/USER/PASS/NAME` env vars from the web service
  (keep only the `YOTSUBA_PG_*` and `YOTSUBA_DB_DRIVER=pgsql` vars)

### Delete MySQL volume

```bash
docker compose down
docker volume rm yotsuba-prod_db_data
```

### Update backup.sh

The current `backup.sh` uses `mysql` and `mysqldump` commands. It needs to be updated
for PostgreSQL:

```bash
# In backup.sh, the db_has_data() and do_dump() functions should use pg_dump instead.
# The entrypoint already handles PG vs MySQL for most things, but the backup script
# is MySQL-only. Update it to check DB_DRIVER and use pg_dump when driver=pgsql:

# db_has_data for PG:
#   PGPASSWORD="$PG_PASS" psql -h "$PG_HOST" -U "$PG_USER" -d "$PG_DB" \
#     -t -A -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'"

# do_dump for PG:
#   PGPASSWORD="$PG_PASS" pg_dump -h "$PG_HOST" -U "$PG_USER" -d "$PG_DB" \
#     --format=custom --compress=6 -f "$filepath"
```

### Update Adminer connection

In `docker-compose.yml`, update Adminer's default server:

```yaml
adminer:
  environment:
    ADMINER_DEFAULT_SERVER: pgdb
    ADMINER_DEFAULT_DB_DRIVER: pgsql
```

### Clean up dev compose

In `docker-compose.dev.yml`, you can remove the MySQL `db` service and simplify to
PG-only if desired.

---

## 9. Known Issues and Gotchas

### Reserved word table names

Board names `int`, `out`, `test` are PostgreSQL reserved words. The DBAL's `$db->qi()`
method handles this by double-quoting all identifiers. All 758 call sites already use
`$db->qi()` for table names. However, if you write raw SQL for debugging or one-off
queries, always double-quote table names:

```sql
-- WRONG: will fail
SELECT * FROM int WHERE no = 1;

-- CORRECT
SELECT * FROM "int" WHERE no = 1;
```

### Sequence reset after data import

PostgreSQL sequences (used for `SERIAL`/auto-increment columns) do not automatically
update when you INSERT with explicit IDs. After any bulk data import, reset sequences:

```sql
-- For each board table (example: board 'a')
SELECT setval(pg_get_serial_sequence('"a"', 'no'), COALESCE(MAX(no), 1)) FROM "a";

-- For system tables with SERIAL PKs
SELECT setval(pg_get_serial_sequence('"boardlist"', 'id'), COALESCE(MAX(id), 1)) FROM "boardlist";
SELECT setval(pg_get_serial_sequence('"mod_users"', 'id'), COALESCE(MAX(id), 1)) FROM "mod_users";
SELECT setval(pg_get_serial_sequence('"banned_users"', 'no'), COALESCE(MAX(no), 1)) FROM "banned_users";
-- etc for all tables with SERIAL columns
```

Or reset all sequences at once:

```sql
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT t.table_name, c.column_name
        FROM information_schema.columns c
        JOIN information_schema.tables t ON t.table_name = c.table_name
        WHERE c.table_schema = 'public'
          AND c.column_default LIKE 'nextval%'
    LOOP
        EXECUTE format(
            'SELECT setval(pg_get_serial_sequence(%L, %L), COALESCE(MAX(%I), 1)) FROM %I',
            r.table_name, r.column_name, r.column_name, r.table_name
        );
    END LOOP;
END $$;
```

### Timestamp handling

- MySQL `datetime` maps to PG `timestamp without time zone`. The schema already handles this.
- MySQL `ON UPDATE CURRENT_TIMESTAMP` does not exist in PG. The `r9k_posts` table has a
  trigger function (`update_timestamp_column()`) in `init_pg.sql` to replicate this behavior.
- MySQL stores `0000-00-00 00:00:00` for unset timestamps. PG rejects this. The migration
  script should convert these to `NULL` or `'1970-01-01 00:00:00'`.

### LIMIT syntax

MySQL: `LIMIT offset, count` -- PG: `LIMIT count OFFSET offset`

The DBAL's `translateSQL()` method handles this automatically. No action needed, but be
aware if writing raw queries.

### MySQL SET commands silently skipped

The DBAL's `exec()` method skips MySQL-specific SET commands on PG:
- `SET read_buffer_size = ...`
- `SET sort_buffer_size = ...`
- `SET net_write_timeout = ...`
- `SET wait_timeout = ...`
- `SET sql_mode = ...`

These are no-ops on PG and handled transparently.

### INSERT IGNORE / ON DUPLICATE KEY UPDATE

MySQL's `INSERT IGNORE` becomes `INSERT ... ON CONFLICT DO NOTHING` in PG.
MySQL's `ON DUPLICATE KEY UPDATE` becomes `ON CONFLICT ... DO UPDATE SET`.
The DBAL `translateSQL()` handles these. The `init_pg.sql` schema already uses
`ON CONFLICT DO NOTHING` for seed data.

### Boolean handling

MySQL uses `tinyint(1)` for booleans, PG schema uses `SMALLINT` to maintain compatibility.
Values are 0/1 integers in both cases. No conversion needed.

### ENUM type

MySQL `ENUM('pending','approved','denied')` in `ban_appeals.status` is mapped to
`VARCHAR(16)` in PG. Application code uses string comparisons, so this works transparently.

### Table locking

MySQL `LOCK TABLES ... WRITE` becomes `BEGIN; LOCK TABLE ... IN EXCLUSIVE MODE` in PG.
The DBAL handles this in `lockTable()`/`unlockTables()`. PG lock is released on
transaction commit/rollback rather than explicit UNLOCK.

### Case sensitivity

PostgreSQL identifiers are case-sensitive when quoted. All table and column names in this
schema are lowercase, so this is not an issue. The DBAL always lowercases identifiers
before quoting.

### `$use_pdo` must stay false

The legacy codebase checks `$use_pdo` in several places. It must remain `false`.
The DBAL uses PDO internally but this is invisible to the legacy code. The entrypoint
generates `config_db.php` with `$use_pdo = false;` -- do not change this.

### Backup script compatibility

The current `backup.sh` and `backup-dump.sh` are MySQL-specific. After migration,
they will fail silently (the `db_has_data()` check will return false). Update them
to use `pg_dump` as described in Section 8, or they will not create backups.

### Image/file data

Images and thumbnails are stored on the filesystem (`/www/4chan.org/web/images/` and
`/www/4chan.org/web/thumbs/`), not in the database. The Docker volumes `uploads_data`
and `thumbs_data` are unaffected by the database migration. No action needed for media files.
