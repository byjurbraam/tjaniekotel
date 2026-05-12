# syntax=docker/dockerfile:1.7

# Stage 1: Composer dependencies
FROM php:8.4-cli-alpine AS composer-builder

ARG COMMIT=53ea66d

WORKDIR /app

# Install system dependencies and PHP extensions
RUN apk add --no-cache \
    git \
    zip \
    unzip \
    icu-dev \
    libzip-dev \
    linux-headers

RUN docker-php-ext-install -j$(nproc) \
    sockets \
    intl \
    pdo_mysql \
    zip

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Clone the repository
RUN git config --global --add safe.directory /app
RUN git clone --recurse-submodules https://github.com/ObjectRetros/atomcms.git .
RUN git checkout $COMMIT
# Real-money shop removal.
COPY ./docker-patches/disable-paid-shop.php /tmp/disable-paid-shop.php
RUN php /tmp/disable-paid-shop.php /app

# Local Docker compatibility redirects. In this setup Nitro is served by the
# separate nitro container, while AtomCMS may still contain older client paths.
RUN <<'EOF'
php <<'PHP'
<?php
$path = 'routes/web.php';
$contents = file_get_contents($path);

$redirects = <<<'ROUTES'

// Local Docker compatibility redirects.
Route::redirect('/game/nitr', '/game/nitro');
Route::get('/client/nitro/nitro-react/dist/index.html', static function () {
    $query = request()->getQueryString();
    $url = rtrim(setting('nitro_path'), '/') . '/index.html';

    return redirect()->away($query ? "{$url}?{$query}" : $url);
});
ROUTES;

if (! str_contains($contents, "Route::redirect('/game/nitr', '/game/nitro');")) {
    $contents = str_replace('// Language route', "{$redirects}\n\n// Language route", $contents);
    file_put_contents($path, $contents);
}
PHP
EOF

# API compatibility fixes for the themed login/register avatar preview.
RUN <<'EOF'
php <<'PHP'
<?php
$servicePath = 'app/Services/User/UserApiService.php';
$service = file_get_contents($servicePath);
$service = str_replace(
    'public function fetchUser(string $username, array $columns): User',
    'public function fetchUser(string $username, array $columns): ?User',
    $service
);
file_put_contents($servicePath, $service);

$controllerPath = 'app/Http/Controllers/Api/HotelApiController.php';
$controller = file_get_contents($controllerPath);
if (! str_contains($controller, 'use Illuminate\Http\JsonResponse;')) {
    $controller = str_replace(
        "use App\Services\User\UserApiService;\n",
        "use App\Services\User\UserApiService;\nuse Illuminate\Http\JsonResponse;\n",
        $controller
    );
}
$controller = str_replace(
    "    public function fetchUser(string \$username, array \$columns = ['username', 'motto', 'look']): UserResource\n    {\n        return new UserResource(\$this->userApiService->fetchUser(\$username, \$columns));\n    }\n",
    "    public function fetchUser(string \$username, array \$columns = ['username', 'motto', 'look']): UserResource|JsonResponse\n    {\n        \$user = \$this->userApiService->fetchUser(\$username, \$columns);\n\n        if (! \$user) {\n            return response()->json(['data' => null, 'message' => 'User not found'], 404);\n        }\n\n        return new UserResource(\$user);\n    }\n",
    $controller
);
file_put_contents($controllerPath, $controller);
PHP
EOF

# Install composer dependencies
RUN --mount=type=cache,id=atomcms-composer-cache,target=/tmp/composer-cache \
    COMPOSER_CACHE_DIR=/tmp/composer-cache composer install \
    --no-interaction \
    --no-dev \
    --prefer-dist \
    --optimize-autoloader \
    --no-scripts

# Generate optimized autoload files
RUN composer dump-autoload --optimize


# Stage 2: Node/NPM build
FROM node:20-alpine AS npm-builder

WORKDIR /app

# Copy application files from composer stage
COPY --from=composer-builder /app /app

# Install dependencies and build assets
RUN --mount=type=cache,id=atomcms-yarn-cache,target=/usr/local/share/.cache/yarn \
    yarn install --frozen-lockfile --cache-folder /usr/local/share/.cache/yarn
RUN yarn run build:atom
RUN yarn run build:dusk

# Clean up node_modules to save space
RUN rm -rf node_modules


# Stage 3: Final image with serversideup/php (nginx + PHP-FPM)
FROM serversideup/php:8.4-fpm-nginx-alpine

ENV PHP_OPCACHE_ENABLE=1

WORKDIR /var/www/html

# Switch to root for setup
USER root

# Copy application from npm-builder
COPY --from=npm-builder --chown=www-data:www-data /app /var/www/html

# Create necessary directories and set permissions
RUN mkdir -p \
    storage/framework/cache \
    storage/framework/sessions \
    storage/framework/views \
    storage/logs \
    bootstrap/cache \
    && chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Custom nginx configuration for Laravel
COPY <<'EOF' /etc/nginx/server-opts.d/laravel.conf
# Security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Access-Control-Allow-Origin "*" always;
add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
add_header Access-Control-Allow-Headers "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization,X-CSRF-TOKEN" always;
add_header Access-Control-Expose-Headers "Content-Length,Content-Range" always;

# Nitro reads these dynamic CMS pages from the separate Nitro origin.
location = /gamedata/habbopages/hide {
    add_header Access-Control-Allow-Origin "*" always;
    add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
    add_header Access-Control-Allow-Headers "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization,X-CSRF-TOKEN" always;
    add_header Access-Control-Expose-Headers "Content-Length,Content-Range" always;
    default_type text/plain;
    return 204;
}

location ~ ^/gamedata/habbopages/ {
    add_header Access-Control-Allow-Origin "*" always;
    add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
    add_header Access-Control-Allow-Headers "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization,X-CSRF-TOKEN" always;
    add_header Access-Control-Expose-Headers "Content-Length,Content-Range" always;

    if ($request_method = 'OPTIONS') {
        add_header Access-Control-Allow-Origin "*" always;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
        add_header Access-Control-Allow-Headers "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization,X-CSRF-TOKEN" always;
        add_header Access-Control-Max-Age 86400 always;
        add_header Content-Type "text/plain; charset=utf-8" always;
        add_header Content-Length 0 always;
        return 204;
    }

    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME $document_root/index.php;
    fastcgi_param SCRIPT_NAME /index.php;
    fastcgi_pass 127.0.0.1:9000;
    fastcgi_buffers 8 8k;
    fastcgi_buffer_size 8k;
    fastcgi_read_timeout 99;
}

# CORS headers for /gamedata directory and all subdirectories
location ~ ^/gamedata/ {
    # Always add CORS headers
    add_header Access-Control-Allow-Origin "*" always;
    add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
    add_header Access-Control-Allow-Headers "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization,X-CSRF-TOKEN" always;
    add_header Access-Control-Expose-Headers "Content-Length,Content-Range" always;
    add_header Access-Control-Allow-Credentials "false" always;
    
    # Handle preflight requests
    if ($request_method = 'OPTIONS') {
        add_header Access-Control-Allow-Origin "*" always;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
        add_header Access-Control-Allow-Headers "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization,X-CSRF-TOKEN" always;
        add_header Access-Control-Max-Age 86400 always;
        add_header Content-Type "text/plain; charset=utf-8" always;
        add_header Content-Length 0 always;
        return 204;
    }
    
    try_files $uri $uri/ @fallback;
}

# Fallback for gamedata requests
location @fallback {
    add_header Access-Control-Allow-Origin "*" always;
    add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
    add_header Access-Control-Allow-Headers "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization,X-CSRF-TOKEN" always;
    try_files $uri /index.php?$query_string;
}

# Static file caching
location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
EOF

# PHP configuration overrides
RUN echo 'max_execution_time = 300' >> /usr/local/etc/php/conf.d/custom.ini \
    && echo 'upload_max_filesize = 20M' >> /usr/local/etc/php/conf.d/custom.ini \
    && echo 'post_max_size = 20M' >> /usr/local/etc/php/conf.d/custom.ini \
    && echo 'memory_limit = 256M' >> /usr/local/etc/php/conf.d/custom.ini \
    && echo 'opcache.enable=1' >> /usr/local/etc/php/conf.d/custom.ini \
    && echo 'opcache.memory_consumption=256' >> /usr/local/etc/php/conf.d/custom.ini \
    && echo 'opcache.interned_strings_buffer=16' >> /usr/local/etc/php/conf.d/custom.ini \
    && echo 'opcache.max_accelerated_files=10000' >> /usr/local/etc/php/conf.d/custom.ini

# Set correct ownership
RUN chown -R www-data:www-data /var/www/html

RUN install-php-extensions sockets intl gd

COPY --chmod=755 ./entrypoint.d/ /etc/entrypoint.d/

# Tjaniekotel branding assets are intentionally copied after dependency and
# extension installation so a logo change does not invalidate package layers.
COPY --chown=www-data:www-data ./branding/tjaniekotel-logo.webp /var/www/html/public/assets/images/tjaniekotel-logo.webp
COPY --chown=www-data:www-data ./branding/tjaniekotel-logo.png /var/www/html/public/assets/images/tjaniekotel-logo.png
COPY --chown=www-data:www-data ./branding/favicon.ico /var/www/html/public/favicon.ico
RUN test -s /var/www/html/public/assets/images/tjaniekotel-logo.png \
    && test -s /var/www/html/public/assets/images/tjaniekotel-logo.webp \
    && test -s /var/www/html/public/favicon.ico

COPY --chmod=755 <<'EOF' /etc/entrypoint.d/20-ensure-default-news-image.sh
#!/bin/sh
set -eu

target="/var/www/html/storage/app/public/website_news_images/default.png"
source_logo="/var/www/html/public/assets/images/tjaniekotel-logo.png"

if [ ! -s "$source_logo" ]; then
    echo "Missing required Tjaniekotel logo asset: $source_logo" >&2
    exit 1
fi

if [ ! -f "$target" ]; then
    mkdir -p "$(dirname "$target")"
    cp "$source_logo" "$target"
fi
EOF

# Switch back to www-data user
USER www-data

RUN php artisan storage:link --force --silent

# serversideup/php uses S6 overlay to manage nginx + php-fpm
# No need to specify CMD, it's handled by the base image
