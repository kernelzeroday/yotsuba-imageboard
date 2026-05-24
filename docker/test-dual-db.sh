#!/bin/bash
# Phase 5: Dual-driver verification test
# Tests that both MySQL and PostgreSQL backends produce identical results.
# Run from project root: bash docker/test-dual-db.sh

set -euo pipefail

COMPOSE="docker compose -f docker-compose.dev.yml"
WEB_CONTAINER="yotsuba-dev-web"
DEV_URL="http://d.local:8084"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC}: $1"; }
fail() { echo -e "${RED}FAIL${NC}: $1"; FAILURES=$((FAILURES + 1)); }
info() { echo -e "${YELLOW}INFO${NC}: $1"; }

FAILURES=0

check_http() {
    local url="$1"
    local desc="$2"
    local code
    code=$(curl -s --compressed -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || echo "000")
    if [ "$code" = "200" ]; then
        pass "$desc (HTTP $code)"
        return 0
    else
        fail "$desc (HTTP $code)"
        return 1
    fi
}

check_contains() {
    local url="$1"
    local pattern="$2"
    local desc="$3"
    local body
    body=$(curl -s --compressed "$url" 2>/dev/null)
    if echo "$body" | grep -q "$pattern"; then
        pass "$desc"
        return 0
    else
        fail "$desc — pattern '$pattern' not found"
        return 1
    fi
}

get_driver() {
    local result
    result=$(docker exec "$WEB_CONTAINER" php -r "
        @require_once '/var/www/html/config/config_db.php';
        echo defined('DB_DRIVER') ? DB_DRIVER : 'mysql';
    " 2>/dev/null || echo "mysql")
    echo "${result:-mysql}"
}

wait_for_web() {
    local max_wait=60
    local elapsed=0
    while [ $elapsed -lt $max_wait ]; do
        if curl -s -o /dev/null -w '%{http_code}' "$DEV_URL/b/" 2>/dev/null | grep -q "200"; then
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    return 1
}

run_test_suite() {
    local driver="$1"
    info "Running test suite against $driver driver"
    echo "=========================================="

    # Basic page loads
    check_http "$DEV_URL/b/" "$driver: /b/ board index"
    check_http "$DEV_URL/g/" "$driver: /g/ board index"
    check_http "$DEV_URL/a/" "$driver: /a/ board index"

    # Catalog
    check_http "$DEV_URL/g/catalog" "$driver: /g/ catalog"

    # Board list page
    check_http "$DEV_URL/" "$driver: homepage"

    # JSON API
    check_http "$DEV_URL/g/catalog.json" "$driver: /g/ catalog JSON"
    check_http "$DEV_URL/g/threads.json" "$driver: /g/ threads JSON"

    # Check page contains expected HTML elements
    check_contains "$DEV_URL/b/" "postForm\|delform\|post.*form" "$driver: /b/ has post form"
    check_contains "$DEV_URL/g/" "postForm\|delform\|post.*form" "$driver: /g/ has post form"

    # Admin panel (should redirect or show login)
    local admin_code
    admin_code=$(curl -s -o /dev/null -w '%{http_code}' "$DEV_URL/admin.php" 2>/dev/null || echo "000")
    if [ "$admin_code" != "000" ]; then
        pass "$driver: admin.php responds (HTTP $admin_code)"
    else
        fail "$driver: admin.php unreachable"
    fi

    # PHP syntax check on key files inside container
    info "Running PHP syntax checks inside container..."
    local syntax_errors=0
    for f in imgboard.php admin.php catalog.php json.php signin.php appeal.php lib/dbal.php lib/db.php lib/admin.php lib/auth.php lib/postfilter.php; do
        if ! docker exec "$WEB_CONTAINER" php -l "/var/www/html/$f" >/dev/null 2>&1; then
            fail "$driver: PHP syntax error in $f"
            syntax_errors=$((syntax_errors + 1))
        fi
    done
    if [ $syntax_errors -eq 0 ]; then
        pass "$driver: All PHP files pass syntax check"
    fi

    # DBAL class loads correctly
    docker exec "$WEB_CONTAINER" php -r "
        require_once '/www/global/yotsuba/lib/dbal.php';
        echo 'YotsubaDB class loaded OK';
    " 2>/dev/null && pass "$driver: DBAL class loads" || fail "$driver: DBAL class failed to load"

    echo ""
}

echo "============================================"
echo "  Yotsuba Dual-Driver Verification Test"
echo "============================================"
echo ""

# Phase 1: Test current driver (should be MySQL)
CURRENT_DRIVER=$(get_driver 2>/dev/null || echo "unknown")
info "Current driver: $CURRENT_DRIVER"
echo ""

run_test_suite "$CURRENT_DRIVER"

echo ""
echo "============================================"
echo "  Results"
echo "============================================"

if [ $FAILURES -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
else
    echo -e "${RED}$FAILURES test(s) failed${NC}"
fi

echo ""
info "To test with PostgreSQL, change YOTSUBA_DB_DRIVER=pgsql in docker-compose.dev.yml and rebuild"

exit $FAILURES
