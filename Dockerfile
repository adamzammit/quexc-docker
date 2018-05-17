FROM php:7-apache

# install the PHP extensions we need
RUN apt-get update && apt-get install -y bzr mysql-client apache2-utils aspell libpspell-dev && rm -rf /var/lib/apt/lists/* \
	&& docker-php-ext-install mysqli opcache pspell

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

VOLUME ["/var/www/html", "/opt/quexc"]

RUN set -x \
	&& bzr branch lp:quexc /usr/src/quexc \
	&& chown -R www-data:www-data /usr/src/quexc

#use ADODB
RUN set -x \
	&& curl -o adodb.tar.gz -fSL "https://github.com/ADOdb/ADOdb/archive/v5.20.7.tar.gz" \
	&& tar -xzf adodb.tar.gz -C /usr/src/ \
	&& rm adodb.tar.gz \
	&& mkdir /usr/share/php \
	&& mv /usr/src/ADOdb-5.20.7 /usr/share/php/adodb

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
