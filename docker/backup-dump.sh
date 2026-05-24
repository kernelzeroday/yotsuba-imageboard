#!/bin/bash
# Version-compatible database dump using only mysql client.
# Generates SQL that can be piped into mysql to restore.
set -uo pipefail
DB_HOST="${1:-db}"
DB_USER="${2:-root}"
DB_PASS="${3:-rootpass}"
DB_NAME="${4:-yotsuba_global}"

M() { mysql --skip-ssl -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N "$@" 2>/dev/null; }

cat <<HEADER
-- Yotsuba database backup $(date '+%Y-%m-%d %H:%M:%S')
-- Tables dumped via mysql client (version-compatible)
SET FOREIGN_KEY_CHECKS=0;
SET NAMES utf8mb4;
SET SQL_MODE='NO_AUTO_VALUE_ON_ZERO';

HEADER

# Get all tables
tables=$(M -e "SHOW TABLES")

for tbl in $tables; do
    echo "-- ---"
    echo "-- Table: $tbl"
    echo "-- ---"
    echo "DROP TABLE IF EXISTS \`$tbl\`;"
    # Get CREATE TABLE (field 2 of tab-separated output)
    M -e "SHOW CREATE TABLE \`$tbl\`" | cut -f2-
    echo ";"
    echo ""

    # Generate INSERT statements via SELECT with server-side QUOTE()
    # QUOTE() handles all escaping correctly for any data type
    ncols=$(M -e "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='$DB_NAME' AND TABLE_NAME='$tbl'")
    if [ "${ncols:-0}" -eq 0 ]; then continue; fi

    cnt=$(M -e "SELECT COUNT(*) FROM \`$tbl\`")
    if [ "${cnt:-0}" -eq 0 ]; then
        echo ""
        continue
    fi

    # Build CONCAT expression using QUOTE() for each column
    concat_expr=$(M -e "SELECT GROUP_CONCAT(CONCAT('QUOTE(\`', COLUMN_NAME, '\`)') ORDER BY ORDINAL_POSITION SEPARATOR ',\",\",') FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='$DB_NAME' AND TABLE_NAME='$tbl'")

    # Query: SELECT CONCAT('INSERT INTO `tbl` VALUES(', QUOTE(col1), ',', QUOTE(col2), ..., ');')
    M --raw -e "SELECT CONCAT('INSERT INTO \`$tbl\` VALUES(', ${concat_expr}, ');') FROM \`$tbl\`"
    echo ""
done

echo "SET FOREIGN_KEY_CHECKS=1;"
