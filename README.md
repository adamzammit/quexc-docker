# What is queXC?

[queXC](https://quexc.acspri.org.au/) is a free and open source system web based system for text classification / coding

# How to use this image

```console
$ docker run --name some-quexc --link some-mysql:mysql -d acspri/quexc
```

The following environment variables are also honored for configuring your queXC instance:

-	`-e QUEXC_DB_HOST=...` (defaults to the IP and port of the linked `mysql` container)
-	`-e QUEXC_DB_USER=...` (defaults to "root")
-	`-e QUEXC_DB_PASSWORD=...` (defaults to the value of the `MYSQL_ROOT_PASSWORD` environment variable from the linked `mysql` container)
-	`-e QUEXC_DB_NAME=...` (defaults to "quexc")
-	`-e QUEXC_ADMIN_PASSWORD=...` (defaults to "password")

If the `QUEXC_DB_NAME` specified does not already exist on the given MySQL server, it will be created automatically upon startup of the `quexc` container, provided that the `QUEXC_DB_USER` specified has the necessary permissions to create it.

If you'd like to be able to access the instance from the host without the container's IP, standard port mappings can be used:

```console
$ docker run --name some-quexc --link some-mysql:mysql -p 8080:80 \
     -d acspri/quexc
```

Then, access it via `http://localhost:8080` or `http://host-ip:8080` in a browser.

If you'd like to use an external database instead of a linked `mysql` container, specify the hostname and port with `QUEXC_DB_HOST` along with the password in `QUEXC_DB_PASSWORD` and the username in `QUEXC_DB_USER` (if it is something other than `root`):

```console
$ docker run --name some-quexc -e QUEXC_DB_HOST=10.1.2.3:3306 \
    -e QUEXC_DB_USER=... -e QUEXC_DB_PASSWORD=... -d acspri/quexc
```

## ... via [`docker-compose`](https://github.com/docker/compose)

Example `docker-compose.yml` for `quexc`:

```yaml
version: '2'

services:

  quexc:
    image: acspri/quexc
    ports:
      - 8080:80
    volumes:
      - /location-of-forms:/forms
    environment:
      QUEXC_DB_PASSWORD: example
      QUEXC_ADMIN_PASSWORD: password

  mysql:
    image: mariadb
    environment:
      MYSQL_ROOT_PASSWORD: example
```

Run `docker-compose up`, wait for it to initialize completely, and visit `http://localhost:8080` or `http://host-ip:8080`.

# Supported Docker versions

This image is officially supported on Docker version 1.12.3.

Support for older versions (down to 1.6) is provided on a best-effort basis.

Please see [the Docker installation documentation](https://docs.docker.com/installation/) for details on how to upgrade your Docker daemon.

Notes
-----

A default username is created:

    admin

The password is specified by the QUEXC_ADMIN_PASSWORD environment variable (defaults to: password)

This Dockerfile is based on the [Wordpress official docker image](https://github.com/docker-library/wordpress/tree/8ab70dd61a996d58c0addf4867a768efe649bf65/php5.6/apache)
