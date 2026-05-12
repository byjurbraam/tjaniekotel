FROM nginx:alpine

COPY vendor/nitro-docker/assets/nginx/ /etc/nginx/conf.d/
COPY vendor/nitro-docker/assets/ /usr/share/nginx/html/
COPY vendor/nitro-docker/assets/favicon.ico /usr/share/nginx/html/favicon.ico
