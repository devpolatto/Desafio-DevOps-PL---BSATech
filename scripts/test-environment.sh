#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

FAILURES=0

pass() { printf "${GREEN}✅ PASS${NC} — %s\n" "$1"; }
fail() { printf "${RED}❌ FAIL${NC} — %s\n" "$1"; FAILURES=$((FAILURES + 1)); }
info() { printf "${YELLOW}   %s${NC}\n" "$1"; }

# --- Checks ---

check_ghost_https() {
    local status
    status=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 10 https://localhost 2>/dev/null || echo "000")
    if [ "$status" = "200" ]; then
        pass "Ghost responde 200 via HTTPS"
    else
        fail "Ghost HTTPS — esperado 200, obtido $status"
        info "Verifique: docker compose logs ghost"
    fi
}

check_http_redirect() {
    local location
    location=$(curl -sI --max-time 10 http://localhost 2>/dev/null | grep -i "^location:" | tr -d '\r\n' || true)
    if echo "$location" | grep -qi "https://localhost"; then
        pass "Redirect HTTP → HTTPS"
    else
        fail "Redirect HTTP → HTTPS — header Location ausente ou incorreto"
        info "Obtido: '$location'"
    fi
}

check_security_headers() {
    local headers
    headers=$(curl -skI --max-time 10 https://localhost 2>/dev/null || true)
    local ok=true

    if echo "$headers" | grep -qi "^strict-transport-security:"; then
        pass "Header Strict-Transport-Security presente"
    else
        fail "Header Strict-Transport-Security ausente"
        ok=false
    fi

    if echo "$headers" | grep -qi "^x-frame-options:"; then
        pass "Header X-Frame-Options presente"
    else
        fail "Header X-Frame-Options ausente"
        ok=false
    fi

    if echo "$headers" | grep -qi "^x-content-type-options:"; then
        pass "Header X-Content-Type-Options presente"
    else
        fail "Header X-Content-Type-Options ausente"
        ok=false
    fi
}

check_mysql() {
    local result
    result=$(docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T mysql \
        mysqladmin ping -uroot -p"${MYSQL_ROOT_PASSWORD}" 2>/dev/null || true)
    if echo "$result" | grep -q "mysqld is alive"; then
        pass "MySQL healthcheck OK"
    else
        fail "MySQL não respondeu ao ping"
        info "Verifique: docker compose logs mysql"
    fi
}

check_prometheus_targets() {
    local response
    response=$(curl -s --max-time 10 http://localhost:9090/api/v1/targets 2>/dev/null || true)

    if [ -z "$response" ]; then
        fail "Prometheus não acessível em localhost:9090"
        return
    fi

    local down_count total_count
    down_count=$(echo "$response" | python3 -c "
import json,sys
data = json.load(sys.stdin)
targets = data.get('data', {}).get('activeTargets', [])
print(sum(1 for t in targets if t['health'] != 'up'))
" 2>/dev/null || echo "error")

    total_count=$(echo "$response" | python3 -c "
import json,sys
data = json.load(sys.stdin)
print(len(data.get('data', {}).get('activeTargets', [])))
" 2>/dev/null || echo "0")

    if [ "$down_count" = "error" ]; then
        fail "Prometheus — não foi possível interpretar resposta"
    elif [ "$down_count" = "0" ]; then
        pass "Prometheus — todos os $total_count targets UP"
    else
        fail "Prometheus — $down_count de $total_count target(s) não estão UP"
        info "Verifique: http://localhost:9090/targets"
    fi
}

check_grafana() {
    local status
    status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://localhost:3000/api/health 2>/dev/null || echo "000")
    if [ "$status" = "200" ]; then
        pass "Grafana acessível (200)"
    else
        fail "Grafana — esperado 200, obtido $status"
        info "Verifique: docker compose logs grafana"
    fi
}

check_volumes() {
    for volume in ghost_data mysql_data; do
        if docker volume inspect "bsatech-blog_${volume}" > /dev/null 2>&1; then
            pass "Volume ${volume} existe"
        else
            fail "Volume ${volume} não encontrado"
        fi
    done
}

# --- Runner ---

echo ""
echo "======================================"
echo "  Smoke Tests — BSATech DevOps Env"
echo "======================================"
echo ""

check_ghost_https
check_http_redirect
check_security_headers
check_mysql
check_prometheus_targets
check_grafana
check_volumes

echo ""
echo "--------------------------------------"
if [ "$FAILURES" -eq 0 ]; then
    printf "${GREEN}✅ Todos os checks passaram.${NC}\n"
    exit 0
else
    printf "${RED}❌ $FAILURES check(s) falharam.${NC}\n"
    exit 1
fi
