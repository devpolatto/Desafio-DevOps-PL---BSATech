#!/bin/sh
set -e

# Executado em toda subida do container — gera apenas na primeira vez.
if [ ! -f /etc/nginx/certs/cert.pem ] || [ ! -f /etc/nginx/certs/key.pem ]; then
    echo "[nginx-init] Certificado SSL não encontrado. Gerando autoassinado (365 dias)..."
    mkdir -p /etc/nginx/certs
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/certs/key.pem \
        -out  /etc/nginx/certs/cert.pem \
        -subj "/C=BR/ST=SP/L=SaoPaulo/O=BSATech/CN=localhost" \
        -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
    echo "[nginx-init] Certificado gerado em /etc/nginx/certs/"
fi

if [ ! -f /etc/nginx/certs/dhparam.pem ]; then
    echo "[nginx-init] Parâmetros Diffie-Hellman não encontrados. Gerando dhparam 2048 bits (aguarde)..."
    openssl dhparam -out /etc/nginx/certs/dhparam.pem 2048
    echo "[nginx-init] dhparam gerado em /etc/nginx/certs/dhparam.pem"
fi

# Garante permissões adequadas nos arquivos de certificado
chown -R nginx:nginx /etc/nginx/certs 2>/dev/null || true

# Delega para o entrypoint oficial do nginx:alpine (que faz a mudança de user)
exec /docker-entrypoint.sh "$@"
