#!/bin/bash
# Gera o arquivo .env com senhas aleatórias seguras.
# Uso: ./scripts/setup-env.sh
set -euo pipefail

ENV_FILE=".env"
ENV_EXAMPLE=".env.example"

if [ ! -f "$ENV_EXAMPLE" ]; then
  echo "❌ Arquivo $ENV_EXAMPLE não encontrado. Execute a partir da raiz do projeto."
  exit 1
fi

if [ -f "$ENV_FILE" ]; then
  read -rp "⚠️  O arquivo .env já existe. Sobrescrever? [s/N] " confirm
  case "$confirm" in
    [sS]) echo "Sobrescrevendo..." ;;
    *) echo "Operação cancelada."; exit 0 ;;
  esac
fi

gen_password() {
  openssl rand -hex 16
}

MYSQL_ROOT_PASSWORD=$(gen_password)
MYSQL_DATABASE="ghostdb"
MYSQL_USER="ghost"
MYSQL_PASSWORD=$(gen_password)
GHOST_URL="https://localhost"
GRAFANA_ADMIN_PASSWORD=$(gen_password)

cat > "$ENV_FILE" <<EOF
# Gerado automaticamente por scripts/setup-env.sh em $(date '+%Y-%m-%d %H:%M:%S')
# NÃO commitar este arquivo.

# --- MySQL ---
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_DATABASE=${MYSQL_DATABASE}
MYSQL_USER=${MYSQL_USER}
MYSQL_PASSWORD=${MYSQL_PASSWORD}

# --- Ghost ---
GHOST_URL=${GHOST_URL}

# --- Grafana ---
GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
EOF

echo ""
echo "✅ Arquivo .env criado com sucesso!"
echo ""
echo "┌───────────────────────────────────────────────────┐"
echo "│           Credenciais geradas                     │"
echo "├───────────────────────────────────────────────────┤"
printf "│  Grafana admin :  %-30s│\n" "$GRAFANA_ADMIN_PASSWORD"
printf "│  MySQL root    :  %-30s│\n" "$MYSQL_ROOT_PASSWORD"
printf "│  MySQL ghost   :  %-30s│\n" "$MYSQL_PASSWORD"
echo "└───────────────────────────────────────────────────┘"
echo ""
echo "  Grafana → http://localhost:3000  (usuário: admin)"
echo ""
echo "  Próximo passo: docker compose up -d"
echo ""
