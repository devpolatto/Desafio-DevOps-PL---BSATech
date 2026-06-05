#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ALERTMANAGER_URL="http://localhost:9093"
STOPPED_SERVICES_FILE="/tmp/bsatech-stopped-services"

usage() {
    cat <<EOF
Usage: $0 <command> [args]

Commands:
  disk              Inject DiskSpaceHigh alert via AlertManager API
  service <name>    Stop a Docker service to trigger an alert
  cleanup           Resolve injected alerts and restart stopped services

Services and the alerts they trigger when stopped:
  mysql             → MySQLDown        (mysql_up == 0, fires in ~30s)
  mysql-exporter    → ServiceDown      (up == 0, fires in ~1m)
  node-exporter     → ServiceDown      (up == 0, fires in ~1m)
  cadvisor          → ServiceDown      (up == 0, fires in ~1m)

Note: ghost, nginx, grafana and alertmanager are not Prometheus scrape targets
and will NOT trigger any alert when stopped.

Note: 'disk' uses AlertManager API injection because filling a large physical
disk to 80% is impractical in most environments. The 'service' command stops
the container for real and Prometheus detects it naturally.
EOF
    exit 1
}

check_alertmanager() {
    if ! curl -sf "$ALERTMANAGER_URL/-/healthy" > /dev/null 2>&1; then
        echo "ERROR: AlertManager not reachable at $ALERTMANAGER_URL" >&2
        echo "Make sure the stack is running: docker compose up -d" >&2
        exit 1
    fi
}

future_date() {
    date -u -d "+${1} minutes" '+%Y-%m-%dT%H:%M:%S.000Z'
}

past_date() {
    date -u -d "-1 second" '+%Y-%m-%dT%H:%M:%S.000Z'
}

cmd_disk() {
    check_alertmanager

    local ends_at
    ends_at="$(future_date 10)"

    echo "Injecting DiskSpaceHigh alert into AlertManager (active for 10 minutes)..."

    curl -sf -X POST "$ALERTMANAGER_URL/api/v2/alerts" \
        -H "Content-Type: application/json" \
        -d "[{
            \"labels\": {
                \"alertname\": \"DiskSpaceHigh\",
                \"severity\": \"warning\",
                \"instance\": \"node-exporter:9100\",
                \"job\": \"node-exporter\",
                \"mountpoint\": \"/\",
                \"fstype\": \"ext4\",
                \"device\": \"/dev/nvme0n1p1\"
            },
            \"annotations\": {
                \"summary\": \"High disk usage on node-exporter:9100\",
                \"description\": \"Disk usage is 85.0% on / (simulated via trigger-alerts.sh)\"
            },
            \"generatorURL\": \"http://localhost:9090/graph\",
            \"endsAt\": \"$ends_at\"
        }]"

    echo ""
    echo "✅ DiskSpaceHigh alert active. Check: $ALERTMANAGER_URL"
    echo ""
    echo "To resolve: $0 cleanup"
}

service_alert_info() {
    case "$1" in
        mysql)          echo "MySQLDown (mysql_up == 0, fires in ~30s)" ;;
        mysql-exporter) echo "ServiceDown (up == 0, fires in ~1m)" ;;
        node-exporter)  echo "ServiceDown (up == 0, fires in ~1m)" ;;
        cadvisor)       echo "ServiceDown (up == 0, fires in ~1m)" ;;
        prometheus)     echo "BLOCKED" ;;
        *)              echo "NONE" ;;
    esac
}

cmd_service() {
    local service="${1:-}"
    if [ -z "$service" ]; then
        echo "ERROR: service name required. Example: $0 service mysql" >&2
        usage
    fi

    if ! docker compose -f "$PROJECT_ROOT/docker-compose.yml" config --services 2>/dev/null | grep -q "^${service}$"; then
        echo "ERROR: service '${service}' not found in docker-compose.yml" >&2
        exit 1
    fi

    local alert_info
    alert_info="$(service_alert_info "$service")"

    if [ "$alert_info" = "BLOCKED" ]; then
        echo "ERROR: stopping 'prometheus' disables alert evaluation entirely — use another service." >&2
        exit 1
    fi

    if [ "$alert_info" = "NONE" ]; then
        echo "WARNING: '${service}' is not a Prometheus scrape target — stopping it will NOT fire any alert."
        echo ""
        echo "Services that trigger alerts when stopped:"
        echo "  mysql             → MySQLDown   (~30s)"
        echo "  mysql-exporter    → ServiceDown (~1m)"
        echo "  node-exporter     → ServiceDown (~1m)"
        echo "  cadvisor          → ServiceDown (~1m)"
        exit 1
    fi

    echo "Stopping service '${service}'..."
    docker compose -f "$PROJECT_ROOT/docker-compose.yml" stop "$service"

    echo "$service" >> "$STOPPED_SERVICES_FILE"

    echo ""
    echo "✅ Service '${service}' stopped."
    echo "Expected alert: ${alert_info}"
    echo "Check: http://localhost:9090/alerts  or  $ALERTMANAGER_URL"
    echo ""
    echo "To restart: $0 cleanup"
}

cmd_cleanup() {
    local cleaned=0

    if curl -sf "$ALERTMANAGER_URL/-/healthy" > /dev/null 2>&1; then
        local ended_at
        ended_at="$(past_date)"

        curl -sf -X POST "$ALERTMANAGER_URL/api/v2/alerts" \
            -H "Content-Type: application/json" \
            -d "[{
                \"labels\": {
                    \"alertname\": \"DiskSpaceHigh\",
                    \"severity\": \"warning\",
                    \"instance\": \"node-exporter:9100\",
                    \"job\": \"node-exporter\",
                    \"mountpoint\": \"/\",
                    \"fstype\": \"ext4\",
                    \"device\": \"/dev/nvme0n1p1\"
                },
                \"endsAt\": \"$ended_at\"
            }]" > /dev/null 2>&1 && {
            echo "✅ DiskSpaceHigh alert resolved."
            cleaned=1
        } || true
    fi

    if [ -f "$STOPPED_SERVICES_FILE" ]; then
        while IFS= read -r service; do
            [ -z "$service" ] && continue
            echo "Restarting service '${service}'..."
            docker compose -f "$PROJECT_ROOT/docker-compose.yml" start "$service"
        done < "$STOPPED_SERVICES_FILE"
        rm -f "$STOPPED_SERVICES_FILE"
        echo "✅ Stopped services restarted."
        cleaned=1
    fi

    if [ "$cleaned" -eq 0 ]; then
        echo "Nothing to clean up."
    fi
}

case "${1:-}" in
    disk)    cmd_disk ;;
    service) cmd_service "${2:-}" ;;
    cleanup) cmd_cleanup ;;
    *)       usage ;;
esac
