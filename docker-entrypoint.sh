#!/bin/bash
set -eu

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
		exit 1
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

if [[ "$1" == apache2* ]] || [ "$1" == php-fpm ]; then
	file_env 'QUEXC_DB_HOST' 'mysql'
	file_env 'QUEXC_ADMIN_PASSWORD' 'password'
	# if we're linked to MySQL and thus have credentials already, let's use them
	file_env 'QUEXC_DB_USER' "${MYSQL_ENV_MYSQL_USER:-root}"
	if [ "$QUEXC_DB_USER" = 'root' ]; then
		file_env 'QUEXC_DB_PASSWORD' "${MYSQL_ENV_MYSQL_ROOT_PASSWORD:-}"
	else
		file_env 'QUEXC_DB_PASSWORD' "${MYSQL_ENV_MYSQL_PASSWORD:-}"
	fi
	file_env 'QUEXC_DB_NAME' "${MYSQL_ENV_MYSQL_DATABASE:-quexc}"
	if [ -z "$QUEXC_DB_PASSWORD" ]; then
		echo >&2 'error: missing required QUEXC_DB_PASSWORD environment variable'
		echo >&2 '  Did you forget to -e QUEXC_DB_PASSWORD=... ?'
		echo >&2
		echo >&2 '  (Also of interest might be QUEXC_DB_USER and QUEXC_DB_NAME.)'
		exit 1
	fi

	if ! [ -e admin/.htaccess ]; then
		echo >&2 "queXC password control not found in $(pwd) - copying now..."
		if [ "$(ls -A)" ]; then
			echo >&2 "WARNING: $(pwd) is not empty - press Ctrl+C now if this is an error!"
			( set -x; ls -A; sleep 10 )
		fi

        cat <<EOF > admin/.htaccess
AuthName "queXC"
AuthType Basic
AuthUserFile /opt/quexc/password
AuthGroupFile /opt/quexc/group
require group admin
EOF
       cat <<EOF > .htaccess
AuthName "queXC"
AuthType Basic
AuthUserFile /opt/quexc/password
AuthGroupFile /opt/quexc/group
require group verifier
EOF
		echo >&2 "Complete! queXC has been successfully set up with password control at $(pwd)"
	else
        echo >&2 "queXC found in $(pwd) - not copying."
	fi

	if ! [ -e /opt/quexc/password ]; then
		echo >&2 "queXC password not found in /opt/quexc/password - creating now..."
        
        htpasswd -c -B -b /opt/quexc/password admin "$QUEXC_ADMIN_PASSWORD"

		cat <<EOF > /opt/quexc/group
admin: admin
verifier: admin
EOF
		echo >&2 "Complete! queXC admin password created"
	else
        echo >&2 "queXC password found in /opt/quexc - not copying."
	fi

	chown www-data:www-data -R /opt/quexc

	# see http://stackoverflow.com/a/2705678/433558
	sed_escape_lhs() {
		echo "$@" | sed -e 's/[]\/$*.^|[]/\\&/g'
	}
	sed_escape_rhs() {
		echo "$@" | sed -e 's/[\/&]/\\&/g'
	}
	php_escape() {
		php -r 'var_export(('$2') $argv[1]);' -- "$1"
	}
	set_config() {
		key="$1"
        value="$(sed_escape_lhs "$2")"
        sed -i "/$key/s/[^,]*/'$value');/2" config.inc.php
	}

	set_config 'DB_HOST' "$QUEXC_DB_HOST"
	set_config 'DB_USER' "$QUEXC_DB_USER"
	set_config 'DB_PASS' "$QUEXC_DB_PASSWORD"
	set_config 'DB_NAME' "$QUEXC_DB_NAME"

	TERM=dumb php -- "$QUEXC_DB_HOST" "$QUEXC_DB_USER" "$QUEXC_DB_PASSWORD" "$QUEXC_DB_NAME" <<'EOPHP'
<?php
// database might not exist, so let's try creating it (just to be safe)

$stderr = fopen('php://stderr', 'w');

list($host, $socket) = explode(':', $argv[1], 2);
$port = 0;
if (is_numeric($socket)) {
	$port = (int) $socket;
	$socket = null;
}

$maxTries = 10;
do {
	$mysql = new mysqli($host, $argv[2], $argv[3], '', $port, $socket);
	if ($mysql->connect_error) {
		fwrite($stderr, "\n" . 'MySQL Connection Error: (' . $mysql->connect_errno . ') ' . $mysql->connect_error . "\n");
		--$maxTries;
		if ($maxTries <= 0) {
			exit(1);
		}
		sleep(3);
	}
} while ($mysql->connect_error);

if (!$mysql->query('CREATE DATABASE IF NOT EXISTS `' . $mysql->real_escape_string($argv[4]) . '`')) {
	fwrite($stderr, "\n" . 'MySQL "CREATE DATABASE" Error: ' . $mysql->error . "\n");
	$mysql->close();
	exit(1);
}

// check if database populated

if (!$mysql->query('SELECT COUNT(*) AS C FROM ' . $argv[4] . '.code')) {
    fwrite($stderr, "\n" . 'Cannot find queXC database. Will now populate... ' . $mysql->error . "\n");

    $command = 'mysql'
        . ' --host=' . $host
        . ' --user=' . $argv[2]
        . ' --password=' . $argv[3]
        . ' --database=' . $argv[4]
        . ' --execute="SOURCE ';

    fwrite($stderr, "\n" . 'Loading queXC database...' . "\n");
    $output1 = shell_exec($command . '/var/www/html/database/quexc.sql"');
    fwrite($stderr, "\n" . 'Loaded queXC database: ' . $output1 . "\n");

    $mysql->query("INSERT INTO " . $argv[4] . ".operator (description,username) VALUES ('Administrator','admin')");
	
} else {
	fwrite($stderr, "\n" . 'queXC Database found. Leaving unchanged.' . "\n");
}

$mysql->close();
EOPHP


fi

exec "$@"
