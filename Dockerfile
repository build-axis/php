# Stage 1: Build extensions
FROM php:8.4.8-fpm-alpine3.22 AS builder

RUN set -ex \
    && apk add --no-cache $PHPIZE_DEPS \
    && docker-php-ext-install -j$(nproc) pdo_mysql opcache \
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

WORKDIR /usr/share/nginx

CMD ["php-fpm"]
