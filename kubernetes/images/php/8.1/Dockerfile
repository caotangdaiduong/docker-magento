FROM php:8.1-fpm-bullseye
MAINTAINER ThePhamDinh [thepd@smartosc.com]

ARG APP_ID=1000

# Database
ENV MYSQL_HOST=127.0.0.1
ENV MYSQL_ROOT_PASSWORD=magento
ENV MYSQL_DATABASE=magento
ENV MYSQL_USER=magento
ENV MYSQL_PASSWORD=magento
ENV MYSQL_INTEGRATION_ROOT_PASSWORD=magento
ENV MYSQL_INTEGRATION_DATABASE=magento_integration_tests
ENV MYSQL_INTEGRATION_USER=magento
ENV MYSQL_INTEGRATION_PASSWORD=magento
ENV MYSQL_INTEGRATION_HOST=db
# ElasticSearch
ENV ES_HOST=127.0.0.1
ENV ES_PORT=9200
ENV ES_HEALTHCHECK_TIMEOUT=100
# Magento
ENV DOMAIN=magento.test
ENV MAGENTO_ADMIN_EMAIL=john.smith@gmail.com
ENV MAGENTO_ADMIN_FIRST_NAME=john
ENV MAGENTO_ADMIN_LAST_NAME=smith
ENV MAGENTO_ADMIN_USER=john.smith
ENV MAGENTO_ADMIN_PASSWORD=password123
ENV MAGENTO_ADMIN_FRONTNAME=admin
ENV MAGENTO_LOCALE=en_US
ENV MAGENTO_CURRENCY=USD
ENV MAGENTO_TIMEZONE=America/New_York
ENV BLACKFIRE_CLIENT_ID=
ENV BLACKFIRE_CLIENT_TOKEN=
ENV COMPOSER_DISABLE_XDEBUG_WARN=1
ENV PHP_CS_FIXER_IGNORE_ENV=1
# RabbitMQ
ENV RABBITMQ_HOST=127.0.0.1
ENV RABBITMQ_PORT=5672
ENV RABBITMQ_MANAGEMENT_PORT=15672
ENV RABBITMQ_DEFAULT_USER=magento
ENV RABBITMQ_DEFAULT_PASS=magento
ENV RABBITMQ_DEFAULT_VHOST=/
ENV RABBITMQ_HEALTHCHECK_TIMEOUT=10


RUN groupadd -g "$APP_ID" app \
  && useradd -g "$APP_ID" -u "$APP_ID" -d /var/www -s /bin/bash app

RUN mkdir -p /etc/nginx/html /var/www/html \
  && chown -R app:app /etc/nginx /var/www /usr/local/etc/php/conf.d

# RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash -

RUN apt-get update && apt-get install -y \
    cron \
    default-mysql-client \
    git \
    gnupg \
    gzip \
    libbz2-dev \
    libfreetype6-dev \
    libicu-dev \
    libjpeg62-turbo-dev \
    libmagickwand-dev \
    libmcrypt-dev \
    libonig-dev \
    libpng-dev \
    libsodium-dev \
    libssh2-1-dev \
    libwebp-dev \
    libxslt1-dev \
    libzip-dev \
    lsof \
    mailutils \
    msmtp \
    nodejs \
    procps \
    vim \
    zip \
  && rm -rf /var/lib/apt/lists/*

RUN pecl channel-update pecl.php.net && pecl install \
    imagick \
    redis \
    ssh2-1.3.1 \
    xdebug \
  && pecl clear-cache \
  && rm -rf /tmp/pear

RUN docker-php-ext-configure \
    gd --with-freetype --with-jpeg --with-webp \
  && docker-php-ext-install \
    bcmath \
    bz2 \
    calendar \
    exif \
    gd \
    gettext \
    intl \
    mbstring \
    mysqli \
    opcache \
    pcntl \
    pdo_mysql \
    soap \
    sockets \
    sodium \
    sysvmsg \
    sysvsem \
    sysvshm \
    xsl \
    zip \
  && docker-php-ext-enable \
    imagick \
    redis \
    ssh2 \
    xdebug

RUN version=$(php -r "echo PHP_MAJOR_VERSION.PHP_MINOR_VERSION;") \
    && architecture=$(uname -m) \
    && curl -A "Docker" -o /tmp/blackfire-probe.tar.gz -D - -L -s https://blackfire.io/api/v1/releases/probe/php/linux/$architecture/$version \
    && mkdir -p /tmp/blackfire \
    && tar zxpf /tmp/blackfire-probe.tar.gz -C /tmp/blackfire \
    && mv /tmp/blackfire/blackfire-*.so $(php -r "echo ini_get ('extension_dir');")/blackfire.so \
    && rm -rf /tmp/blackfire /tmp/blackfire-probe.tar.gz

RUN curl -sS https://getcomposer.org/installer | \
  php -- --install-dir=/usr/local/bin --filename=composer

COPY conf/blackfire.ini $PHP_INI_DIR/conf.d/blackfire.ini
COPY conf/msmtprc /etc/msmtprc
COPY conf/php.ini $PHP_INI_DIR
COPY conf/php-fpm.conf /usr/local/etc/
COPY conf/www.conf /usr/local/etc/php-fpm.d/

# Download source code
RUN echo "Composer auth for repo.magento.com" && \
    composer config --global http-basic.repo.magento.com 9a88e8f9040ba41a8516077e2bbad8e0 9fe89f9ee74c4bf55d6a2da335837b4a && \
    chown -R app:app /var/www/html/ && \
    echo "Creat project template" && \
    composer create-project --repository=https://repo.magento.com/ magento/project-community-edition=2.4.4 . 

RUN echo "Adding Magento modules to Composer allow-plugins directive..." && \
    composer config --no-plugins allow-plugins.magento/magento-composer-installer true && \
    composer config --no-plugins allow-plugins.magento/inventory-composer-installer true && \
    composer config --no-plugins allow-plugins.laminas/laminas-dependency-plugin true && \
    ping 8.8.8.8 -t

USER app:app
VOLUME /var/www
WORKDIR /var/www/html
EXPOSE 9000
