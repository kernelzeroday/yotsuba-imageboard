FROM php:5.6-apache

# Security lab — not for production use
LABEL org.opencontainers.image.description="4chan Yotsuba imageboard — security testing lab"

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
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

# Set up app directory
WORKDIR /var/www/html

# Copy application code
COPY . /var/www/html/

# Copy container-specific config
COPY docker/config/ /var/www/html/config/
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

# Create required directories
RUN mkdir -p /www/global/yotsuba/config \
    && mkdir -p /www/global/yotsuba/plugins \
    && mkdir -p /www/global/yotsuba/views \
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
