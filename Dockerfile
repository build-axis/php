FROM php:8.4.8-fpm-bookworm

RUN apt-get update && apt-get install -y \
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
    && POLICY_FILE=$(find /etc/ImageMagick-* -name policy.xml | head -n 1) \
    && sed -i 's/rights="none" pattern="PDF"/rights="read|write" pattern="PDF"/g' $POLICY_FILE \
    && sed -i 's/rights="none" pattern="PS"/rights="read|write" pattern="PS"/g' $POLICY_FILE \
    && sed -i 's/rights="none" pattern="EPS"/rights="read|write" pattern="EPS"/g' $POLICY_FILE \
    && sed -i 's/rights="none" pattern="XPS"/rights="read|write" pattern="XPS"/g' $POLICY_FILE \
    && sed -i 's/rights="none" pattern="CDR"/rights="read|write" pattern="CDR"/g' $POLICY_FILE \
    && DELEGATE_FILE=$(find /etc/ImageMagick-* -name delegates.xml | head -n 1) \
    && sed -i '/<delegatemap>/a \  <delegate decode="cdr" command="inkscape &quot;%i&quot; --export-filename=&
