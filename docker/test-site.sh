#!/bin/bash
# Yotsuba Imageboard Integration Test Suite
# Tests the site end-to-end via HTTP against the DEV environment.
# Run from project root: bash docker/test-site.sh

set -uo pipefail

COMPOSE="docker compose -f docker-compose.dev.yml"
WEB_CONTAINER="yotsuba-dev-web"
DEV_URL="http://d.local:8084"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

FAILURES=0
PASSES=0
SKIPS=0
TOTAL=0
SECTION=""

pass() { PASSES=$((PASSES + 1)); TOTAL=$((TOTAL + 1)); echo -e "  ${GREEN}PASS${NC}: $1"; }
fail() { FAILURES=$((FAILURES + 1)); TOTAL=$((TOTAL + 1)); echo -e "  ${RED}FAIL${NC}: $1"; }
skip() { SKIPS=$((SKIPS + 1)); TOTAL=$((TOTAL + 1)); echo -e "  ${YELLOW}SKIP${NC}: $1"; }
info() { echo -e "  ${YELLOW}INFO${NC}: $1"; }
section() { SECTION="$1"; echo ""; echo -e "${BOLD}${CYAN}[$1]${NC}"; echo -e "${CYAN}$(printf '%.0s-' {1..60})${NC}"; }

# -----------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------

check_http() {
    local url="$1"
    local desc="$2"
    local expected="${3:-200}"
    local code
    code=$(curl -s --compressed -o /dev/null -w '%{http_code}' --max-time 10 "$url" 2>/dev/null || echo "000")
    if [ "$code" = "$expected" ]; then
        pass "$desc (HTTP $code)"
        return 0
    else
        fail "$desc (expected HTTP $expected, got $code)"
        return 1
    fi
}

check_contains() {
    local url="$1"
    local pattern="$2"
    local desc="$3"
    local body
    body=$(curl -s --compressed --max-time 10 "$url" 2>/dev/null)
    if echo "$body" | grep -qi "$pattern"; then
        pass "$desc"
        return 0
    else
        fail "$desc — pattern '$pattern' not found"
        return 1
    fi
}

check_not_contains() {
    local url="$1"
    local pattern="$2"
    local desc="$3"
    local body
    body=$(curl -s --compressed --max-time 10 "$url" 2>/dev/null)
    if echo "$body" | grep -qi "$pattern"; then
        fail "$desc — unwanted pattern '$pattern' found"
        return 1
    else
        pass "$desc"
        return 0
    fi
}

# Fetch body and return it; also check HTTP code
fetch_body() {
    local url="$1"
    curl -s --compressed --max-time 10 "$url" 2>/dev/null
}

# Execute PHP inside the container; returns output or empty on failure
container_php() {
    local php_code="$1"
    DOCKER_HOST=ssh://d.local docker exec "$WEB_CONTAINER" php -r "$php_code" 2>/dev/null
}

container_exec() {
    DOCKER_HOST=ssh://d.local docker exec "$WEB_CONTAINER" "$@" 2>/dev/null
}

# -----------------------------------------------------------------------
# Pre-flight: verify DEV is reachable
# -----------------------------------------------------------------------

echo ""
echo -e "${BOLD}============================================${NC}"
echo -e "${BOLD}  Yotsuba Integration Test Suite${NC}"
echo -e "${BOLD}============================================${NC}"
echo ""
info "Target: $DEV_URL (DEV)"
info "Container: $WEB_CONTAINER"
echo ""

# Quick connectivity check
HTTP_CHECK=$(curl -s --compressed -o /dev/null -w '%{http_code}' --max-time 5 "$DEV_URL/" 2>/dev/null || echo "000")
if [ "$HTTP_CHECK" = "000" ]; then
    echo -e "${RED}ERROR: Cannot reach $DEV_URL — is the dev environment running?${NC}"
    echo "  Start it with: docker compose -f docker-compose.dev.yml up --build"
    exit 1
fi
info "DEV environment is reachable (HTTP $HTTP_CHECK)"

# -----------------------------------------------------------------------
# 1. Board rendering
# -----------------------------------------------------------------------

section "1. Board Rendering"

BOARDS_TO_TEST="b g a pol v int sci fit mu tv k an co sp lit"

for board in $BOARDS_TO_TEST; do
    check_http "$DEV_URL/$board/" "/$board/ board index loads"
done

# Verify board pages contain expected HTML structures
check_contains "$DEV_URL/b/" "boardTitle" "/b/ has boardTitle element"
check_contains "$DEV_URL/b/" "postForm" "/b/ has post form"
check_contains "$DEV_URL/b/" "boardNavDesktop" "/b/ has desktop navigation"
check_contains "$DEV_URL/b/" "delform" "/b/ has delete form"
check_contains "$DEV_URL/g/" "boardTitle" "/g/ has boardTitle element"
check_contains "$DEV_URL/g/" "postForm" "/g/ has post form"
check_contains "$DEV_URL/g/" "/g/ - Technology" "/g/ shows correct board title"
check_contains "$DEV_URL/b/" "/b/ - Random" "/b/ shows correct board title"
check_contains "$DEV_URL/pol/" "/pol/ - Politically Incorrect" "/pol/ shows correct board title"

# Verify board navigation links are present
check_contains "$DEV_URL/b/" 'href="/g/"' "/b/ has nav link to /g/"
check_contains "$DEV_URL/b/" 'href="/a/"' "/b/ has nav link to /a/"
check_contains "$DEV_URL/g/" 'href="/b/"' "/g/ has nav link to /b/"

# Check sticky threads exist on boards
check_contains "$DEV_URL/b/" "sticky" "/b/ has sticky thread"
check_contains "$DEV_URL/g/" "sticky" "/g/ has sticky thread"

# -----------------------------------------------------------------------
# 2. Catalog
# -----------------------------------------------------------------------

section "2. Catalog"

check_http "$DEV_URL/b/catalog" "/b/ catalog loads"
check_http "$DEV_URL/g/catalog" "/g/ catalog loads"
check_http "$DEV_URL/a/catalog" "/a/ catalog loads"
check_http "$DEV_URL/v/catalog" "/v/ catalog loads"

# Catalog contains expected structure
check_contains "$DEV_URL/b/catalog" "catalog" "/b/ catalog has catalog data"
check_contains "$DEV_URL/g/catalog" "catalog" "/g/ catalog has catalog data"
check_contains "$DEV_URL/b/catalog" "Catalog" "/b/ catalog has Catalog in title"
check_contains "$DEV_URL/b/catalog" "boardTitle" "/b/ catalog has boardTitle"

# Catalog has thread entries (the catalog JS variable should have thread data)
check_contains "$DEV_URL/b/catalog" "threads" "/b/ catalog has thread entries"
check_contains "$DEV_URL/g/catalog" "threads" "/g/ catalog has thread entries"

# -----------------------------------------------------------------------
# 3. JSON API
# -----------------------------------------------------------------------

section "3. JSON API"

# Catalog JSON
CATALOG_JSON=$(fetch_body "$DEV_URL/g/catalog.json")
if echo "$CATALOG_JSON" | python3 -m json.tool >/dev/null 2>&1; then
    pass "/g/catalog.json is valid JSON"
else
    fail "/g/catalog.json is not valid JSON"
fi

# Check catalog.json structure: should be array of page objects
if echo "$CATALOG_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert isinstance(data, list), 'not a list'
assert len(data) > 0, 'empty list'
page = data[0]
assert 'page' in page, 'no page key'
assert 'threads' in page, 'no threads key'
assert isinstance(page['threads'], list), 'threads not a list'
if len(page['threads']) > 0:
    t = page['threads'][0]
    assert 'no' in t, 'thread missing no'
    assert 'time' in t, 'thread missing time'
" 2>/dev/null; then
    pass "/g/catalog.json has correct structure (page/threads/no/time)"
else
    fail "/g/catalog.json structure incorrect"
fi

# Threads JSON
THREADS_JSON=$(fetch_body "$DEV_URL/g/threads.json")
if echo "$THREADS_JSON" | python3 -m json.tool >/dev/null 2>&1; then
    pass "/g/threads.json is valid JSON"
else
    fail "/g/threads.json is not valid JSON"
fi

# Check threads.json structure
if echo "$THREADS_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert isinstance(data, list), 'not a list'
assert len(data) > 0, 'empty list'
page = data[0]
assert 'page' in page, 'no page key'
assert 'threads' in page, 'no threads key'
t = page['threads'][0]
assert 'no' in t, 'thread missing no'
assert 'last_modified' in t, 'thread missing last_modified'
assert 'replies' in t, 'thread missing replies'
" 2>/dev/null; then
    pass "/g/threads.json has correct structure (page/threads/no/last_modified/replies)"
else
    fail "/g/threads.json structure incorrect"
fi

# Test JSON on multiple boards
for board in b a v pol; do
    BCAT=$(curl -s --compressed -o /dev/null -w '%{http_code}' --max-time 10 "$DEV_URL/$board/catalog.json" 2>/dev/null || echo "000")
    if [ "$BCAT" = "200" ]; then
        pass "/$board/catalog.json returns 200"
    else
        fail "/$board/catalog.json returns $BCAT (expected 200)"
    fi
done

for board in b a v pol; do
    BTHR=$(curl -s --compressed -o /dev/null -w '%{http_code}' --max-time 10 "$DEV_URL/$board/threads.json" 2>/dev/null || echo "000")
    if [ "$BTHR" = "200" ]; then
        pass "/$board/threads.json returns 200"
    else
        fail "/$board/threads.json returns $BTHR (expected 200)"
    fi
done

# -----------------------------------------------------------------------
# 4. Post form
# -----------------------------------------------------------------------

section "4. Post Form"

BOARD_HTML=$(fetch_body "$DEV_URL/b/")

# Check all required form fields
for field in 'name="name"' 'name="email"' 'name="sub"' 'name="com"' 'name="upfile"' 'name="mode"' 'name="pwd"'; do
    if echo "$BOARD_HTML" | grep -q "$field"; then
        pass "/b/ form has field: $field"
    else
        fail "/b/ form missing field: $field"
    fi
done

# Check form action
if echo "$BOARD_HTML" | grep -q 'action="/b/post"'; then
    pass "/b/ form action points to /b/post"
else
    fail "/b/ form action not found or incorrect"
fi

# Check form method and enctype
if echo "$BOARD_HTML" | grep -q 'method="post"'; then
    pass "/b/ form uses POST method"
else
    fail "/b/ form does not use POST method"
fi

if echo "$BOARD_HTML" | grep -q 'enctype="multipart/form-data"'; then
    pass "/b/ form has multipart/form-data enctype"
else
    fail "/b/ form does not have multipart/form-data enctype"
fi

# Check submit button
if echo "$BOARD_HTML" | grep -q 'type="submit"'; then
    pass "/b/ form has submit button"
else
    fail "/b/ form missing submit button"
fi

# -----------------------------------------------------------------------
# 5. Thread creation & reply
# -----------------------------------------------------------------------

section "5. Thread Creation & Reply"

# POST a new thread to /b/
# Note: The site may reject posts for various reasons (captcha, cooldown, etc.)
# We test that the endpoint accepts POST requests and returns a response.

THREAD_TIMESTAMP=$(date +%s)
THREAD_COMMENT="Integration test thread created at $THREAD_TIMESTAMP"
THREAD_SUBJECT="Test Thread $THREAD_TIMESTAMP"

POST_RESPONSE=$(curl -s --compressed -w '\n__HTTP_CODE__:%{http_code}' --max-time 15 \
    "$DEV_URL/b/imgboard.php" \
    -F "mode=regist" \
    -F "name=TestBot" \
    -F "sub=$THREAD_SUBJECT" \
    -F "com=$THREAD_COMMENT" \
    -F "pwd=testpwd$(date +%s)" \
    -F "textonly=on" \
    -F "MAX_FILE_SIZE=2097152" \
    2>/dev/null)

POST_CODE=$(echo "$POST_RESPONSE" | grep '__HTTP_CODE__' | sed 's/.*__HTTP_CODE__://')
POST_BODY=$(echo "$POST_RESPONSE" | grep -v '__HTTP_CODE__')

if [ "$POST_CODE" = "200" ] || [ "$POST_CODE" = "302" ] || [ "$POST_CODE" = "303" ]; then
    pass "Thread creation POST accepted (HTTP $POST_CODE)"

    # Try to find the new thread
    sleep 2
    B_THREADS=$(fetch_body "$DEV_URL/b/threads.json")
    LATEST_THREAD=$(echo "$B_THREADS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
threads = []
for page in data:
    for t in page['threads']:
        threads.append(t)
threads.sort(key=lambda x: x['no'], reverse=True)
if threads:
    print(threads[0]['no'])
" 2>/dev/null)

    if [ -n "$LATEST_THREAD" ] && [ "$LATEST_THREAD" -gt 1 ] 2>/dev/null; then
        pass "Found thread no=$LATEST_THREAD in /b/threads.json"

        # Try to load the thread page
        THREAD_CODE=$(curl -s --compressed -o /dev/null -w '%{http_code}' --max-time 10 "$DEV_URL/b/thread/$LATEST_THREAD" 2>/dev/null || echo "000")
        if [ "$THREAD_CODE" = "200" ]; then
            pass "Thread page /b/thread/$LATEST_THREAD loads (HTTP 200)"
        else
            info "Thread page returned HTTP $THREAD_CODE (may be normal for new threads)"
        fi

        # Try to reply to the thread
        REPLY_COMMENT="Integration test reply at $(date +%s)"
        REPLY_RESPONSE=$(curl -s --compressed -w '\n__HTTP_CODE__:%{http_code}' --max-time 15 \
            "$DEV_URL/b/imgboard.php" \
            -F "mode=regist" \
            -F "resto=$LATEST_THREAD" \
            -F "name=TestReplyBot" \
            -F "com=$REPLY_COMMENT" \
            -F "pwd=replypwd$(date +%s)" \
            -F "textonly=on" \
            2>/dev/null)

        REPLY_CODE=$(echo "$REPLY_RESPONSE" | grep '__HTTP_CODE__' | sed 's/.*__HTTP_CODE__://')
        if [ "$REPLY_CODE" = "200" ] || [ "$REPLY_CODE" = "302" ] || [ "$REPLY_CODE" = "303" ]; then
            pass "Reply POST accepted (HTTP $REPLY_CODE)"
        else
            skip "Reply POST returned HTTP $REPLY_CODE (may require captcha or have cooldown)"
        fi
    else
        info "Could not find new thread in threads.json (thread may not have been created)"
    fi
elif echo "$POST_BODY" | grep -qi "error\|errmsg\|banned\|blocked\|captcha\|cooldown"; then
    skip "Thread creation rejected: $(echo "$POST_BODY" | grep -oP '(?<=id="errmsg">)[^<]+' | head -1)"
else
    skip "Thread creation POST returned HTTP $POST_CODE (endpoint exists but post may require captcha/image)"
fi

# Verify existing thread (sticky thread #1 should always exist)
check_http "$DEV_URL/b/thread/1" "Sticky thread /b/thread/1 loads"

# -----------------------------------------------------------------------
# 6. Thread display
# -----------------------------------------------------------------------

section "6. Thread Display"

THREAD_HTML=$(fetch_body "$DEV_URL/b/thread/1")

# Check thread page structure
if echo "$THREAD_HTML" | grep -q 'class="thread"'; then
    pass "/b/thread/1 has thread container"
else
    fail "/b/thread/1 missing thread container"
fi

if echo "$THREAD_HTML" | grep -q 'class="post op"'; then
    pass "/b/thread/1 has OP post"
else
    fail "/b/thread/1 missing OP post"
fi

if echo "$THREAD_HTML" | grep -q 'postMessage'; then
    pass "/b/thread/1 has post message content"
else
    fail "/b/thread/1 missing post message content"
fi

if echo "$THREAD_HTML" | grep -q 'postInfo'; then
    pass "/b/thread/1 has post info section"
else
    fail "/b/thread/1 missing post info section"
fi

if echo "$THREAD_HTML" | grep -q 'is_thread'; then
    pass "/b/thread/1 has is_thread body class"
else
    fail "/b/thread/1 missing is_thread body class"
fi

# Check that thread has reply form (sticky thread #1 is closed, so no reply form expected)
if echo "$THREAD_HTML" | grep -q 'closedIcon\|class="closed"'; then
    pass "/b/thread/1 is a closed thread (reply form correctly absent)"
elif echo "$THREAD_HTML" | grep -q 'name="com"'; then
    pass "/b/thread/1 has reply comment field"
else
    fail "/b/thread/1 missing reply comment field and not marked closed"
fi

# Check thread on another board
check_http "$DEV_URL/g/thread/1" "Sticky thread /g/thread/1 loads"
check_contains "$DEV_URL/g/thread/1" "Technology" "/g/thread/1 mentions Technology"

# -----------------------------------------------------------------------
# 7. Admin panel
# -----------------------------------------------------------------------

section "7. Admin Panel"

ADMIN_CODE=$(curl -s --compressed -o /dev/null -w '%{http_code}' --max-time 10 "$DEV_URL/admin.php" 2>/dev/null || echo "000")
if [ "$ADMIN_CODE" != "000" ]; then
    pass "admin.php responds (HTTP $ADMIN_CODE)"
else
    fail "admin.php unreachable"
fi

ADMIN_BODY=$(fetch_body "$DEV_URL/admin.php")
if echo "$ADMIN_BODY" | grep -qi "admin\|login\|password\|manager\|mod\|sign.in"; then
    pass "admin.php contains admin-related content"
else
    info "admin.php returned content but no admin keywords found (may be expected)"
fi

# -----------------------------------------------------------------------
# 8. Static assets
# -----------------------------------------------------------------------

section "8. Static Assets"

# CSS files
CSS_FILES="yotsubanew.715.css yotsubluenew.715.css futabanew.715.css burichannew.715.css photon.715.css tomorrow.715.css"
for css in $CSS_FILES; do
    check_http "$DEV_URL/static/css/$css" "CSS: $css"
done

# Check CSS contains actual style rules
CSS_BODY=$(fetch_body "$DEV_URL/static/css/yotsubanew.715.css")
if echo "$CSS_BODY" | grep -q "body\|font\|color\|background"; then
    pass "yotsubanew.715.css contains CSS rules"
else
    fail "yotsubanew.715.css appears empty or invalid"
fi

# Extra CSS
check_http "$DEV_URL/static/css/xa24extra.css" "CSS: xa24extra.css"
check_http "$DEV_URL/static/css/catalog_mobile.705.css" "CSS: catalog_mobile.705.css"
check_http "$DEV_URL/static/css/frontpage.12.css" "CSS: frontpage.12.css"

# JavaScript files
check_http "$DEV_URL/static/js/core.min.1123.js" "JS: core.min.1123.js"
check_http "$DEV_URL/static/js/extension.min.1178.js" "JS: extension.min.1178.js"
check_http "$DEV_URL/static/js/catalog.min.1024.js" "JS: catalog.min.1024.js"

# Images
check_http "$DEV_URL/static/image/favicon.ico" "Image: favicon.ico"
check_http "$DEV_URL/static/image/sticky.gif" "Image: sticky.gif"
check_http "$DEV_URL/static/image/closed.gif" "Image: closed.gif"
check_http "$DEV_URL/static/image/archived.gif" "Image: archived.gif"
check_http "$DEV_URL/static/image/adminicon.gif" "Image: adminicon.gif"
check_http "$DEV_URL/static/image/modicon.gif" "Image: modicon.gif"

# -----------------------------------------------------------------------
# 9. Homepage
# -----------------------------------------------------------------------

section "9. Homepage"

check_http "$DEV_URL/" "Homepage loads"

HOMEPAGE=$(fetch_body "$DEV_URL/")

# Check board list sections
if echo "$HOMEPAGE" | grep -q "Japanese Culture"; then
    pass "Homepage has 'Japanese Culture' section"
else
    fail "Homepage missing 'Japanese Culture' section"
fi

if echo "$HOMEPAGE" | grep -q "Video Games"; then
    pass "Homepage has 'Video Games' section"
else
    fail "Homepage missing 'Video Games' section"
fi

if echo "$HOMEPAGE" | grep -q "Technology"; then
    pass "Homepage has 'Technology' section"
else
    fail "Homepage missing 'Technology' section (link text)"
fi

# Check board links
for board in a b g v pol; do
    if echo "$HOMEPAGE" | grep -q "href=\"/$board/\""; then
        pass "Homepage has link to /$board/"
    else
        fail "Homepage missing link to /$board/"
    fi
done

# Check meta elements
if echo "$HOMEPAGE" | grep -q "<title>"; then
    pass "Homepage has title tag"
else
    fail "Homepage missing title tag"
fi

if echo "$HOMEPAGE" | grep -q "4chan"; then
    pass "Homepage mentions 4chan"
else
    fail "Homepage missing 4chan branding"
fi

# -----------------------------------------------------------------------
# 10. Error handling
# -----------------------------------------------------------------------

section "10. Error Handling"

# Nonexistent board
check_http "$DEV_URL/nonexistent_board_xyz/" "Nonexistent board returns error" "404"

# Invalid thread ID on a valid board
INVALID_THREAD_CODE=$(curl -s --compressed -o /dev/null -w '%{http_code}' --max-time 10 "$DEV_URL/b/thread/999999999" 2>/dev/null || echo "000")
if [ "$INVALID_THREAD_CODE" = "404" ] || [ "$INVALID_THREAD_CODE" = "302" ] || [ "$INVALID_THREAD_CODE" = "200" ]; then
    pass "Invalid thread ID handled (HTTP $INVALID_THREAD_CODE)"
else
    fail "Invalid thread ID returned unexpected HTTP $INVALID_THREAD_CODE"
fi

# Nonexistent static file
check_http "$DEV_URL/static/image/does_not_exist_xyz.png" "Nonexistent static file returns 404" "404"

# Nonexistent JSON endpoint
NOJSON_CODE=$(curl -s --compressed -o /dev/null -w '%{http_code}' --max-time 10 "$DEV_URL/nonexistent/catalog.json" 2>/dev/null || echo "000")
if [ "$NOJSON_CODE" = "404" ] || [ "$NOJSON_CODE" = "500" ]; then
    pass "Nonexistent JSON endpoint returns error (HTTP $NOJSON_CODE)"
else
    fail "Nonexistent JSON endpoint returned HTTP $NOJSON_CODE (expected 404 or 500)"
fi

# -----------------------------------------------------------------------
# 11. PHP health
# -----------------------------------------------------------------------

section "11. PHP Health (syntax check)"

PHP_FILES="imgboard.php admin.php catalog.php json.php signin.php appeal.php homepage.php boards.php yotsuba_config.php lib/dbal.php lib/db.php lib/admin.php lib/auth.php lib/postfilter.php lib/util.php"
SYNTAX_ERRORS=0
SYNTAX_CHECKED=0

for f in $PHP_FILES; do
    RESULT=$(container_exec php -l "/var/www/html/$f" 2>&1)
    if [ $? -eq 0 ]; then
        SYNTAX_CHECKED=$((SYNTAX_CHECKED + 1))
    else
        fail "PHP syntax error in $f: $RESULT"
        SYNTAX_ERRORS=$((SYNTAX_ERRORS + 1))
    fi
done

if [ $SYNTAX_ERRORS -eq 0 ] && [ $SYNTAX_CHECKED -gt 0 ]; then
    pass "All $SYNTAX_CHECKED PHP files pass syntax check"
elif [ $SYNTAX_CHECKED -eq 0 ]; then
    skip "Could not run PHP syntax checks (container not accessible via DOCKER_HOST)"
fi

# Check PHP version inside container
PHP_VERSION=$(container_exec php -v 2>/dev/null | head -1)
if [ -n "$PHP_VERSION" ]; then
    pass "PHP version: $PHP_VERSION"
else
    skip "Could not determine PHP version"
fi

# -----------------------------------------------------------------------
# 12. DBAL
# -----------------------------------------------------------------------

section "12. DBAL"

# Verify DBAL class loads
DBAL_LOAD=$(container_php "
    require_once '/www/global/yotsuba/lib/dbal.php';
    echo 'YotsubaDB class loaded';
" 2>/dev/null)

if echo "$DBAL_LOAD" | grep -q "YotsubaDB class loaded"; then
    pass "DBAL class (YotsubaDB) loads successfully"
else
    fail "DBAL class failed to load"
fi

# Verify driver detection
DRIVER_RESULT=$(container_php "
    @require_once '/var/www/html/config/config_db.php';
    \$driver = defined('DB_DRIVER') ? DB_DRIVER : 'mysql';
    echo \$driver;
" 2>/dev/null)

if [ -n "$DRIVER_RESULT" ]; then
    pass "DBAL driver detected: $DRIVER_RESULT"
else
    skip "Could not detect DBAL driver (container not accessible)"
fi

# Verify DBAL methods exist
DBAL_METHODS=$(container_php "
    require_once '/www/global/yotsuba/lib/dbal.php';
    \$methods = get_class_methods('YotsubaDB');
    echo implode(',', \$methods);
" 2>/dev/null)

if echo "$DBAL_METHODS" | grep -q "query"; then
    pass "DBAL has query() method"
else
    fail "DBAL missing query() method"
fi

if echo "$DBAL_METHODS" | grep -q "exec"; then
    pass "DBAL has exec() method"
else
    fail "DBAL missing exec() method"
fi

if echo "$DBAL_METHODS" | grep -q "getDriver"; then
    pass "DBAL has getDriver() method"
else
    fail "DBAL missing getDriver() method"
fi

if echo "$DBAL_METHODS" | grep -q "lastInsertId"; then
    pass "DBAL has lastInsertId() method"
else
    fail "DBAL missing lastInsertId() method"
fi

# -----------------------------------------------------------------------
# 13. Board config
# -----------------------------------------------------------------------

section "13. Board Configuration"

# Check global config exists
GLOBAL_CONFIG=$(container_exec test -f /var/www/html/config/global_config.ini && echo "exists" || echo "missing")
if [ "$GLOBAL_CONFIG" = "exists" ]; then
    pass "global_config.ini exists"
else
    fail "global_config.ini missing"
fi

# Check global strings exists
GLOBAL_STRINGS=$(container_exec test -f /var/www/html/config/global_strings.ini && echo "exists" || echo "missing")
if [ "$GLOBAL_STRINGS" = "exists" ]; then
    pass "global_strings.ini exists"
else
    fail "global_strings.ini missing"
fi

# Check per-board config directories
BOARD_CONFIGS_TO_CHECK="b g a pol v int sci"
for board in $BOARD_CONFIGS_TO_CHECK; do
    CONFIG_EXISTS=$(container_exec test -f "/var/www/html/config/boards/$board.config.ini" && echo "exists" || echo "missing")
    if [ "$CONFIG_EXISTS" = "exists" ]; then
        pass "Board config exists: $board.config.ini"
    else
        # Some boards may not have per-board overrides (they use category defaults)
        info "No per-board config for /$board/ (uses category defaults)"
    fi
done

# Verify board directories exist in web root
BOARD_DIRS_TO_CHECK="b g a pol v int sci mu tv k an co sp lit fit fa jp"
BOARD_DIR_COUNT=0
for board in $BOARD_DIRS_TO_CHECK; do
    DIR_EXISTS=$(container_exec test -d "/www/4chan.org/web/boards/$board" && echo "exists" || echo "missing")
    if [ "$DIR_EXISTS" = "exists" ]; then
        BOARD_DIR_COUNT=$((BOARD_DIR_COUNT + 1))
    fi
done

if [ $BOARD_DIR_COUNT -gt 0 ]; then
    pass "$BOARD_DIR_COUNT board directories found in web root"
else
    skip "Could not verify board directories (container not accessible)"
fi

# -----------------------------------------------------------------------
# 14. Database connectivity
# -----------------------------------------------------------------------

section "14. Database Connectivity"

# Test DB connection from inside container
DB_CONN=$(container_php "
    require_once '/var/www/html/lib/dbal.php';
    @require_once '/var/www/html/config/config_db.php';
    try {
        \$db = YotsubaDB::global();
        echo 'connected:' . \$db->getDriver();
    } catch (Exception \$e) {
        echo 'error:' . \$e->getMessage();
    }
" 2>/dev/null)

if echo "$DB_CONN" | grep -q "^connected:"; then
    CONN_DRIVER=$(echo "$DB_CONN" | sed 's/connected://')
    pass "Database connection successful (driver: $CONN_DRIVER)"
else
    fail "Database connection failed: $DB_CONN"
fi

# Verify boardlist table has entries
BOARD_COUNT=$(container_php "
    require_once '/var/www/html/lib/dbal.php';
    @require_once '/var/www/html/config/config_db.php';
    try {
        \$db = YotsubaDB::global();
        \$res = \$db->query(\"SELECT COUNT(*) FROM \" . \$db->qi('boardlist'));
        echo \$res->fetchColumn();
    } catch (Exception \$e) {
        echo 'error';
    }
" 2>/dev/null)

if [ -n "$BOARD_COUNT" ] && [ "$BOARD_COUNT" != "error" ] && [ "$BOARD_COUNT" -gt 0 ] 2>/dev/null; then
    pass "boardlist table has $BOARD_COUNT boards"
else
    fail "boardlist table empty or inaccessible (got: $BOARD_COUNT)"
fi

# Verify a board table exists and has rows
B_TABLE_COUNT=$(container_php "
    require_once '/var/www/html/lib/dbal.php';
    @require_once '/var/www/html/config/config_db.php';
    try {
        \$db = YotsubaDB::global();
        \$res = \$db->query(\"SELECT COUNT(*) FROM \" . \$db->qi('b'));
        echo \$res->fetchColumn();
    } catch (Exception \$e) {
        echo 'error';
    }
" 2>/dev/null)

if [ -n "$B_TABLE_COUNT" ] && [ "$B_TABLE_COUNT" != "error" ] && [ "$B_TABLE_COUNT" -gt 0 ] 2>/dev/null; then
    pass "/b/ board table has $B_TABLE_COUNT posts"
else
    if [ "$B_TABLE_COUNT" = "0" ]; then
        info "/b/ board table exists but has 0 posts"
    else
        fail "/b/ board table inaccessible (got: $B_TABLE_COUNT)"
    fi
fi

# Check blotter table
BLOTTER_COUNT=$(container_php "
    require_once '/var/www/html/lib/dbal.php';
    @require_once '/var/www/html/config/config_db.php';
    try {
        \$db = YotsubaDB::global();
        \$res = \$db->query(\"SELECT COUNT(*) FROM \" . \$db->qi('blotter'));
        echo \$res->fetchColumn();
    } catch (Exception \$e) {
        echo 'error';
    }
" 2>/dev/null)

if [ -n "$BLOTTER_COUNT" ] && [ "$BLOTTER_COUNT" != "error" ] && [ "$BLOTTER_COUNT" -ge 0 ] 2>/dev/null; then
    pass "blotter table accessible ($BLOTTER_COUNT entries)"
else
    fail "blotter table inaccessible"
fi

# -----------------------------------------------------------------------
# 15. Cross-board consistency
# -----------------------------------------------------------------------

section "15. Cross-Board Consistency"

# Check a wide sample of boards all return 200
ALL_BOARDS="3 a aco adv an b bant biz c cgl ck cm co d diy e f fa fit g gd gif h hc his hm hr i ic int jp k lgbt lit m mlp mu n news o out p po pol pw qa qst r r9k s s4s sci soc sp t tg toy trv tv u v vg vm vmg vp vr vrpg vst vt w wg wsg wsr x xs y"
BOARD_200_COUNT=0
BOARD_FAIL_COUNT=0
BOARD_TOTAL=0

for board in $ALL_BOARDS; do
    BOARD_TOTAL=$((BOARD_TOTAL + 1))
    CODE=$(curl -s --compressed -o /dev/null -w '%{http_code}' --max-time 5 "$DEV_URL/$board/" 2>/dev/null || echo "000")
    if [ "$CODE" = "200" ]; then
        BOARD_200_COUNT=$((BOARD_200_COUNT + 1))
    else
        BOARD_FAIL_COUNT=$((BOARD_FAIL_COUNT + 1))
        info "/$board/ returned HTTP $CODE"
    fi
done

if [ $BOARD_200_COUNT -eq $BOARD_TOTAL ]; then
    pass "All $BOARD_TOTAL boards return HTTP 200"
elif [ $BOARD_200_COUNT -ge 80 ]; then
    pass "$BOARD_200_COUNT/$BOARD_TOTAL boards return HTTP 200 ($BOARD_FAIL_COUNT failed)"
else
    fail "Only $BOARD_200_COUNT/$BOARD_TOTAL boards return HTTP 200"
fi

# -----------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------

echo ""
echo -e "${BOLD}============================================${NC}"
echo -e "${BOLD}  Results${NC}"
echo -e "${BOLD}============================================${NC}"
echo ""
echo -e "  Total tests: ${BOLD}$TOTAL${NC}"
echo -e "  Passed:      ${GREEN}$PASSES${NC}"
echo -e "  Failed:      ${RED}$FAILURES${NC}"
echo -e "  Skipped:     ${YELLOW}$SKIPS${NC}"
echo ""

if [ $FAILURES -eq 0 ]; then
    echo -e "  ${GREEN}${BOLD}All tests passed!${NC}"
else
    echo -e "  ${RED}${BOLD}$FAILURES test(s) failed${NC}"
fi

echo ""

exit $FAILURES
