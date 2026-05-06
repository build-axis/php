# STAGE 1: Build environment
FROM php:8.4.8-fpm-bookworm AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    $PHPIZE_DEPS \
    libmagickwand-dev \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libicu-dev \
    && rm -rf /var/lib/apt/lists/*

# Compile PHP extensions
RUN pecl install imagick redis \
    && docker-php-ext-enable imagick redis \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd zip pdo_mysql intl opcache

# STAGE 2: Runtime environment
FROM php:8.4.8-fpm-bookworm

# Install only runtime libraries and tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    ghostscript \
    imagemagick \
    inkscape \
    libpng16-16 \
    libjpeg62-turbo \
    libzip4 \
    libicu72 \
    liblcms2-2 \
    curl \
    bash \
    unzip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy compiled extensions and configurations from builder
COPY --from=builder /usr/local/lib/php/extensions /usr/local/lib/php/extensions
COPY --from=builder /usr/local/etc/php/conf.d /usr/local/etc/php/conf.d

# Configure ImageMagick security policies
RUN sed -i 's/rights="none" pattern="PDF"/rights="read|write" pattern="PDF"/g' /etc/ImageMagick-6/policy.xml && \
    sed -i 's/rights="none" pattern="CDR"/rights="read|write" pattern="CDR"/g' /etc/ImageMagick-6/policy.xml && \
    # Setup Inkscape delegate for CDR files
    sed -i '/delegate.*decode="cdr"/d' /etc/ImageMagick-6/delegates.xml && \
    sed -i '/<delegatemap>/a \  <delegate decode="cdr" command="cp \&quot;%i\&quot; \&quot;%i.cdr\&quot;; inkscape \&quot;%i.cdr\&quot; --export-filename=\&quot;%o.svg\&quot;; mv \&quot;%o.svg\&quot; \&quot;%o\&quot;; rm -f \&quot;%i.cdr\&quot;"/>' /etc/ImageMagick-6/delegates.xml

# Configure Opcache
RUN { \
    echo 'opcache.enable=1'; \
    echo 'opcache.enable_cli=1'; \
    echo 'opcache.memory_consumption=256'; \
    echo 'opcache.interned_strings_buffer=16'; \
    echo 'opcache.max_accelerated_files=20000'; \
    echo 'opcache.save_comments=1'; \
    } >> /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

# Setup non-root user
ENV USER=php UID=1000 GID=1000
RUN groupadd -g "$GID" "$USER" && \
    useradd -u "$UID" -g "$USER" -m -s /bin/bash "$USER"

WORKDIR "/usr/share/nginx"

USER "$USER"

CMD ["php-fpm"]
