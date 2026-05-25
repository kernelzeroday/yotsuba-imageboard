#!/bin/bash
# Pre-generate board index HTML by hitting local Apache for each board.
# Called from entrypoint.sh after Apache starts.

BASE_URL="http://localhost"
DB_DRIVER="${YOTSUBA_DB_DRIVER:-mysql}"

if [ "$DB_DRIVER" = "pgsql" ]; then
    BOARDS=$(PGPASSWORD="${YOTSUBA_PG_PASS:-yotsuba}" psql \
        -h "${YOTSUBA_PG_HOST:-pgdb}" \
        -p "${YOTSUBA_PG_PORT:-5432}" \
        -U "${YOTSUBA_PG_USER:-yotsuba}" \
        -d "${YOTSUBA_PG_NAME:-yotsuba_dev}" \
        -t -A -c "SELECT dir FROM boardlist WHERE hidden = 0" 2>/dev/null)
else
    BOARDS=$(php -- <<'PHPEOF'
<?php
require '/var/www/html/config/config_db.php';
$host = defined('SQLHOST_GLOBAL') ? SQLHOST_GLOBAL : 'db';
if (strpos($host, ':') !== false) {
    list($h, $p) = explode(':', $host, 2);
} else {
    $h = $host; $p = 3306;
}
$c = @mysqli_connect($h, SQLUSER_GLOBAL, SQLPASS_GLOBAL, SQLDB_GLOBAL, (int)$p);
if (!$c) exit;
$q = mysqli_query($c, "SELECT dir FROM boardlist WHERE hidden = 0");
while ($r = mysqli_fetch_row($q)) { echo $r[0] . "\n"; }
PHPEOF
)
fi

if [ -z "$BOARDS" ]; then
    echo "[init] No boards found. Skipping pre-generation."
    exit 0
fi

echo "[init] Generating board index pages..."

for board in $BOARDS; do
    HTTP_CODE=$(curl -s "$BASE_URL/$board/" -o /dev/null -w "%{http_code}" 2>/dev/null)

    INDEX_FILE="/www/4chan.org/web/boards/$board/imgboard.html"
    GZ_FILE="${INDEX_FILE}.gz"
    if [ -f "$GZ_FILE" ]; then
        SIZE=$(stat -c%s "$GZ_FILE" 2>/dev/null || stat -f%z "$GZ_FILE" 2>/dev/null)
        echo "[init] $board — $HTTP_CODE, index: $SIZE bytes (gz)"
    elif [ -f "$INDEX_FILE" ]; then
        SIZE=$(stat -c%s "$INDEX_FILE" 2>/dev/null || stat -f%z "$INDEX_FILE" 2>/dev/null)
        echo "[init] $board — $HTTP_CODE, index: $SIZE bytes"
    else
        echo "[init] $board — $HTTP_CODE"
    fi

    # Generate empty archive page if missing
    ARCHIVE_FILE="/www/4chan.org/web/boards/$board/archive.html.gz"
    if [ ! -f "$ARCHIVE_FILE" ]; then
        curl -s "$BASE_URL/$board/imgboard.php?mode=rebuild_archive" -o /dev/null 2>/dev/null
        if [ ! -f "$ARCHIVE_FILE" ]; then
            echo "<html><head><title>/$board/ - Archive</title></head><body><h4 class=\"center\">No archived threads.</h4></body></html>" \
                | gzip > "$ARCHIVE_FILE"
        fi
    fi
done

echo "[init] Board pre-generation complete."
