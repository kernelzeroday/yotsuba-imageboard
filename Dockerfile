FROM php:5.6-apache

# Security lab — not for production use
LABEL org.opencontainers.image.description="4chan Yotsuba imageboard — security testing lab"

# Install system dependencies — Debian Stretch is EOL, use archive mirrors
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
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN pecl install memcached-2.2.0 \
    && docker-php-ext-enable memcached \
    && pecl install imagick-3.4.4 \
    && docker-php-ext-enable imagick \
    && docker-php-ext-install -j$(nproc) \
        mysql \
        mysqli \
        pdo \
        pdo_mysql \
        gd \
        xml \
        mbstring \
        zip

# Configure PHP for the imageboard
RUN { \
        echo 'short_open_tag = On'; \
        echo 'display_errors = On'; \
        echo 'error_reporting = E_ALL'; \
        echo 'log_errors = On'; \
        echo 'memory_limit = 256M'; \
        echo 'upload_max_filesize = 10M'; \
        echo 'post_max_size = 12M'; \
        echo 'max_execution_time = 60'; \
        echo 'expose_php = Off'; \
    } > /usr/local/etc/php/conf.d/yotsuba.ini

# Enable Apache modules
RUN a2enmod rewrite expires headers

# Configure Apache vhost for the imageboard
# DocumentRoot at /www/4chan.org/web/boards/ so /b/ maps to boards/b/
# URL path parsing in yotsuba_config.php derives board from the directory
RUN { \
        echo '<VirtualHost *:80>'; \
        echo '  DocumentRoot /www/4chan.org/web/boards'; \
        echo '  DirectoryIndex imgboard.php'; \
        echo '  <Directory /www/4chan.org/web/boards>'; \
        echo '    Options FollowSymLinks'; \
        echo '    AllowOverride All'; \
        echo '    Require all granted'; \
        echo '  </Directory>'; \
        echo '  RewriteEngine On'; \
        echo '  RewriteRule ^/([a-z0-9]+)/?$ /$1/imgboard.php [QSA,L]'; \
        echo '  RewriteRule ^/([a-z0-9]+)/thread/([0-9]+) /$1/imgboard.php [QSA,L]'; \
        echo '  RewriteRule ^/([a-z0-9]+)/catalog /$1/catalog.php [QSA,L]'; \
        echo '  RewriteRule ^/([a-z0-9]+)/json /$1/json.php [QSA,L]'; \
        echo '</VirtualHost>'; \
    } > /etc/apache2/sites-available/yotsuba.conf \
    && a2dissite 000-default \
    && a2ensite yotsuba

# Set up app directory
WORKDIR /var/www/html

# Copy application code
COPY . /var/www/html/

# Copy container-specific config
COPY docker/config/ /var/www/html/config/
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

# Create required directories & symlink source to yotsuba path
RUN mkdir -p /www/global \
    && ln -s /var/www/html /www/global/yotsuba \
    && mkdir -p /www/4chan.org/web/boards \
    && mkdir -p /www/4chan.org/web/images \
    && mkdir -p /www/4chan.org/web/thumbs \
    && mkdir -p /www/4chan.org/web/sys \
    && mkdir -p /www/keys \
    && mkdir -p /www/perhost \
    && chown -R www-data:www-data /www

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["apache2-foreground"]
