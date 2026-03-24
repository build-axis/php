FROM php:8.4.8-fpm-alpine3.22

RUN apk add --no-cache tzdata
ENV TZ=Europe/Kiev
  
RUN apk add ghostscript
RUN set -ex \
    && apk add --no-cache --virtual .phpize-deps $PHPIZE_DEPS imagemagick-dev libtool \
    && export CFLAGS="$PHP_CFLAGS" CPPFLAGS="$PHP_CPPFLAGS" LDFLAGS="$PHP_LDFLAGS" \
    && pecl install imagick \
    && docker-php-ext-enable imagick \
    && apk add --no-cache --virtual .imagick-runtime-deps imagemagick \
    && apk del .phpize-deps  

RUN apk add --no-cache \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev \
    zip \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install gd zip

# Установка pdo_mysql и opcache
RUN docker-php-ext-install pdo_mysql opcache

RUN set -ex \
    && apk add --no-cache --virtual .redis-deps alpine-sdk php84-dev \
    && yes "" | pecl install redis \
    && docker-php-ext-enable redis \
    && apk del .redis-deps  

RUN set -ex \
    && apk add --no-cache icu \
    && apk add --no-cache --virtual .intl-deps icu-dev $PHPIZE_DEPS \
    && docker-php-ext-configure intl \
    && docker-php-ext-install intl \
    && apk del .intl-deps 

# Настройка OPcache для Laravel
RUN { \
    echo 'opcache.enable=1'; \
    echo 'opcache.enable_cli=1'; \
    echo 'opcache.memory_consumption=256'; \
    echo 'opcache.interned_strings_buffer=16'; \
    echo 'opcache.max_accelerated_files=20000'; \
    echo 'opcache.revalidate_freq=0'; \
    echo 'opcache.validate_timestamps=0'; \
    echo 'opcache.save_comments=1'; \
    echo 'opcache.fast_shutdown=1'; \
    } > /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini

RUN curl -o /tmp/composer-setup.php https://getcomposer.org/installer \
    && curl -o /tmp/composer-setup.sig https://composer.github.io/installer.sig \
    && php -r "if (hash('SHA384', file_get_contents('/tmp/composer-setup.php')) !== trim(file_get_contents('/tmp/composer-setup.sig'))) { unlink('/tmp/composer-setup.php'); echo 'Invalid installer' . PHP_EOL; exit(1); }" \
    && php /tmp/composer-setup.php \
    && mv composer.phar /usr/local/bin/composer \
    && rm /tmp/composer-setup.php

ENV USER=php
ENV UID=1000
ENV GID=1000
RUN addgroup -S "$USER" --gid="$GID" && \
    adduser \
    -G "$USER" \
    --disabled-password \
    --gecos "" \
    --home "/home/php" \
    --ingroup "$USER" \
    --uid "$UID" \
    "$USER"

RUN apk add --no-cache supervisor openvpn

RUN rm -rf /tmp/* /var/cache/apk/*

RUN echo '* * * * * cd /usr/share/nginx && php artisan schedule:run >> /dev/null 2>&1' > /etc/crontabs/www-data

RUN mv /etc/supervisord.conf /etc/supervisord.conf.back
RUN echo -e "[supervisord]\nnodaemon=true\n" > /etc/supervisord.conf
RUN echo -e "[program:php-fpm]\ncommand=php-fpm -F\nstdout_logfile=/dev/stdout\nstdout_logfile_maxbytes=0\nstderr_logfile=/dev/stderr\nstderr_logfile_maxbytes=0\nautorestart=true\nstartretries=0\n" >> /etc/supervisord.conf
RUN echo -e "[program:phpjob]\ncommand=php artisan queue:work --tries=1\nuser=www-data\nnumprocs=1\ndirectory=/usr/share/nginx\nautostart=true\nautorestart=true\nstdout_logfile=/dev/stdout\nstderr_logfile=/dev/stderr\n" >> /etc/supervisord.conf
RUN echo -e "[program:crond]\ncommand=crond\nstdout_logfile=/dev/stdout\nstdout_logfile_maxbytes=0\nstderr_logfile=/dev/stderr\nstderr_logfile_maxbytes=0\nautorestart=true\nstartretries=0\n" >> /etc/supervisord.conf

WORKDIR "/usr/share/nginx"
ENTRYPOINT ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisord.conf"]
