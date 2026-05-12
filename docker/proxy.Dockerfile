FROM nginx:alpine

COPY ./docker/nginx/default.conf.template /etc/nginx/templates/default.conf.template

