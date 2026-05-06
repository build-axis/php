# Stage 1: Build extensions
FROM php:8.4.8-fpm-alpine3.22 AS builder

RUN set -ex \
    && apk add --no-cache $PHPIZE_DEPS \
    && docker-php-ext-install -j$(nproc) pdo_mysql opcache pcntl \
    && pecl install redis \
    && docker-php-ext-enable redis

# Stage 2: Final image
FROM php:8.4.8-fpm-alpine3.22

COPY --from=builder /usr/local/lib/php/extensions /usr/local/lib/php/extensions
COPY --from=builder /usr/local/etc/php/conf.d /usr/local/etc/php/conf.d

RUN { \
    echo 'opcache.memory_consumption=256'; \
    echo 'opcache.interned_strings_buffer=16'; \
    echo 'opcache.max_accelerated_files=20000'; \
    echo 'opcache.revalidate_freq=0'; \
    echo 'opcache.validate_timestamps=0'; \
    echo 'opcache.fast_shutdown=1'; \
    echo 'opcache.enable_cli=1'; \
    } > /usr/local/etc/php/conf.d/opcache-optimized.ini

RUN set -ex \
    && addgroup -g 1000 php \
    && adduser -u 1000 -G php -s /bin/sh -D php \
    && mkdir -p /etc/crontabs \
    && echo "* * * * * /usr/local/bin/php /usr/share/nginx/artisan schedule:run >> /dev/stdout 2>&1" > /etc/crontabs/php \
    && sed -i 's/user = www-data/user = php/g' /usr/local/etc/php-fpm.d/www.conf \
    && sed -i 's/group = www-data/group = php/g' /usr/local/etc/php-fpm.d/www.conf

WORKDIR /usr/share/nginx

CMD ["php-fpm"]
