FROM php:8.2.7-fpm-alpine3.18

RUN apk update; \
    apk upgrade;
       
RUN apk add --no-cache freetype libpng libjpeg-turbo freetype-dev libpng-dev libjpeg-turbo-dev && \
  docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg && \
  NPROC=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1) && \
  docker-php-ext-install -j${NPROC} gd && \
  apk del --no-cache freetype-dev libpng-dev libjpeg-turbo-dev
  

RUN apk add --no-cache tzdata
ENV TZ=Europe/Kiev
  
#3.5.1  
RUN set -ex \
    && apk add --no-cache --virtual .phpize-deps $PHPIZE_DEPS imagemagick-dev libtool \
    && export CFLAGS="$PHP_CFLAGS" CPPFLAGS="$PHP_CPPFLAGS" LDFLAGS="$PHP_LDFLAGS" \
    && pecl install imagick-3.7.0 \
    && docker-php-ext-enable imagick \
    && apk add --no-cache --virtual .imagick-runtime-deps imagemagick \
    && apk del .phpize-deps \
    && rm -rf /tmp/* /var/cache/apk/*  

#RUN docker-php-ext-install exif 
RUN docker-php-ext-install pdo_mysql

#RUN docker-php-ext-install mysqli
RUN docker-php-ext-install pcntl



#RUN apt-get install libsodium-dev -y
#RUN docker-php-ext-install sodium

RUN apk add --no-cache libzip-dev && docker-php-ext-configure zip && docker-php-ext-install zip

RUN apk add --no-cache libintl icu icu-dev && docker-php-ext-configure intl && docker-php-ext-install intl

RUN curl -o /tmp/composer-setup.php https://getcomposer.org/installer \
  && curl -o /tmp/composer-setup.sig https://composer.github.io/installer.sig \
  && php -r "if (hash('SHA384', file_get_contents('/tmp/composer-setup.php')) !== trim(file_get_contents('/tmp/composer-setup.sig'))) { unlink('/tmp/composer-setup.php'); echo 'Invalid installer' . PHP_EOL; exit(1); }"

RUN php /tmp/composer-setup.php
RUN mv composer.phar /usr/local/bin/composer
RUN rm /tmp/composer-setup.php

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


RUN apk add --no-cache  supervisor
RUN apk add --no-cache  git
RUN apk add --no-cache  sudo
#RUN apk add openssh-client

#RUN apk add mysql-client
#RUN apk add zip
RUN apk add --no-cache openvpn


#mongo db ext begin
#RUN apk add \
#    alpine-sdk \
#    openssl-dev \
#    php82-pear \
#    php82-dev \
#    && rm -rf /var/cache/apk/*

#RUN pecl install mongodb \
#    && pecl clear-cache

#RUN echo "extension=mongodb.so" > /etc/php82/conf.d/mongodb.ini
#RUN echo "extension=mongodb.so" > /usr/local/etc/php/conf.d/docker-php-ext-mongodb.ini 
#mongdb exto end


RUN apk add --no-cache pcre-dev $PHPIZE_DEPS \
    && yes "" | pecl install redis \
    && docker-php-ext-enable redis \
    && apk del pcre-dev $PHPIZE_DEPS

RUN rm -rf /tmp/* /var/cache/apk/*

RUN echo '* * * * * cd /usr/share/nginx && php artisan schedule:run >> /dev/null 2>&1' > /etc/crontabs/www-data

RUN mv /etc/supervisord.conf  /etc/supervisord.conf.back
RUN echo -e "[supervisord]\nnodaemon=true\n" > /etc/supervisord.conf
RUN echo -e "[program:php-fpm]\ncommand=php-fpm -F\nstdout_logfile=/dev/stdout\nstdout_logfile_maxbytes=0\nstderr_logfile=/dev/stderr\nstderr_logfile_maxbytes=0\nautorestart=true\nstartretries=0\n" >> /etc/supervisord.conf
RUN echo -e "[program:phpjob]\ncommand=php artisan queue:work --tries=1\nuser=www-data\nnumprocs=1\ndirectory=/usr/share/nginx\nautostart=true\nautorestart=true\nstdout_logfile=/dev/stdout\nstderr_logfile=/dev/stderr\n" >> /etc/supervisord.conf
RUN echo -e "[program:crond]\ncommand=crond\nstdout_logfile=/dev/stdout\nstdout_logfile_maxbytes=0\nstderr_logfile=/dev/stderr\nstderr_logfile_maxbytes=0\nautorestart=true\nstartretries=0\n" >> /etc/supervisord.conf

WORKDIR "/usr/share/nginx"
ENTRYPOINT ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisord.conf"]

