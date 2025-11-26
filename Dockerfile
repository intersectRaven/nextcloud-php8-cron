# DO NOT EDIT: created by update.sh from Dockerfile-debian.template
FROM php:8.4-apache-trixie

# entrypoint.sh and cron.sh dependencies
RUN set -ex; \
    \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        rsync \
        bzip2 \
        busybox-static \
        ghostscript \
        imagemagick \
        libldap-common \
        libmagickcore-7.q16-10-extra \
    ; \
    apt-get dist-clean; \
    \
    mkdir -p /var/spool/cron/crontabs; \
    echo '*/5 * * * * php -f /var/www/html/cron.php' > /var/spool/cron/crontabs/www-data

# install the PHP extensions we need
# see https://docs.nextcloud.com/server/stable/admin_manual/installation/source_installation.html
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

RUN chmod +x /usr/local/bin/install-php-extensions && sync

ENV PHP_MEMORY_LIMIT 512M
ENV PHP_UPLOAD_LIMIT 512M
ENV PHP_OPCACHE_MEMORY_CONSUMPTION 128
ENV IPE_GD_WITHOUTAVIF 1
RUN set -ex; \
    \
    install-php-extensions \
        apcu \
        bcmath \
        exif \
        gd \
        gmp \
        igbinary \
        imagick \
        intl \
        ldap \
        memcached \
        opcache \
        pcntl \
        pdo_mysql \
        pdo_pgsql \
        redis \
        sysvsem \
        zip \
    ;

# trust all ldap certificates
RUN { \
        echo 'TLS_REQCERT allow'; \
    } >> /etc/ldap/ldap.conf

# set recommended PHP.ini settings
# see https://docs.nextcloud.com/server/stable/admin_manual/configuration_server/server_tuning.html#enable-php-opcache
RUN { \
        echo 'opcache.enable=1'; \
        echo 'opcache.interned_strings_buffer=32'; \
        echo 'opcache.jit=1255'; \
        echo 'opcache.jit_buffer_size=128M'; \
        echo 'opcache.max_accelerated_files=10000'; \
        echo 'opcache.memory_consumption=${PHP_OPCACHE_MEMORY_CONSUMPTION}'; \
        echo 'opcache.revalidate_freq=60'; \
        echo 'opcache.save_comments=1'; \
    } > "${PHP_INI_DIR}/conf.d/opcache-recommended.ini"; \
    \
    { \
        echo 'apc.enable_cli=1'; \
        echo 'apc.shm_size=128M'; \
    } >> "${PHP_INI_DIR}/conf.d/docker-php-ext-apcu.ini"; \
    \
    { \
        echo 'always_populate_raw_post_data=-1'; \
        echo 'default_socket_timeout=600'; \
        echo 'max_execution_time=300'; \
        echo 'max_input_time=300'; \
        echo 'memory_limit=${PHP_MEMORY_LIMIT}'; \
        echo 'output_buffering=0'; \
        echo 'post_max_size=${PHP_UPLOAD_LIMIT}'; \
        echo 'upload_max_filesize=${PHP_UPLOAD_LIMIT}'; \
    } > "${PHP_INI_DIR}/conf.d/nextcloud.ini"; \
    \
    { \
        echo 'apc.serializer=igbinary'; \
        echo 'session.serialize_handler=igbinary'; \
    } >> "${PHP_INI_DIR}/conf.d/docker-php-ext-igbinary.ini"; \
    \
    { \
        echo 'redis.session.locking_enabled = 1'; \
        echo 'redis.session.lock_retries = -1'; \
        echo 'redis.session.lock_wait_time = 10000'; \
        echo 'session.gc_maxlifetime = 86400'; \
    } > "${PHP_INI_DIR}/conf.d/redis-session.ini"; \
    \
    mkdir /var/www/data; \
    mkdir -p /docker-entrypoint-hooks.d/pre-installation \
             /docker-entrypoint-hooks.d/post-installation \
             /docker-entrypoint-hooks.d/pre-upgrade \
             /docker-entrypoint-hooks.d/post-upgrade \
             /docker-entrypoint-hooks.d/before-starting; \
    chown -R www-data:root /var/www; \
    chmod -R g=u /var/www

# set ImageMagick policy
RUN sed -i'' 's|.*<policy domain="coder".*"PDF".*|  <policy domain="coder" rights="read \| write" pattern="PDF" />|g' \
    /etc/ImageMagick-7/policy.xml

VOLUME /var/www/html

RUN a2enmod headers rewrite remoteip ; \
    { \
     echo 'RemoteIPHeader X-Real-IP'; \
     echo 'RemoteIPInternalProxy 10.0.0.0/8'; \
     echo 'RemoteIPInternalProxy 172.16.0.0/12'; \
     echo 'RemoteIPInternalProxy 192.168.0.0/16'; \
    } > /etc/apache2/conf-available/remoteip.conf; \
    a2enconf remoteip

# set apache config LimitRequestBody
ENV APACHE_BODY_LIMIT 1073741824
RUN { \
     echo 'LimitRequestBody ${APACHE_BODY_LIMIT}'; \
    } > /etc/apache2/conf-available/apache-limits.conf; \
    a2enconf apache-limits

ENV NEXTCLOUD_VERSION 32.0.2

RUN set -ex; \
    fetchDeps=" \
        gnupg \
        dirmngr \
    "; \
    apt-get update; \
    apt-get install -y --no-install-recommends $fetchDeps; \
    \
    curl -fsSL -o nextcloud.tar.bz2 \
        "https://github.com/nextcloud-releases/server/releases/download/v${NEXTCLOUD_VERSION}/nextcloud-${NEXTCLOUD_VERSION}.tar.bz2"; \
    curl -fsSL -o nextcloud.tar.bz2.asc \
        "https://github.com/nextcloud-releases/server/releases/download/v${NEXTCLOUD_VERSION}/nextcloud-${NEXTCLOUD_VERSION}.tar.bz2.asc"; \
    export GNUPGHOME="$(mktemp -d)"; \
# gpg key from https://nextcloud.com/nextcloud.asc
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 28806A878AE423A28372792ED75899B9A724937A; \
    gpg --batch --verify nextcloud.tar.bz2.asc nextcloud.tar.bz2; \
    tar -xjf nextcloud.tar.bz2 -C /usr/src/; \
    gpgconf --kill all; \
    rm nextcloud.tar.bz2.asc nextcloud.tar.bz2; \
    rm -rf "$GNUPGHOME" /usr/src/nextcloud/updater; \
    mkdir -p /usr/src/nextcloud/data; \
    mkdir -p /usr/src/nextcloud/custom_apps; \
    chmod +x /usr/src/nextcloud/occ; \
    \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false $fetchDeps; \
    rm -rf /var/lib/apt/lists/*

COPY *.sh upgrade.exclude /
COPY config/* /usr/src/nextcloud/config/

ENTRYPOINT ["/entrypoint.sh"]
CMD ["apache2-foreground"]

RUN apt-get update && apt-get install -y \
    supervisor \
  && rm -rf /var/lib/apt/lists/*

COPY supervisord.conf /

ENV NEXTCLOUD_UPDATE=1

CMD ["/usr/bin/supervisord", "-c", "/supervisord.conf"]
