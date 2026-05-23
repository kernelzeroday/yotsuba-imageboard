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

# Disable NSFW inference (no external service available)
patch_ini TENSORCHAN_MODE 0

# Local asset serving
patch_ini STATIC_SERVER "/static/"
patch_ini DATA_SERVER "/"
patch_ini PHP_SERVER "/"
patch_ini IMG_SERVER "/images/"
patch_ini THUMB_DIR2 "/thumbs/{{BOARD_DIR}}/"
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
# Keep display_errors off — PHP 8 is strict about undefined vars and the legacy code has many
sed -i 's/display_errors = .*/display_errors = Off/' /usr/local/etc/php/conf.d/yotsuba.ini
sed -i 's/error_reporting = .*/error_reporting = E_ALL \& ~E_NOTICE \& ~E_DEPRECATED \& ~E_STRICT \& ~E_WARNING/' /usr/local/etc/php/conf.d/yotsuba.ini

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

# Category config overrides
for cat_conf in "$SRC/config/categories/"*.config.ini; do
    [ -f "$cat_conf" ] || continue
    sed -i 's|^TENSORCHAN_MODE = .*|TENSORCHAN_MODE = 0|' "$cat_conf"
    sed -i 's|^TENSORCHAN_LOG_ONLY = .*|TENSORCHAN_LOG_ONLY = yes|' "$cat_conf"
done

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
# Patch updating_index() — always render from DB (no static HTML cache)
# ---------------------------------------------------------------------------
php -- <<'PHPEOF'
<?php
$f = '/var/www/html/imgboard.php';
$c = file_get_contents($f);
if (strpos($c, '// Lab: always render from DB') !== false) {
    echo "[entrypoint] updating_index() already patched, skipping.\n";
    exit;
}
$old = 'function updating_index()
{
	echo "<!doctype html>';
$new = 'function updating_index()
{
	// Lab: always render from DB — no static cache, no stale pages
	global $mode;
	$prev_mode = $mode;
	$mode = "nothing";
	updatelog(0, 0);
	$mode = $prev_mode;
	$file = SELF_PATH2_FILE;
	$gzfile = $file . ".gz";
	if (file_exists($gzfile)) {
		header("Content-Encoding: gzip");
		readfile($gzfile);
		@unlink($gzfile);
		return;
	}
	if (file_exists($file)) {
		readfile($file);
		@unlink($file);
		return;
	}
	echo "<!doctype html>';
$c = str_replace($old, $new, $c, $count);
file_put_contents($f, $c);
echo "[entrypoint] Patched updating_index() ($count replacements).\n";
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
# Create board directories with symlinks
# ---------------------------------------------------------------------------
for board_conf in "$SRC/config/boards/"*.config.ini; do
    board=$(basename "$board_conf" .config.ini)
    board_dir="$BOARDS_ROOT/$board"
    mkdir -p "$board_dir" "$board_dir/thread"
    mkdir -p "/www/4chan.org/web/images/$board"
    mkdir -p "/www/4chan.org/web/thumbs/$board"

    for f in imgboard.php catalog.php catalog_serve.php json.php rid.php boards.php; do
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
             rebuildd.php rebuildd-test.php clippy.html latest.php homepage.php infopage.php; do
        [ -f "$SRC/$f" ] && ln -sf "$SRC/$f" "$board_dir/$f"
    done
done

# ---------------------------------------------------------------------------
# Admin auth: create salt file, expand local IP ranges for Docker
# ---------------------------------------------------------------------------
mkdir -p /www/perhost /www/keys
echo -n 'local-lab-salt' > /www/keys/2014_admin.salt
echo -n 'local-lab-enc-key-32bytes!!!!!!!!' > /www/keys/2015_enc.key

# Expand is_local() in admin.php to include Docker bridge networks
php -- <<'PHPEOF'
<?php
foreach (['/var/www/html/admin.php', '/var/www/html/admin-test.php'] as $f) {
    if (!file_exists($f)) continue;
    $c = file_get_contents($f);
    if (strpos($c, '172.16.0.0/12') !== false) continue;
    $c = str_replace(
        'cidrtest( $longip, "127.0.0.0/24" )',
        'cidrtest( $longip, "127.0.0.0/8" ) || cidrtest( $longip, "172.16.0.0/12" ) || cidrtest( $longip, "192.168.0.0/16" )',
        $c
    );
    file_put_contents($f, $c);
    echo "[entrypoint] Patched is_local() in " . basename($f) . "\n";
}

// Disable is_local_auth() — in Docker every request arrives from a local IP,
// which would grant staff privileges to all visitors, bypassing thread locks etc.
foreach (['/var/www/html/lib/auth.php', '/var/www/html/lib/auth-test.php'] as $f) {
    if (!file_exists($f)) continue;
    $c = file_get_contents($f);
    if (strpos($c, 'lab: disabled') !== false) continue;
    // Find the function and replace it entirely (handles nested braces)
    $start = strpos($c, 'function is_local_auth()');
    if ($start === false) continue;
    $brace = strpos($c, '{', $start);
    if ($brace === false) continue;
    $depth = 0;
    $end = $brace;
    for ($i = $brace; $i < strlen($c); $i++) {
        if ($c[$i] === '{') $depth++;
        if ($c[$i] === '}') { $depth--; if ($depth === 0) { $end = $i + 1; break; } }
    }
    $c = substr($c, 0, $start) . "function is_local_auth()\n{\n\treturn false; // lab: disabled\n}" . substr($c, $end);
    file_put_contents($f, $c);
    echo "[entrypoint] Disabled is_local_auth() in " . basename($f) . "\n";
}
PHPEOF

# Patch cookie domain in clear_cookies() and auth — remove .4chan.org domain restriction
php -- <<'PHPEOF'
<?php
foreach (['/var/www/html/lib/admin.php', '/var/www/html/lib/admin-test.php'] as $f) {
    if (!file_exists($f)) continue;
    $c = file_get_contents($f);
    if (strpos($c, '// lab: patched cookie domain') !== false) continue;
    $old = 'function clear_cookies()
{
	if( strstr( $_SERVER["HTTP_HOST"], ".4chan.org" ) ) {
		setcookie( "4chan_auser", "", time() - 3600, "/", ".4chan.org", true );
		setcookie( "4chan_apass", "", time() - 3600, "/", ".4chan.org", true );
		setcookie( "4chan_aflags", "", time() - 3600, "/", ".4chan.org", true );

	} elseif( strstr( $_SERVER["HTTP_HOST"], ".4channel.org" ) ) {
		setcookie( "4chan_auser", "", time() - 24 * 3600, "/", ".4channel.org", true );
		setcookie( "4chan_apass", "", time() - 24 * 3600, "/", ".4channel.org", true );
	} else {
		setcookie( "4chan_auser", "", time() - 24 * 3600, "/", true );
		setcookie( "4chan_apass", "", time() - 24 * 3600, "/", true );
		setcookie( "4chan_aflags", "", time() - 24 * 3600, "/", true );
	}

	setcookie( \'extra_path\', \'\', 1, \'/\', \'.4chan.org\' );
}';
    $new = 'function clear_cookies()
{
	// lab: patched cookie domain
	setcookie( "4chan_auser", "", time() - 3600, "/" );
	setcookie( "4chan_apass", "", time() - 3600, "/" );
	setcookie( "apass", "", time() - 3600, "/" );
	setcookie( "4chan_aflags", "", time() - 3600, "/" );
	setcookie( "extra_path", "", time() - 3600, "/" );
}';
    $c = str_replace($old, $new, $c, $n);
    if ($n) {
        file_put_contents($f, $c);
        echo "[entrypoint] Patched clear_cookies() in " . basename($f) . "\n";
    }
}
PHPEOF

# Add Apache rewrite rules for admin
VHOST=/etc/apache2/sites-enabled/yotsuba.conf
if ! grep -q 'admin\.php' "$VHOST"; then
    sed -i '/RewriteEngine On/a\  RewriteRule ^/admin\\.php$ /b/admin.php [QSA,L]\n  RewriteRule ^/admin$ /b/admin.php [QSA,L]\n  RewriteRule ^/([a-z0-9]+)/admin$ /$1/admin.php [QSA,L]' "$VHOST"
    echo "[entrypoint] Added admin rewrite rules"
fi
# Ensure homepage rewrite is present (not redirect to /b/)
if grep -q 'R=302.*\/b\/' "$VHOST"; then
    sed -i 's|RewriteRule ^/?\$ /b/ \[R=302,L\]|RewriteRule ^/?$ /b/homepage.php [QSA,L]|' "$VHOST"
    echo "[entrypoint] Fixed homepage rewrite (no redirect)"
fi
# Use catalog_serve.php instead of catalog.php for catalog routes
if grep -q 'catalog\.php \[QSA' "$VHOST"; then
    sed -i 's|/catalog /\$1/catalog\.php \[QSA|/catalog /$1/catalog_serve.php [QSA|' "$VHOST"
    sed -i 's|/catalog \$1/catalog\.php \[QSA|/catalog $1/catalog_serve.php [QSA|' "$VHOST"
    echo "[entrypoint] Updated catalog rewrite to use catalog_serve.php"
fi

# ---------------------------------------------------------------------------
# Rebuild title_banners.txt from actual files on disk
# ---------------------------------------------------------------------------
TITLE_DIR="/www/4chan.org/web/static/image/title"
BANNERS_TXT="$SRC/title_banners.txt"
if [ -d "$TITLE_DIR" ]; then
    ls "$TITLE_DIR" > "$BANNERS_TXT"
    cp "$BANNERS_TXT" "/www/4chan.org/web/static/title_banners.txt"
    echo "[entrypoint] Rebuilt title_banners.txt ($(wc -l < "$BANNERS_TXT") banners)"
fi

# ---------------------------------------------------------------------------
# Build contest_banners.json from contest_banners DB table
# ---------------------------------------------------------------------------
CONTEST_JSON="/www/4chan.org/web/static/contest_banners.json"
DB_HOST="${YOTSUBA_DB_HOST:-db}"
DB_USER="${YOTSUBA_DB_USER:-yotsuba}"
DB_PASS="${YOTSUBA_DB_PASS:-yotsuba}"
DB_NAME="${YOTSUBA_DB_NAME:-yotsuba_global}"
if mysql --skip-ssl -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT 1 FROM contest_banners LIMIT 1" >/dev/null 2>&1; then
    mysql --skip-ssl -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -e \
        "SELECT CONCAT('{\"f\":\"', file_name, '\",\"b\":\"', board, '\"}') FROM contest_banners WHERE active=1" \
        | awk 'BEGIN{printf "["} NR>1{printf ","} {printf "%s",$0} END{printf "]\n"}' \
        > "$CONTEST_JSON"
    echo "[entrypoint] Built contest_banners.json ($(python3 -c "import json;print(len(json.load(open('$CONTEST_JSON'))))" 2>/dev/null || echo '?') banners)"
else
    echo "[entrypoint] contest_banners table not ready yet, skipping JSON generation"
fi

# ---------------------------------------------------------------------------
# Finalize
# ---------------------------------------------------------------------------
chown -R www-data:www-data /www/perhost /www/keys /www/4chan.org/web/images /www/4chan.org/web/thumbs /www/4chan.org/web/sys /www/4chan.org/web/boards
echo "ServerName localhost" >> /etc/apache2/apache2.conf

echo "[entrypoint] Boards: $(ls $BOARDS_ROOT | tr '\n' ' ')"

# Start Apache briefly for board init, then restart as PID 1
echo "[entrypoint] Starting Apache for board initialization..."
apache2-foreground &
APACHE_PID=$!

# Wait for DB to be ready
echo "[entrypoint] Waiting for database..."
DB_HOST="${YOTSUBA_DB_HOST:-db}"
DB_USER="${YOTSUBA_DB_USER:-yotsuba}"
DB_PASS="${YOTSUBA_DB_PASS:-yotsuba}"
for i in $(seq 1 30); do
    if mysql --skip-ssl -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" -e "SELECT 1" >/dev/null 2>&1; then
        echo "[entrypoint] Database ready after ${i}s"
        break
    fi
    sleep 1
done

/usr/local/bin/run-migrations.sh
/usr/local/bin/init-boards.sh

# Stop the temporary Apache
kill $APACHE_PID 2>/dev/null
wait $APACHE_PID 2>/dev/null || true

echo "[entrypoint] Initialization complete. Starting Apache..."
exec "$@"
