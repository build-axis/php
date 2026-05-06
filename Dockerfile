FROM php:8.4.8-fpm-bookworm

# 1. Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ghostscript \
    imagemagick \
    inkscape \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libicu-dev \
    curl \
    bash \
    liblcms2-2 \
    unzip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 2. Build and install PHP extensions
RUN set -ex \
    && apt-get update && apt-get install -y $PHPIZE_DEPS libmagickwand-dev --no-install-recommends \
    && pecl install imagick redis \
    && docker-php-ext-enable imagick redis \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd zip pdo_mysql intl opcache \
    # Adjust ImageMagick security policies for PDF and CDR support
    && sed -i 's/rights="none" pattern="PDF"/rights="read|write" pattern="PDF"/g' /etc/ImageMagick-6/policy.xml \
    && sed -i 's/rights="none" pattern="CDR"/rights="read|write" pattern="CDR"/g' /etc/ImageMagick-6/policy.xml \
    # Configure Inkscape delegate for CorelDraw files
    && sed -i '/delegate.*decode="cdr"/d' /etc/ImageMagick-6/delegates.xml \
    && sed -i '/<delegatemap>/a \  <delegate decode="cdr" command="cp &quot;%i&quot; &quot;%i.cdr&quot;; inkscape &quot;%i.cdr&quot; --export-filename=&quot;%o.svg&quot;; mv &quot;%o.svg&quot; &quot;%o&quot;; rm -f &quot;%i.cdr&quot;"/>' /etc/ImageMagick-6/delegates.xml \
    && apt-get purge -y $PHPIZE_DEPS libmagickwand-dev \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# 3. Configure Opcache
RUN { \
    echo 'opcache.enable=1'; \
    echo 'opcache.enable_cli=1'; \
    echo 'opcache.memory_consumption=256'; \
    echo 'opcache.interned_strings_buffer=16'; \
    echo 'opcache.max_accelerated_files=20000'; \
    echo 'opcache.save_comments=1'; \
    } >> /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

# 4. Set up non-root user (UID 1000)
ENV USER=php UID=1000 GID=1000
RUN groupadd -g "$GID" "$USER" && \
    useradd -u "$UID" -g "$USER" -m -s /bin/bash "$USER"

WORKDIR "/usr/share/nginx"

# Switch to the non-root user for security
USER "$USER"

CMD ["php-fpm"]
