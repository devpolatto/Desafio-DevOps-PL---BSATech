FROM nginx:1.27-alpine@sha256:65645c7bb6a0661892a8b03b89d0743208a18dd2f3f17a54ef4b76fb8e2f2a10

RUN apk update && apk upgrade --no-cache && apk add --no-cache openssl

RUN rm -f /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Entrypoint customizado: gera cert se ausente, depois delega ao nginx:alpine
COPY docker-entrypoint.sh /bsatech-entrypoint.sh
RUN chmod +x /bsatech-entrypoint.sh

EXPOSE 80 443

USER nginx

ENTRYPOINT ["/bsatech-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
