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

// Stub captcha keys for lab — not valid externally
define('RECAPTCHA_API_KEY_PUBLIC', 'lab-test-key');
define('RECAPTCHA_API_KEY_PRIVATE', 'lab-test-key');
define('HCAPTCHA_API_KEY_PUBLIC', 'lab-test-key');
define('HCAPTCHA_API_KEY_PRIVATE', 'lab-test-key');
define('TCAPTCHA_API_KEY_PUBLIC', 'lab-test-key');
define('TCAPTCHA_API_KEY_PRIVATE', 'lab-test-key');
PHPEOF

# ---- Fix: load config_db.php before yotsuba_config.php checks $use_pdo ----
sed -i 's|require_once .lib/ini.php.|require_once "lib/ini.php";\nrequire_once "config/config_db.php";|' "$SRC/yotsuba_config.php"

# ---- Patch MEMCACHED_HOST ----
if [ -n "$YOTSUBA_MEMCACHED_HOST" ]; then
    sed -i "s/MEMCACHED_HOST *=.*/MEMCACHED_HOST = $YOTSUBA_MEMCACHED_HOST/" "$SRC/config/global_config.ini"
fi

# ---- Lab patches: allow on-demand index generation ----
# 1. Remove DDOS check in updatelog_real so GET requests can trigger rebuild
sed -i "s|if( \$_SERVER\\['REQUEST_METHOD'\\] == 'GET' \\&\\& !has_level() ) {|if (false) { // lab|" "$SRC/views/imgboard.php"

# 2. Patch updating_index() to serve cached static HTML (generate on first access).
#    updatelog() writes .gz files to disk via print_page(); we read them back.
#    Idempotent: skips if already patched.
php -- <<'PHPEOF'
<?php
$f = file_get_contents('/var/www/html/imgboard.php');
// Check if already patched
if (strpos($f, '// Lab patch: serve cached static HTML') !== false) {
    echo "[entrypoint] updating_index() already patched, skipping.\n";
    exit;
}
$old = 'function updating_index()
{
	$proto = ( stripos( $_SERVER["HTTP_REFERER"], "https" ) !== false ) ? "https:" : "http:";
	echo';
$new = 'function updating_index()
{
	// Lab patch: serve cached static HTML if available, generate if not.
	$file = SELF_PATH2_FILE;
	$gzfile = $file . ".gz";
	if (file_exists($gzfile)) {
		header("Content-Encoding: gzip");
		readfile($gzfile);
		return;
	}
	if (file_exists($file)) {
		readfile($file);
		return;
	}
	// Generate on first access (bypasses STATIC_REBUILD early-return)
	global $mode;
	$mode = "nothing";
	updatelog(0, 0);
	if (file_exists($gzfile)) {
		header("Content-Encoding: gzip");
		readfile($gzfile);
		return;
	}
	if (file_exists($file)) {
		readfile($file);
		return;
	}
	// Fallback: original "Updating index..." spinner
	$proto = ( stripos( $_SERVER["HTTP_REFERER"], "https" ) !== false ) ? "https:" : "http:";
	echo';
$f = str_replace($old, $new, $f, $count);
file_put_contents('/var/www/html/imgboard.php', $f);
echo "[entrypoint] Patched updating_index() to serve cached HTML ($count replacements).\n";
PHPEOF

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

# ---- Start Apache in background for init ----
echo "[entrypoint] Starting Apache (background) for board init..."
apache2-foreground &
APACHE_PID=$!
sleep 3

# ---- Pre-generate board index HTML via HTTP ----
/usr/local/bin/init-boards.sh

# ---- Bring Apache to foreground ----
echo "[entrypoint] Board init complete. Bringing Apache to foreground..."
wait $APACHE_PID
