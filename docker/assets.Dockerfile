FROM nginx:alpine

COPY assets/nginx/ /etc/nginx/conf.d/
COPY assets/ /usr/share/nginx/html/
COPY assets/favicon.ico /usr/share/nginx/html/favicon.ico
