FROM php:7.3-apache

ENV DOWNLOAD_URL https://master.dl.sourceforge.net/project/quexc/quexc/quexc-0.9.8/quexc-0.9.8.zip

# install the PHP extensions we need
RUN apt-get update && apt-get install -y unzip mariadb-client apache2-utils aspell libpspell-dev && rm -rf /var/lib/apt/lists/* \
	&& docker-php-ext-install mysqli opcache pspell pdo_mysql

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=2'; \
		echo 'opcache.fast_shutdown=1'; \
		echo 'opcache.enable_cli=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

RUN a2enmod rewrite expires authz_groupfile

RUN mkdir /opt/quexc && chown www-data:www-data /opt/quexc

VOLUME ["/opt/quexc"]

RUN set -x; \
	curl -SL "$DOWNLOAD_URL" -o /tmp/quexc.zip; \
    unzip /tmp/quexc.zip -d /tmp; \
    mv /tmp/quexc*/* /var/www/html/; \
    rm /tmp/quexc.zip; \
    rmdir /tmp/quexc*; \
    chown -R www-data:www-data /var/www/html

#use ADODB
RUN set -x \
	&& curl -o adodb.tar.gz -fSL "https://github.com/ADOdb/ADOdb/archive/master.tar.gz" \
	&& tar -xzf adodb.tar.gz -C /usr/src/ \
	&& rm adodb.tar.gz \
	&& mkdir /usr/share/php \
	&& mv /usr/src/ADOdb-master /usr/share/php/adodb

#Set PHP defaults for queXS (allow bigger uploads for sample files)
RUN { \
		echo 'memory_limit=384M'; \
		echo 'upload_max_filesize=128M'; \
		echo 'post_max_size=128M'; \
		echo 'max_execution_time=120'; \
        echo 'max_input_vars=10000'; \
        echo 'date.timezone=UTC'; \
	} > /usr/local/etc/php/conf.d/uploads.ini

COPY docker-entrypoint.sh /usr/local/bin/
RUN ln -s usr/local/bin/docker-entrypoint.sh /entrypoint.sh # backwards compat

# ENTRYPOINT resets CMD
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
