FROM php:8.2-apache

LABEL org.opencontainers.image.description="4chan Yotsuba imageboard — local development environment"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    libmemcached-dev \
    zlib1g-dev \
    libpng-dev \
    libjpeg-dev \
    libwebp-dev \
    libfreetype6-dev \
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
    libzip-dev \
    libonig-dev \
    libpq-dev \
    default-mysql-client \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# PHP extensions
RUN pecl install memcached \
    && docker-php-ext-enable memcached \
    && pecl install imagick \
    && docker-php-ext-enable imagick \
    && docker-php-ext-configure gd --with-jpeg --with-webp --with-freetype \
    && docker-php-ext-install -j$(nproc) \
        mysqli \
        pdo \
        pdo_mysql \
        pdo_pgsql \
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
        echo 'error_reporting = E_ALL & ~E_NOTICE & ~E_DEPRECATED & ~E_STRICT & ~E_WARNING'; \
        echo 'memory_limit = 256M'; \
        echo 'upload_max_filesize = 10M'; \
        echo 'post_max_size = 12M'; \
        echo 'max_execution_time = 60'; \
        echo 'expose_php = Off'; \
        echo 'date.timezone = UTC'; \
    } > /usr/local/etc/php/conf.d/yotsuba.ini

# Symlink binaries to paths expected by the source code
RUN ln -sf /usr/bin/jpegtran /usr/local/bin/jpegtran \
    && ln -sf /usr/bin/gifsicle /usr/local/bin/gifsicle \
    && ln -sf /usr/bin/gs /usr/local/bin/gs \
    && ln -sf /usr/bin/optipng /usr/local/bin/optipng \
    && ln -sf /usr/bin/jhead /usr/local/bin/jhead \
    && ln -sf /usr/bin/ffmpeg /usr/local/bin/ffmpeg-mp4 \
    && ln -sf /usr/bin/ffprobe /usr/local/bin/ffprobe-mp4

# Apache modules
RUN a2enmod rewrite expires headers

# Apache vhost — DocumentRoot at /www/4chan.org/web/boards so /b/ maps to boards/b/
RUN { \
        echo '<VirtualHost *:80>'; \
        echo '  DocumentRoot /www/4chan.org/web/boards'; \
        echo '  DirectoryIndex imgboard.php'; \
        echo '  Alias /images /www/4chan.org/web/images'; \
        echo '  Alias /thumbs /www/4chan.org/web/thumbs'; \
        echo '  Alias /static /www/4chan.org/web/static'; \
        echo '  Alias /sys /www/4chan.org/web/sys'; \
        echo '  <Directory /www/4chan.org/web/boards>'; \
        echo '    Options FollowSymLinks'; \
        echo '    AllowOverride All'; \
        echo '    Require all granted'; \
        echo '  </Directory>'; \
        echo '  <Directory /www/4chan.org/web/images>'; \
        echo '    Require all granted'; \
        echo '  </Directory>'; \
        echo '  <Directory /www/4chan.org/web/thumbs>'; \
        echo '    Require all granted'; \
        echo '  </Directory>'; \
        echo '  <Directory /www/4chan.org/web/static>'; \
        echo '    Require all granted'; \
        echo '  </Directory>'; \
        echo '  <Directory /www/4chan.org/web/sys>'; \
        echo '    Require all granted'; \
        echo '  </Directory>'; \
        echo '  ErrorDocument 404 /static/pages/404.html'; \
        echo '  RewriteEngine On'; \
        echo '  RewriteRule ^/boards\\.json$ /b/boards.php [QSA,L]'; \
        echo '  RewriteRule ^/?$ /b/homepage.php [QSA,L]'; \
        echo '  RewriteRule ^/blotter$ /static/pages/blotter.html [PT,L]'; \
        echo '  RewriteRule ^/rules$ /static/pages/rules.html [PT,L]'; \
        echo '  RewriteRule ^/faq$ /static/pages/faq.html [PT,L]'; \
        echo '  RewriteRule ^/feedback$ /static/pages/feedback.html [PT,L]'; \
        echo '  RewriteRule ^/legal$ /static/pages/legal.html [PT,L]'; \
        echo '  RewriteRule ^/contact$ /static/pages/contact.html [PT,L]'; \
        echo '  RewriteRule ^/advertise$ /static/pages/advertise.html [PT,L]'; \
        echo '  RewriteRule ^/search$ /static/pages/search.html [PT,L]'; \
        echo '  RewriteRule ^/shiichan$ /static/pages/shiichan.html [PT,L]'; \
        echo '  RewriteCond %{DOCUMENT_ROOT}/$1/thread/$2.json.gz -f'; \
        echo '  RewriteRule ^/([a-z0-9]+)/thread/([0-9]+)\\.json$ /$1/thread/$2.json.gz [L,E=no-gzip:1,T=application/json]'; \
        echo '  RewriteCond %{DOCUMENT_ROOT}/$1/$2.json.gz -f'; \
        echo '  RewriteRule ^/([a-z0-9]+)/([0-9]+)\\.json$ /$1/$2.json.gz [L,E=no-gzip:1,T=application/json]'; \
        echo '  RewriteCond %{DOCUMENT_ROOT}/$1/catalog.json.gz -f'; \
        echo '  RewriteRule ^/([a-z0-9]+)/catalog\\.json$ /$1/catalog.json.gz [L,E=no-gzip:1,T=application/json]'; \
        echo '  RewriteCond %{DOCUMENT_ROOT}/$1/threads.json.gz -f'; \
        echo '  RewriteRule ^/([a-z0-9]+)/threads\\.json$ /$1/threads.json.gz [L,E=no-gzip:1,T=application/json]'; \
        echo '  <FilesMatch "\\.json\\.gz$">'; \
        echo '    ForceType application/json'; \
        echo '    Header set Content-Encoding gzip'; \
        echo '  </FilesMatch>'; \
        echo '  <FilesMatch "\\.html\\.gz$">'; \
        echo '    ForceType text/html'; \
        echo '    Header set Content-Encoding gzip'; \
        echo '  </FilesMatch>'; \
        echo '  RewriteCond %{DOCUMENT_ROOT}/$1/$2.html.gz -f'; \
        echo '  RewriteRule ^/([a-z0-9]+)/([0-9]+)$ /$1/$2.html.gz [L,E=no-gzip:1]'; \
        echo '  RewriteRule ^/([a-z0-9]+)/?$ /$1/imgboard.php [QSA,L]'; \
        echo '  RewriteRule ^/([a-z0-9]+)/post /$1/imgboard.php [QSA,L]'; \
        echo '  RewriteRule ^/([a-z0-9]+)/delete /$1/imgboard.php [QSA,L]'; \
        echo '  RewriteRule ^/([a-z0-9]+)/thread/([0-9]+) /$1/imgboard.php?res=$2 [QSA,L]'; \
        echo '  RewriteRule ^/([a-z0-9]+)/catalog /$1/catalog_serve.php [QSA,L]'; \
        echo '  RewriteRule ^/([a-z0-9]+)/json /$1/json.php [QSA,L]'; \
        echo '</VirtualHost>'; \
    } > /etc/apache2/sites-available/yotsuba.conf \
    && a2dissite 000-default \
    && a2ensite yotsuba

# Composer (for PHPUnit)
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

WORKDIR /var/www/html

# Copy application code
COPY . /var/www/html/
COPY docker/config/ /var/www/html/config/
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY docker/init-boards.sh /usr/local/bin/init-boards.sh
COPY docker/run-migrations.sh /usr/local/bin/run-migrations.sh
COPY docker/backup.sh /usr/local/bin/backup.sh
COPY docker/backup-dump.sh /usr/local/bin/backup-dump.sh
COPY docker/static/ /www/4chan.org/web/static/

RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/init-boards.sh /usr/local/bin/run-migrations.sh /usr/local/bin/backup.sh /usr/local/bin/backup-dump.sh

# Install PHP dev dependencies (PHPUnit)
RUN cd /var/www/html && composer install --no-interaction --no-progress 2>/dev/null || true

# Directory structure + symlink source to global path
RUN mkdir -p /www/global \
    && ln -s /var/www/html /www/global/yotsuba \
    && mkdir -p /www/4chan.org/web/boards \
    && mkdir -p /www/4chan.org/web/images \
    && mkdir -p /www/4chan.org/web/thumbs \
    && mkdir -p /www/4chan.org/web/sys \
    && mkdir -p /www/keys \
    && mkdir -p /www/perhost \
    && mkdir -p /www/backups \
    && chown -R www-data:www-data /www

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["apache2-foreground"]
