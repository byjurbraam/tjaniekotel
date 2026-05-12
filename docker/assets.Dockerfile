FROM nginx:alpine

COPY assets/nginx/ /etc/nginx/conf.d/
COPY assets/ /usr/share/nginx/html/
