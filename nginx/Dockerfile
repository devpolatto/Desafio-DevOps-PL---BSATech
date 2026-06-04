FROM nginx:alpine

RUN apk add --no-cache openssl

RUN rm -f /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Entrypoint customizado: gera cert se ausente, depois delega ao nginx:alpine
COPY docker-entrypoint.sh /bsatech-entrypoint.sh
RUN chmod +x /bsatech-entrypoint.sh

EXPOSE 80 443

ENTRYPOINT ["/bsatech-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
