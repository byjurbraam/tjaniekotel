FROM node:lts-alpine AS builder

ARG BRANCH=main
ARG COMMIT=33ff182

WORKDIR /build

RUN apk add --no-cache git
RUN git clone --branch ${BRANCH} --recurse-submodules https://github.com/Gurkengewuerz/nitro.git .
RUN git checkout $COMMIT
RUN corepack enable && corepack prepare pnpm@10 --activate
RUN pnpm install --force --config.node-linker=hoisted
RUN pnpm add --save-dev nx
RUN pnpm exec nx build frontend

FROM nginx:alpine

COPY --from=builder /build/dist/apps/frontend/ /usr/share/nginx/html/
COPY nitro/nginx.conf /etc/nginx/conf.d/default.conf
COPY nitro/renderer-config.json /usr/share/nginx/html/renderer-config.json
COPY nitro/ui-config.json /usr/share/nginx/html/ui-config.json
