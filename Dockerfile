FROM php:5.6-apache

LABEL org.opencontainers.image.description="localchan imageboard — security testing lab"

# Debian Stretch is EOL — use archive mirrors
RUN echo 'deb http://archive.debian.org/debian stretch main' > /etc/apt/sources.list \
    && echo 'deb http://archive.debian.org/debian-security stretch/updates main' >> /etc/apt/sources.list \
    && apt-get update -o Acquire::Check-Valid-Until=false -o Acquire::AllowInsecureRepositories=true \
    && apt-get install -y --no-install-recommends --allow-unauthenticated \
    libmemcached-dev \
    zlib1g-dev \
    libpng-dev \
    libjpeg-dev \
    libwebp-dev \
    libxml2-dev \
    imagemagick \
    libmagickwand-dev \
    ghostscript \
    ffmpeg \
    gifsicle \
    optipng \
    jhead \
    libjpeg-turbo-progs \
    libicu-dev \
    && rm -rf /var/lib/apt/lists/*

# PHP extensions
RUN pecl install memcached-2.2.0 \
    && docker-php-ext-enable memcached \
    && pecl install imagick-3.4.4 \
    && docker-php-ext-enable imagick \
    && docker-php-ext-configure gd --with-jpeg-dir=/usr --with-png-dir=/usr --with-freetype-dir=/usr --with-webp-dir=/usr \
    && docker-php-ext-install -j$(nproc) \
        mysql \
        mysqli \
        pdo \
        pdo_mysql \
        gd \
        xml \
        mbstring \
        zip \
        intl

# PHP config
RUN { \
        echo 'short_open_tag = On'; \
        echo 'display_errors = Off'; \
        echo 'log_errors = On'; \
        echo 'error_reporting = E_ALL & ~E_NOTICE & ~E_DEPRECATED & ~E_STRICT'; \
        echo 'memory_limit = 256M'; \
        echo 'upload_max_filesize = 10M'; \
        echo 'post_max_size = 12M'; \
        echo 'max_execution_time = 60'; \
        echo 'expose_php = Off'; \
        echo 'date.timezone = UTC'; \
    } > /usr/local/etc/php/conf.d/localchan.ini

# Apache modules
RUN a2enmod rewrite expires headers

# Apache vhost — DocumentRoot at /www/localchan/boards so /b/ maps to boards/b/
RUN { \
        echo '<VirtualHost *:80>'; \
        echo '  DocumentRoot /www/localchan/boards'; \
        echo '  DirectoryIndex imgboard.php'; \
        echo '  Alias /images /www/localchan/images'; \
        echo '  Alias /thumbs /www/localchan/thumbs'; \
        echo '  Alias /static /www/localchan/static'; \
        echo '  Alias /sys /www/localchan/sys'; \
        echo '  <Directory /www/localchan/boards>'; \
        echo '    Options FollowSymLinks'; \
        echo '    AllowOverride All'; \
        echo '    Require all granted'; \
        echo '  </Directory>'; \
        echo '  <Directory /www/localchan/images>'; \
        echo '    Require all granted'; \
        echo '  </Directory>'; \
        echo '  <Directory /www/localchan/thumbs>'; \
        echo '    Require all granted'; \
        echo '  </Directory>'; \
        echo '  <Directory /www/localchan/static>'; \
        echo '    Require all granted'; \
        echo '  </Directory>'; \
        echo '  <Directory /www/localchan/sys>'; \
        echo '    Require all granted'; \
        echo '  </Directory>'; \
        echo '  RewriteEngine On'; \
        echo '  RewriteRule ^/?$ /b/ [R=302,L]'; \
        echo '  RewriteRule ^/([a-z0-9]+)/?$ /$1/imgboard.php [QSA,L]'; \
        echo '  RewriteRule ^/([a-z0-9]+)/post /$1/imgboard.php [QSA,L]'; \
        echo '  RewriteRule ^/([a-z0-9]+)/delete /$1/imgboard.php [QSA,L]'; \
        echo '  RewriteRule ^/([a-z0-9]+)/thread/([0-9]+) /$1/imgboard.php [QSA,L]'; \
        echo '  RewriteRule ^/([a-z0-9]+)/catalog /$1/catalog.php [QSA,L]'; \
        echo '  RewriteRule ^/([a-z0-9]+)/json /$1/json.php [QSA,L]'; \
        echo '</VirtualHost>'; \
    } > /etc/apache2/sites-available/localchan.conf \
    && a2dissite 000-default \
    && a2ensite localchan

WORKDIR /var/www/html

# Copy application code
COPY . /var/www/html/
COPY docker/config/ /var/www/html/config/
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY docker/init-boards.sh /usr/local/bin/init-boards.sh
COPY docker/static/ /www/localchan/static/

RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/init-boards.sh

# Directory structure + symlink source to global path
RUN mkdir -p /www/global \
    && ln -s /var/www/html /www/global/localchan \
    && mkdir -p /www/localchan/boards \
    && mkdir -p /www/localchan/images \
    && mkdir -p /www/localchan/thumbs \
    && mkdir -p /www/localchan/sys \
    && mkdir -p /www/keys \
    && mkdir -p /www/perhost \
    && chown -R www-data:www-data /www

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["apache2-foreground"]
