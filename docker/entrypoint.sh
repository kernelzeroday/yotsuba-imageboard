#!/bin/bash
set -e

echo "[entrypoint] Bootstrapping Yotsuba container..."

SRC=/var/www/html
BOARDS_ROOT=/www/4chan.org/web/boards

# ---------------------------------------------------------------------------
# Runtime database config (generated from environment variables)
# ---------------------------------------------------------------------------
cat > "$SRC/config/config_db.php" <<'PHPEOF'
<?php
define('SQLHOST_GLOBAL', getenv('YOTSUBA_DB_HOST') ?: 'db');
define('SQLUSER_GLOBAL', getenv('YOTSUBA_DB_USER') ?: 'yotsuba');
define('SQLPASS_GLOBAL', getenv('YOTSUBA_DB_PASS') ?: 'yotsuba');
define('SQLDB_GLOBAL',  getenv('YOTSUBA_DB_NAME') ?: 'yotsuba_global');
define('SQLHOST', SQLHOST_GLOBAL);
define('SQLDB', SQLDB_GLOBAL);
define('SQLUSER', SQLUSER_GLOBAL);
define('SQLPASS', SQLPASS_GLOBAL);
$use_pdo = false;
$using_pdo = false;

define('RECAPTCHA_API_KEY_PUBLIC', 'lab-test-key');
define('RECAPTCHA_API_KEY_PRIVATE', 'lab-test-key');
define('HCAPTCHA_API_KEY_PUBLIC', 'lab-test-key');
define('HCAPTCHA_API_KEY_PRIVATE', 'lab-test-key');
define('TCAPTCHA_API_KEY_PUBLIC', 'lab-test-key');
define('TCAPTCHA_API_KEY_PRIVATE', 'lab-test-key');
PHPEOF

# ---------------------------------------------------------------------------
# Patch config loader to pick up config_db.php before checking $use_pdo
# ---------------------------------------------------------------------------
if ! grep -q 'config_db.php' "$SRC/yotsuba_config.php"; then
    sed -i "/require_once 'lib\/ini.php'/a require_once 'config\/config_db.php';" "$SRC/yotsuba_config.php"
fi

# ---------------------------------------------------------------------------
# Global config overrides for local lab environment
# ---------------------------------------------------------------------------
patch_ini() {
    sed -i "s|^$1 = .*|$1 = $2|" "$SRC/config/global_config.ini"
}

# Memcached
if [ -n "$YOTSUBA_MEMCACHED_HOST" ]; then
    patch_ini MEMCACHED_HOST "$YOTSUBA_MEMCACHED_HOST"
fi

# Disable captcha
patch_ini CAPTCHA no
patch_ini CAPTCHA_TWISTER no

# Local asset serving
patch_ini STATIC_SERVER "/static/"
patch_ini DATA_SERVER "/"
patch_ini PHP_SERVER "/"
patch_ini IMG_SERVER "/images/"
patch_ini THUMB_DIR2_PART "localhost/thumbs/{{BOARD_DIR}}/"
patch_ini MAIN_DOMAIN localhost
patch_ini TITLEIMG "/rid.php"
patch_ini STATIC_IMG_DIR2 "/static/image/"
patch_ini NO_TEXTONLY no

# Relaxed rate limits for testing
patch_ini MAX_USER_THREADS 999
patch_ini MAX_USER_THREADS_PERIOD 0
for key in RENZOKU RENZOKU2 RENZOKU2_INTRA RENZOKU3 RENZOKU_DUPE; do
    patch_ini "$key" 5
done

# Disable anti-flood
for key in ANTI_FLOOD_INTERVAL ANTI_FLOOD_INTERVAL_REP ANTI_FLOOD_INTERVAL_GLOBAL \
           ANTI_FLOOD_INTERVAL_SITE ANTI_FLOOD_INTERVAL_RAW \
           ANTIFLOOD_INTERVAL_REPLY ANTIFLOOD_INTERVAL_OP; do
    patch_ini "$key" 0
done
for key in ANTI_FLOOD_THRES ANTI_FLOOD_THRES_REP ANTI_FLOOD_THRES_GLOBAL \
           ANTI_FLOOD_THRES_SITE ANTI_FLOOD_THRES_RAW \
           ANTIFLOOD_THRES_REPLY ANTIFLOOD_THRES_OP; do
    patch_ini "$key" 99999
done

# ---------------------------------------------------------------------------
# PHP source patches (idempotent — skip if already applied)
# ---------------------------------------------------------------------------

# Enable error display for lab debugging
sed -i 's/display_errors = Off/display_errors = On/' /usr/local/etc/php/conf.d/yotsuba.ini

# Allow GET requests to trigger index rebuild (bypass DDOS check)
php -- <<'PHPEOF'
<?php
$f = '/var/www/html/views/imgboard.php';
$c = file_get_contents($f);
if (strpos($c, '// lab') !== false) exit;
$c = str_replace(
    "if( \$_SERVER['REQUEST_METHOD'] == 'GET' && !has_level() ) {",
    "if (false) { // lab",
    $c, $n
);
if ($n) { file_put_contents($f, $c); echo "[entrypoint] Patched DDOS check in views/imgboard.php\n"; }
PHPEOF

# Accept any referrer — bypass validate_referer()
php -- <<'PHPEOF'
<?php
foreach (['/var/www/html/imgboard.php', '/var/www/html/imgboard-test.php'] as $f) {
    if (!file_exists($f)) continue;
    $c = file_get_contents($f);
    if (strpos($c, '// lab: accept any referrer') !== false) continue;
    $c = str_replace(
        "if (!\$strict && (!isset(\$_SERVER['HTTP_REFERER']) || \$_SERVER['HTTP_REFERER'] == '')) {",
        "if (true) { // lab: accept any referrer",
        $c, $n
    );
    if ($n) { file_put_contents($f, $c); echo "[entrypoint] Patched referrer check in " . basename($f) . "\n"; }
}
PHPEOF

# Stub GeoIP2 (MaxMind not installed in lab)
php -- <<'PHPEOF'
<?php
$f = '/var/www/html/lib/geoip2.php';
$c = file_get_contents($f);
if (strpos($c, 'GeoIP stubbed') !== false) exit;
$c = str_replace(
    'return new MaxMind\\Db\\Reader($file);',
    'return false; // GeoIP stubbed for lab',
    $c, $n
);
if ($n) { file_put_contents($f, $c); echo "[entrypoint] Stubbed GeoIP2\n"; }
PHPEOF

# ---------------------------------------------------------------------------
# Rewrite external URLs to local paths
# ---------------------------------------------------------------------------
rewrite_urls() {
    local f="$1"
    [ -f "$f" ] || return

    # 4chan/4channel domain URLs → relative paths
    sed -i "s|https://boards\.4chan\.org/|/|g" "$f"
    sed -i "s|//boards\.4chan\.org/|/|g" "$f"
    sed -i "s|https://www\.4chan\.org/|/|g" "$f"
    sed -i "s|//www\.4chan\.org/|/|g" "$f"
    sed -i "s|//www\.4chan\.org|/|g" "$f"
    sed -i "s|https://sys\.4chan\.org/|/|g" "$f"
    sed -i "s|//sys\.4chan\.org/|/|g" "$f"
    sed -i "s|https://sys\.4chan\.org|/sys|g" "$f"
    sed -i "s|https://www\.4channel\.org/|/|g" "$f"
    sed -i "s|//www\.4channel\.org/|/|g" "$f"
    sed -i "s|//www\.4channel\.org|/|g" "$f"
    sed -i "s|//p\.4chan\.org/|/|g" "$f"

    # CDN → local static/images
    sed -i "s|https://s\.4cdn\.org/|/static/|g" "$f"
    sed -i "s|//s\.4cdn\.org/|/static/|g" "$f"
    sed -i "s|https://i\.4cdn\.org/|/images/|g" "$f"
    sed -i "s|http://i\.4cdn\.org/|/images/|g" "$f"
    sed -i "s|//i\.4cdn\.org/|/images/|g" "$f"

    # Strip third-party ad/analytics scripts
    sed -i 's|</script><script src="https://static\.danbo\.org/[^"]*"[^>]*>||g' "$f"
    sed -i 's|<script[^>]*src="https://cdn\.pubfuture-ad\.com/[^"]*"[^>]*></script>||g' "$f"
    sed -i 's|<link[^>]*href="https://fonts\.googleapis\.com/[^"]*"[^>]*>||g' "$f"

    # team/internal subdomains
    sed -i "s|https://team\.4chan\.org/|/|g" "$f"
    sed -i "s|http://team\.4chan\.org/|/|g" "$f"
}

# Headers and footers
for f in "$SRC/header.txt" "$SRC/header-sys.txt" "$SRC/header-ws.txt" "$SRC/header-test.txt" \
         "$SRC/footer.txt" "$SRC/footer-ws.txt" "$SRC/footer-test.txt"; do
    rewrite_urls "$f"
done

# PHP files
for f in "$SRC/imgboard.php" "$SRC/imgboard-test.php" \
         "$SRC/catalog.php" "$SRC/catalog-test.php" \
         "$SRC/admin.php" "$SRC/admin-test.php" \
         "$SRC/auth.php" "$SRC/auth-test.php" \
         "$SRC/captcha.php" "$SRC/captcha-test.php" \
         "$SRC/signin.php" "$SRC/signin-test.php" \
         "$SRC/views/signin.tpl.php" "$SRC/views/signin-test.tpl.php" \
         "$SRC/views/imgboard.php" "$SRC/views/imgboard-test.php" \
         "$SRC/views/pass_auth.tpl.php" \
         "$SRC/modes/report.php" "$SRC/modes/report-test.php" \
         "$SRC/lib/admin.php" "$SRC/lib/admin-test.php" \
         "$SRC/forms/ban.php"; do
    rewrite_urls "$f"
done

# Fix dynamic domain URL construction (PHP regex for complex string concatenation)
php -- <<'PHPEOF'
<?php
$files = [
    '/var/www/html/imgboard.php',
    '/var/www/html/imgboard-test.php',
    '/var/www/html/admin.php',
    '/var/www/html/admin-test.php',
];

foreach ($files as $file) {
    if (!file_exists($file)) continue;
    $code = file_get_contents($file);
    $orig = $code;

    $code = str_replace(
        '"href=\"$protocol//boards." . L::d(BOARD_DIR) . "/$1/\\""',
        '\'href="/$1/"\'',
        $code
    );
    $code = str_replace(
        '"href=\"//sys." . L::d(BOARD_DIR) . "/$1/admin\\""',
        '\'href="/$1/admin"\'',
        $code
    );
    $code = str_replace(
        '\"//boards." . L::d(BOARD_DIR) . \'/\'',
        '\"/"',
        $code
    );

    $patterns = [
        '~\$proto\s*\.\s*\'//boards\.\'\s*\.\s*L::d\([^)]*\)\s*\.\s*\'/~' => "'/",
        '~\$protocol\s*\.\s*\'//boards\.\'\s*\.\s*L::d\([^)]*\)\s*\.\s*\'/~' => "'/",
        '~"https://boards\."\s*\.\s*L::d\([^)]*\)\s*\.\s*"/~' => '"/',
        '~"https://boards\."\s*\.\s*L::d\([^)]*\)\s*\.\s*\'/~' => "\"/'",
        '~"//boards\."\s*\.\s*L::d\([^)]*\)\s*\.\s*"/~' => '"/',
        '~"//boards\."\s*\.\s*L::d\([^)]*\)\s*\.\s*\'/~' => "\"/'",
        '~"https://www\."\s*\.\s*L::d\([^)]*\)\s*\.\s*"/~' => '"/',
        '~"//sys\."\s*\.\s*L::d\([^)]*\)\s*\.\s*"/~' => '"/',
        '~\'https://boards\.\'\s*\.\s*L::d\([^)]*\)\s*\.\s*\'/~' => "'/",
        '~\'https://boards\.\'\s*\.\s*L::d\([^)]*\)\s*\.\s*"/~' => '"/',
        '~\'//boards\.\'\s*\.\s*L::d\([^)]*\)\s*\.\s*\'/~' => "'/",
        '~\'//boards\.\'\s*\.\s*L::d\([^)]*\)\s*\.\s*"/~' => '"/',
        '~\'https://www\.\'\s*\.\s*L::d\([^)]*\)\s*\.\s*\'/~' => "'/",
        '~\'https://www\.\'\s*\.\s*L::d\([^)]*\)\s*\.\s*"/~' => '"/',
        '~\'//www\.\'\s*\.\s*L::d\([^)]*\)\s*\.\s*\'/~' => "'/",
        '~\'//www\.\'\s*\.\s*L::d\([^)]*\)\s*\.\s*"/~' => '"/',
        '~\'https://sys\.\'\s*\.\s*L::d\([^)]*\)\s*\.\s*\'/~' => "'/",
        '~\'//sys\.\'\s*\.\s*L::d\([^)]*\)\s*\.\s*\'/~' => "'/",
        '~//boards\.\'\s*\.\s*L::d\([^)]*\)\s*\.\s*\'/~' => "/",
        '~//boards\.\'\s*\.\s*L::d\([^)]*\)\s*\.\s*"/~' => '/',
        '~https://boards\.\'\s*\.\s*L::d\([^)]*\)\s*\.\s*\'/~' => "/",
        '~https://boards\.\'\s*\.\s*L::d\([^)]*\)\s*\.\s*"/~' => '/',
        '~//www\.\'\s*\.\s*L::d\([^)]*\)\s*\.\s*\'/~' => "/",
        '~//www\.\'\s*\.\s*L::d\([^)]*\)\s*\.\s*"/~' => '/',
    ];

    foreach ($patterns as $pattern => $replacement) {
        $code = preg_replace($pattern, $replacement, $code);
    }

    if ($code !== $orig) {
        file_put_contents($file, $code);
        echo "[entrypoint] Fixed domain URLs in " . basename($file) . "\n";
    }
}
PHPEOF

# Board config ini files
for board_conf in "$SRC/config/boards/"*.config.ini; do
    [ -f "$board_conf" ] || continue
    sed -i 's|//www\.4chan\.org/|/|g' "$board_conf"
    sed -i 's|//boards\.4chan\.org/|/|g' "$board_conf"
    sed -i 's|https://sys\.4chan\.org/|/|g' "$board_conf"
    sed -i 's|//i\.4cdn\.org/|/images/|g' "$board_conf"
    sed -i 's|^STATIC_REBUILD = .*|STATIC_REBUILD = 0|' "$board_conf"
    sed -i 's|^RENZOKU = .*|RENZOKU = 5|' "$board_conf"
    sed -i 's|^RENZOKU2 = .*|RENZOKU2 = 5|' "$board_conf"
    sed -i 's|^RENZOKU3 = .*|RENZOKU3 = 5|' "$board_conf"
    sed -i 's|^RENZOKU_DUPE = .*|RENZOKU_DUPE = 5|' "$board_conf"
done

# Global strings
sed -i 's|https://sys\.4chan\.org/|/|g' "$SRC/config/global_strings.ini"
sed -i 's|https://www\.4chan\.org/|/|g' "$SRC/config/global_strings.ini"
sed -i 's|https://www\.{{MAIN_DOMAIN}}/|/|g' "$SRC/config/global_strings.ini"
sed -i 's|//www\.{{MAIN_DOMAIN}}/|/|g' "$SRC/config/global_strings.ini"
sed -i 's|https://sys\.{{MAIN_DOMAIN}}/|/|g' "$SRC/config/global_strings.ini"
sed -i 's|//sys\.{{MAIN_DOMAIN}}/|/|g' "$SRC/config/global_strings.ini"
sed -i 's|//v\.4chan\.org/bbs\.php||g' "$SRC/config/global_config.ini"

# Domain constants in lib/util.php
sed -i "s|private static \$blue = '4chan.org'|private static \$blue = 'localhost'|" "$SRC/lib/util.php"
sed -i "s|private static \$red = '4chan.org'|private static \$red = 'localhost'|" "$SRC/lib/util.php"

# Static assets permissions
chown -R www-data:www-data /www/4chan.org/web/static 2>/dev/null || true

# ---------------------------------------------------------------------------
# Patch updating_index() — serve cached static HTML
# ---------------------------------------------------------------------------
php -- <<'PHPEOF'
<?php
$f = file_get_contents('/var/www/html/imgboard.php');
if (strpos($f, '// Lab: serve cached HTML') !== false) {
    echo "[entrypoint] updating_index() already patched, skipping.\n";
    exit;
}
$old = 'function updating_index()
{
	$proto = ( stripos( $_SERVER["HTTP_REFERER"], "https" ) !== false ) ? "https:" : "http:";
	echo';
$new = 'function updating_index()
{
	// Lab: serve cached HTML if available, regenerate if missing
	$gzfile = SELF_PATH2_FILE . ".gz";
	if (file_exists($gzfile)) {
		header("Content-Encoding: gzip");
		readfile($gzfile);
		return;
	}
	$file = SELF_PATH2_FILE;
	if (file_exists($file)) {
		readfile($file);
		return;
	}
	global $mode;
	$prev_mode = $mode;
	$mode = "nothing";
	updatelog(0, 0);
	$mode = $prev_mode;
	if (file_exists($gzfile)) {
		header("Content-Encoding: gzip");
		readfile($gzfile);
		return;
	}
	if (file_exists($file)) {
		readfile($file);
		return;
	}
	$proto = ( stripos( $_SERVER["HTTP_REFERER"], "https" ) !== false ) ? "https:" : "http:";
	echo';$f = str_replace($old, $new, $f, $count);
file_put_contents('/var/www/html/imgboard.php', $f);
echo "[entrypoint] Patched updating_index() ($count replacements).\n";
PHPEOF

# ---------------------------------------------------------------------------
# Patch show_post_successful() — invalidate cached index after post
# ---------------------------------------------------------------------------
php -- <<'PHPEOF'
<?php
$f = file_get_contents('/var/www/html/imgboard.php');
if (strpos($f, '// Lab: invalidate cached index') !== false) {
    echo "[entrypoint] show_post_successful() already patched, skipping.\n";
    exit;
}
$old = 'echo $success;';
$new = '	// Lab: invalidate cached index so next page load regenerates it
	@unlink(SELF_PATH2_FILE . ".gz");
	@unlink(SELF_PATH2_FILE);
	echo $success;';
$f = str_replace($old, $new, $f, $count);
file_put_contents('/var/www/html/imgboard.php', $f);
echo "[entrypoint] Patched show_post_successful() ($count replacements).\n";
PHPEOF

# ---------------------------------------------------------------------------
# Patch fastcgi_finish_request() — guard for mod_php (not PHP-FPM)
# ---------------------------------------------------------------------------
php -- <<'PHPEOF'
<?php
$f = file_get_contents('/var/www/html/imgboard.php');
if (strpos($f, 'function_exists("fastcgi_finish_request")') !== false) {
    echo "[entrypoint] fastcgi_finish_request already patched, skipping.\n";
    exit;
}
$old = 'if ($resto) {
	  fastcgi_finish_request();
	}';
$new = 'if ($resto && function_exists("fastcgi_finish_request")) {
	  fastcgi_finish_request();
	}';
$f = str_replace($old, $new, $f, $count);
$old2 = 'if ($thread_id) {
    fastcgi_finish_request();
  }';
$new2 = 'if ($thread_id && function_exists("fastcgi_finish_request")) {
    fastcgi_finish_request();
  }';
$f = str_replace($old2, $new2, $f, $count2);
file_put_contents('/var/www/html/imgboard.php', $f);
echo "[entrypoint] Patched fastcgi_finish_request ($count + $count2 replacements).\n";
PHPEOF

# ---------------------------------------------------------------------------
# Patch catalog.php — serve cached catalog HTML
# ---------------------------------------------------------------------------
php -- <<'PHPEOF'
<?php
$f = file_get_contents('/var/www/html/catalog.php');
if (strpos($f, '// Lab: serve cached catalog') !== false) {
    echo "[entrypoint] catalog.php already patched, skipping.\n";
    exit;
}
$insert = '

// Lab: serve cached catalog HTML
if (basename($_SERVER["SCRIPT_FILENAME"]) === "catalog.php" || basename($_SERVER["SCRIPT_FILENAME"]) === "catalog-test.php") {
    if (!defined("DATA_ROOT")) {
        $_SERVER["REQUEST_METHOD"] = "GET";
        require_once "yotsuba_config.php";
    }
    $cat_gz = INDEX_DIR . "catalog.html.gz";
    $cat_html = INDEX_DIR . "catalog.html";
    if (file_exists($cat_gz)) {
        header("Content-Encoding: gzip");
        readfile($cat_gz);
        exit;
    }
    if (file_exists($cat_html)) {
        readfile($cat_html);
        exit;
    }
    echo "Catalog not yet generated. Make a post to trigger catalog rebuild.";
    exit;
}
';
$f .= $insert;
file_put_contents('/var/www/html/catalog.php', $f);
echo "[entrypoint] Patched catalog.php serving.\n";
PHPEOF

# ---------------------------------------------------------------------------
# Create board directories with symlinks
# ---------------------------------------------------------------------------
for board_conf in "$SRC/config/boards/"*.config.ini; do
    board=$(basename "$board_conf" .config.ini)
    board_dir="$BOARDS_ROOT/$board"
    mkdir -p "$board_dir" "$board_dir/thread"
    mkdir -p "/www/4chan.org/web/images/$board"
    mkdir -p "/www/4chan.org/web/thumbs/$board"

    for f in imgboard.php catalog.php json.php rid.php; do
        ln -sf "$SRC/$f" "$board_dir/$f"
    done

    for d in config lib views css js modes forms plugins wordfilters imgtop; do
        ln -sf "$SRC/$d" "$board_dir/$d"
    done

    for f in yotsuba_config.php header.txt footer.txt header-sys.txt header-ws.txt \
             footer-ws.txt footer-test.txt header-test.txt globalmsg.txt \
             boardlist.txt captcha.php captcha-test.php catalog.php catalog-test.php \
             json.php json-test.php admin.php admin-test.php auth.php auth-test.php \
             signin.php signin-test.php emotes_xa22.php xa24tb.php derefer.php \
             rebuildd.php rebuildd-test.php clippy.html latest.php; do
        [ -f "$SRC/$f" ] && ln -sf "$SRC/$f" "$board_dir/$f"
    done
done

# ---------------------------------------------------------------------------
# Finalize
# ---------------------------------------------------------------------------
mkdir -p /www/perhost /www/keys
chown -R www-data:www-data /www/perhost /www/4chan.org/web/images /www/4chan.org/web/thumbs /www/4chan.org/web/sys /www/4chan.org/web/boards
echo "ServerName localhost" >> /etc/apache2/apache2.conf

echo "[entrypoint] Boards: $(ls $BOARDS_ROOT | tr '\n' ' ')"

# Start Apache briefly for board init, then restart as PID 1
echo "[entrypoint] Starting Apache for board initialization..."
apache2-foreground &
APACHE_PID=$!
sleep 3

/usr/local/bin/init-boards.sh

# Stop the temporary Apache
kill $APACHE_PID 2>/dev/null
wait $APACHE_PID 2>/dev/null || true

echo "[entrypoint] Initialization complete. Starting Apache..."
exec "$@"
