#!/bin/bash
set -e

echo "[entrypoint] Bootstrapping Yotsuba container..."

SRC=/var/www/html
BOARDS_ROOT=/www/4chan.org/web/boards

# ---- Write container DB config ----
cat > "$SRC/config/config_db.php" <<'PHPEOF'
<?php
define('SQLHOST_GLOBAL', getenv('YOTSUBA_DB_HOST') ?: 'db');
define('SQLUSER_GLOBAL', getenv('YOTSUBA_DB_USER') ?: 'yotsuba');
define('SQLPASS_GLOBAL', getenv('YOTSUBA_DB_PASS') ?: 'yotsuba');
define('SQLDB_GLOBAL',  getenv('YOTSUBA_DB_GLOBAL') ?: 'yotsuba_global');
define('SQLHOST', SQLHOST_GLOBAL);
define('SQLDB', SQLDB_GLOBAL);
define('SQLUSER', SQLUSER_GLOBAL);
define('SQLPASS', SQLPASS_GLOBAL);
$use_pdo = false;
$using_pdo = false;
PHPEOF

# ---- Fix: load config_db.php before yotsuba_config.php checks $use_pdo ----
sed -i 's|require_once .lib/ini.php.|require_once "lib/ini.php";\nrequire_once "config/config_db.php";|' "$SRC/yotsuba_config.php"

# ---- Patch MEMCACHED_HOST ----
if [ -n "$YOTSUBA_MEMCACHED_HOST" ]; then
    sed -i "s/MEMCACHED_HOST *=.*/MEMCACHED_HOST = $YOTSUBA_MEMCACHED_HOST/" "$SRC/config/global_config.ini"
fi

# ---- Create board directories with symlinks ----
# Each board directory needs symlinks to PHP files AND supporting directories
# because PHP resolves relative includes via CWD (the board dir)
for board_conf in "$SRC/config/boards/"*.config.ini; do
    board=$(basename "$board_conf" .config.ini)
    board_dir="$BOARDS_ROOT/$board"
    mkdir -p "$board_dir"

    # Symlink core PHP files
    for f in imgboard.php catalog.php json.php rid.php; do
        ln -sf "$SRC/$f" "$board_dir/$f"
    done

    # Symlink directories needed for relative includes
    for d in config lib views css js modes forms plugins wordfilters imgtop; do
        ln -sf "$SRC/$d" "$board_dir/$d"
    done

    # Symlink support files in root
    for f in yotsuba_config.php header.txt footer.txt header-sys.txt header-ws.txt \
             footer-ws.txt footer-test.txt header-test.txt globalmsg.txt \
             boardlist.txt captcha.php captcha-test.php catalog.php catalog-test.php \
             json.php json-test.php admin.php admin-test.php auth.php auth-test.php \
             signin.php signin-test.php emotes_xa22.php xa24tb.php derefer.php \
             rebuildd.php rebuildd-test.php clippy.html latest.php; do
        if [ -f "$SRC/$f" ]; then
            ln -sf "$SRC/$f" "$board_dir/$f"
        fi
    done
done

# ---- Create runtime directories ----
mkdir -p /www/perhost
mkdir -p /www/keys
chown -R www-data:www-data /www/perhost /www/4chan.org/web/images /www/4chan.org/web/thumbs /www/4chan.org/web/sys /www/4chan.org/web/boards

# ---- Set Apache ServerName ----
echo "ServerName localhost" >> /etc/apache2/apache2.conf

echo "[entrypoint] Boards set up: $(ls $BOARDS_ROOT | tr '\n' ' ')"
echo "[entrypoint] Starting Apache..."
exec "$@"
