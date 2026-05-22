#!/bin/bash
# Pre-generate board index HTML by hitting local Apache for each board.
# Called from entrypoint.sh after Apache starts.

BASE_URL="http://localhost"

BOARDS=$(php -- <<'PHPEOF'
<?php
require '/var/www/html/config/config_db.php';
$c = mysql_connect(SQLHOST_GLOBAL, SQLUSER_GLOBAL, SQLPASS_GLOBAL);
if (!$c) exit;
mysql_select_db(SQLDB_GLOBAL, $c);
$q = mysql_query("SELECT dir FROM boardlist WHERE hidden = 0");
while ($r = mysql_fetch_row($q)) { echo $r[0] . "\n"; }
PHPEOF
)

if [ -z "$BOARDS" ]; then
    echo "[init] No boards found. Skipping pre-generation."
    exit 0
fi

echo "[init] Pre-generating board indexes..."

for board in $BOARDS; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/$board/" 2>&1)

    INDEX_FILE="/www/localchan/boards/$board/imgboard.html"
    GZ_FILE="${INDEX_FILE}.gz"
    if [ -f "$GZ_FILE" ]; then
        SIZE=$(stat -c%s "$GZ_FILE" 2>/dev/null || stat -f%z "$GZ_FILE" 2>/dev/null)
        echo "[init] $board — HTTP $HTTP_CODE, index: $SIZE bytes (gz)"
    elif [ -f "$INDEX_FILE" ]; then
        SIZE=$(stat -c%s "$INDEX_FILE" 2>/dev/null || stat -f%z "$INDEX_FILE" 2>/dev/null)
        echo "[init] $board — HTTP $HTTP_CODE, index: $SIZE bytes"
    else
        echo "[init] $board — HTTP $HTTP_CODE, WARNING: index not created"
    fi
done

echo "[init] Board pre-generation complete."
