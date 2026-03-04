FROM php:8.4.8-fpm-alpine3.22

RUN apk add --no-cache \
    ghostscript \
    imagemagick \
    inkscape \
    libpng \
    libjpeg-turbo \
    freetype \
    libzip \
    icu-libs \
    openvpn \
    supervisor \
    curl \
    bash

RUN set -ex \
    && apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        imagemagick-dev \
        libtool \
        libpng-dev \
        libjpeg-turbo-dev \
        freetype-dev \
        libzip-dev \
        icu-dev \
    && pecl install imagick \
    && docker-php-ext-enable imagick \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-install -j$(nproc) zip pdo_mysql intl \
    && pecl install redis \
    && docker-php-ext-enable redis \
    # Разблокировка прав на чтение PDF, PS, EPS и CDR для ImageMagick
    && sed -i 's/rights="none" pattern="PDF"/rights="read|write" pattern="PDF"/g' /etc/ImageMagick-7/policy.xml \
    && sed -i 's/rights="none" pattern="PS"/rights="read|write" pattern="PS"/g' /etc/ImageMagick-7/policy.xml \
    && sed -i 's/rights="none" pattern="EPS"/rights="read|write" pattern="EPS"/g' /etc/ImageMagick-7/policy.xml \
    && sed -i 's/rights="none" pattern="XPS"/rights="read|write" pattern="XPS"/g' /etc/ImageMagick-7/policy.xml \
    && apk del .build-deps \
    && rm -rf /tmp/* /var/cache/apk/*

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

ENV USER=php UID=1000 GID=1000
RUN addgroup -S "$USER" --gid="$GID" && \
    adduser -S -G "$USER" -u "$UID" -h "/home/php" -D "$USER"

RUN echo '* * * * * cd /usr/share/nginx && php artisan schedule:run >> /dev/null 2>&1' > /etc/crontabs/www-data

RUN mv /etc/supervisord.conf /etc/supervisord.conf.back && \
    echo -e "[supervisord]\nnodaemon=true\nuser=root\n" > /etc/supervisord.conf && \
    echo -e "[program:php-fpm]\ncommand=php-fpm -F\nstdout_logfile=/dev/stdout\nstdout_logfile_maxbytes=0\nstderr_logfile=/dev/stderr\nstderr_logfile_maxbytes=0\nautorestart=true\n" >> /etc/supervisord.conf && \
    echo -e "[program:phpjob]\ncommand=php artisan queue:work --tries=1\nuser=php\nnumprocs=1\ndirectory=/usr/share/nginx\nautostart=true\nautorestart=true\nstdout_logfile=/dev/stdout\nstderr_logfile=/dev/stderr\n" >> /etc/supervisord.conf && \
    echo -e "[program:crond]\ncommand=crond -f\nstdout_logfile=/dev/stdout\nstdout_logfile_maxbytes=0\nstderr_logfile=/dev/stderr\nstderr_logfile_maxbytes=0\nautorestart=true\n" >> /etc/supervisord.conf

WORKDIR "/usr/share/nginx"
ENTRYPOINT ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisord.conf"]
