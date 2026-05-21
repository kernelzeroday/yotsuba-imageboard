#!/bin/bash
set -e

# === 4chan Yotsuba — container entrypoint ===
# Adjusts config paths for the container environment,
# then launches Apache.

CONFIG_DIR="/var/www/html/config"
GLOBAL_CONFIG="$CONFIG_DIR/global_config.ini"
LIB_INI="/var/www/html/lib/ini.php"

echo "[entrypoint] Bootstrapping Yotsuba container..."

# ---- Patch lib/ini.php paths for container ----
if grep -q "/www/global/yotsuba/config" "$LIB_INI"; then
    sed -i "s|/www/global/yotsuba/config|/var/www/html/config|g" "$LIB_INI"
    echo "[entrypoint] Patched configdir in ini.php"
fi

# ---- Patch config_db.php if not already done ----
# The docker image already copied docker/config/config_db.php, but
# ensure env vars are current.
cat > "$CONFIG_DIR/config_db.php" <<'PHPEOF'
<?php
// Containerized config — values from environment
define('SQLHOST_GLOBAL', getenv('YOTSUBA_DB_HOST') ?: 'db');
define('SQLUSER_GLOBAL', getenv('YOTSUBA_DB_USER') ?: 'yotsuba');
define('SQLPASS_GLOBAL', getenv('YOTSUBA_DB_PASS') ?: 'yotsuba');
define('SQLDB_GLOBAL',  getenv('YOTSUBA_DB_GLOBAL') ?: 'yotsuba_global');

define('SQLUSER', SQLUSER_GLOBAL);
define('SQLPASS', SQLPASS_GLOBAL);

// Use PDO — modern, safer, works on PHP 5.6+
$use_pdo = true;
$using_pdo = true;
PHPEOF

# ---- Patch global_config.ini paths for container ----
if [ -f "$GLOBAL_CONFIG" ]; then
    sed -i 's|/www/global/yotsuba/|/var/www/html/|g' "$GLOBAL_CONFIG"
    sed -i 's|/www/4chan.org/web/|/var/www/html/|g' "$GLOBAL_CONFIG"
    sed -i 's|/www/keys/|/var/www/html/keys/|g' "$GLOBAL_CONFIG"
    echo "[entrypoint] Patched paths in global_config.ini"
fi

# ---- Update MEMCACHED_HOST if env var set ----
if [ -n "$YOTSUBA_MEMCACHED_HOST" ] && [ -f "$GLOBAL_CONFIG" ]; then
    sed -i "s/MEMCACHED_HOST *=.*/MEMCACHED_HOST = $YOTSUBA_MEMCACHED_HOST/" "$GLOBAL_CONFIG"
    echo "[entrypoint] Set MEMCACHED_HOST=$YOTSUBA_MEMCACHED_HOST"
fi

# ---- Create runtime directories ----
mkdir -p /var/www/html/keys
mkdir -p /var/www/html/boards
mkdir -p /var/www/html/images
mkdir -p /var/www/html/thumbs
mkdir -p /var/www/html/sys
mkdir -p /var/www/html/plugins
mkdir -p /var/www/html/views
mkdir -p /www/perhost
chown -R www-data:www-data /var/www/html/boards /var/www/html/images /var/www/html/thumbs /var/www/html/sys

# ---- Set Apache ServerName to suppress warning ----
echo "ServerName localhost" >> /etc/apache2/apache2.conf

# ---- Launch Apache ----
echo "[entrypoint] Starting Apache..."
exec "$@"
