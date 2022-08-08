#!/bin/bash

DOMAIN=${1:-magento.test}

# shellcheck source=../env/db.env
source env/db.env
# shellcheck source=../env/elasticsearch.env
source env/elasticsearch.env
# shellcheck source=../env/magento.env
source env/magento.env
# shellcheck source=../env/rabbitmq.env
source env/rabbitmq.env
# shellcheck source=../env/redis.env
source env/redis.env

DOMAIN=${1:-magento.test}

echo "Composer auth for repo.magento.com"
composer config --global http-basic.repo.magento.com 9a88e8f9040ba41a8516077e2bbad8e0 9fe89f9ee74c4bf55d6a2da335837b4a
chown -R app:app /var/www/html/
echo "Creat project template"
composer create-project --repository=https://repo.magento.com/ magento/project-community-edition=2.4.4 . 

composer config --no-plugins allow-plugins.magento/magento-composer-installer true
composer config --no-plugins allow-plugins.magento/inventory-composer-installer true
composer config --no-plugins allow-plugins.laminas/laminas-dependency-plugin true

echo "Waiting for connection to Elasticsearch..."
timeout $ES_HEALTHCHECK_TIMEOUT bash -c "
    until curl --silent --output /dev/null http://$ES_HOST:$ES_PORT/_cat/health?h=st; do
        printf '.'
        sleep 2
    done"
[ $? != 0 ] && echo "Failed to connect to Elasticsearch" && exit

echo ""
echo "Waiting for connection to RabbitMQ..."
timeout $RABBITMQ_HEALTHCHECK_TIMEOUT bash -c "
    until curl --silent --output /dev/null http://$RABBITMQ_DEFAULT_USER:$RABBITMQ_DEFAULT_PASS@$RABBITMQ_HOST:$RABBITMQ_MANAGEMENT_PORT/api/aliveness-test/%2F; do
        printf '.'
        sleep 2
    done"
[ $? != 0 ] && echo "Failed to connect to RabbitMQ" && exit

bin/clinotty bin/magento setup:install \
  --db-host="$MYSQL_HOST" \
  --db-name="$MYSQL_DATABASE" \
  --db-user="$MYSQL_USER" \
  --db-password="$MYSQL_PASSWORD" \
  --base-url=https://"$DOMAIN"/ \
  --base-url-secure=https://"$DOMAIN"/ \
  --backend-frontname="$MAGENTO_ADMIN_FRONTNAME" \
  --admin-firstname="$MAGENTO_ADMIN_FIRST_NAME" \
  --admin-lastname="$MAGENTO_ADMIN_LAST_NAME" \
  --admin-email="$MAGENTO_ADMIN_EMAIL" \
  --admin-user="$MAGENTO_ADMIN_USER" \
  --admin-password="$MAGENTO_ADMIN_PASSWORD" \
  --language="$MAGENTO_LOCALE" \
  --currency="$MAGENTO_CURRENCY" \
  --timezone="$MAGENTO_TIMEZONE" \
  --amqp-host="$RABBITMQ_HOST" \
  --amqp-port="$RABBITMQ_PORT" \
  --amqp-user="$RABBITMQ_DEFAULT_USER" \
  --amqp-password="$RABBITMQ_DEFAULT_PASS" \
  --amqp-virtualhost="$RABBITMQ_DEFAULT_VHOST" \
  --cache-backend=redis \
  --cache-backend-redis-server=$REDIS_HOST \
  --cache-backend-redis-db=$REDIS_DB_CACHE_BACKEND \
  --page-cache=redis \
  --page-cache-redis-server=$REDIS_HOST \
  --page-cache-redis-db=$REDIS_DB_CACHE_FRONTEND \
  --session-save=redis \
  --session-save-redis-host=$REDIS_HOST \
  --session-save-redis-log-level=4 \
  --session-save-redis-db=$REDIS_DB_SESSION \
  --search-engine=elasticsearch7 \
  --elasticsearch-host=$ES_HOST \
  --elasticsearch-port=$ES_PORT \
  --use-rewrites=1 \
  --no-interaction

echo "Forcing deploy of static content to speed up initial requests..."
bin/magento setup:static-content:deploy -f

echo "Re-indexing with Elasticsearch..."
bin/magento indexer:reindex

echo "Setting basic URL and generating SSL certificate..."
bin/setup-domain "${DOMAIN}"

echo "Fixing owner and permissions..."
chown -R app:app /var/www/html/

echo "Clearing the cache to apply updates..."
bin/magento cache:flush

echo "Installing cron, run 'bin/cron start' to enable..."
bin/magento cron:install

echo "Turning on developer mode..."
bin/magento deploy:mode:set developer