FROM php:8.4.8-fpm-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    ghostscript \
    imagemagick \
    inkscape \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libicu-dev \
    openvpn \
    supervisor \
    curl \
    bash \
    liblcms2-2 \
    unzip \
    cron \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN set -ex \
    && apt-get update && apt-get install -y $PHPIZE_DEPS libmagickwand-dev --no-install-recommends \
    && pecl install imagick \
    && docker-php-ext-enable imagick \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-install -j$(nproc) zip pdo_mysql intl \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && sed -i 's/rights="none" pattern="PDF"/rights="read|write" pattern="PDF"/g' /etc/ImageMagick-6/policy.xml \
    && sed -i 's/rights="none" pattern="CDR"/rights="read|write" pattern="CDR"/g' /etc/ImageMagick-6/policy.xml \
    && sed -i '/<delegatemap>/a \  <delegate decode="cdr" command="cp &quot;%i&quot; &quot;%i.cdr&quot;; inkscape &quot;%i.cdr&quot; --export-filename=&quot;%o.svg&quot;; mv &quot;%o.svg&quot; &quot;%o&quot;; rm -f &quot;%i.cdr&quot;"/>' /etc/ImageMagick-6/delegates.xml \
    && apt-get purge -y $PHPIZE_DEPS libmagickwand-dev \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

ENV USER=php UID=1000 GID=1000
RUN groupadd -g "$GID" "$USER" && \
    useradd -u "$UID" -g "$USER" -m -s /bin/bash "$USER"

RUN echo "* * * * * root cd /usr/share/nginx && php artisan schedule:run >> /dev/null 2>&1" > /etc/cron.d/laravel-cron

RUN echo "[supervisord]\nnodaemon=true\nuser=root\n" > /etc/supervisord.conf && \
    echo "[program:php-fpm]\ncommand=php-fpm -F\nstdout_logfile=/dev/stdout\nstdout_logfile_maxbytes=0\nstderr_logfile=/dev/stderr\nstderr_logfile_maxbytes=0\nautorestart=true\n" >> /etc/supervisord.conf && \
    echo "[program:phpjob]\ncommand=php artisan queue:work --tries=1\nuser=php\nnumprocs=1\ndirectory=/usr/share/nginx\nautostart=true\nautorestart=true\nstdout_logfile=/dev/stdout\nstderr_logfile=/dev/stderr\n" >> /etc/supervisord.conf && \
    echo "[program:cron]\ncommand=cron -f\nstdout_logfile=/dev/stdout\nstdout_logfile_maxbytes=0\nstderr_logfile=/dev/stderr\nstderr_logfile_maxbytes=0\nautorestart=true\n" >> /etc/supervisord.conf

WORKDIR "/usr/share/nginx"
ENTRYPOINT ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisord.conf"]
