# Wordpress with File manager

![intro](intro.png)


This repository exists to provide a developer-first WordPress runtime with full file and system control through a Cloud IDE. It gives direct file access via [c9sdk](https://github.com/lequanghuylc/c9sdk-pm2-nginx) so you can fully control the environment, and it is optimized for iterative development with IDE + terminal access, WP-CLI workflows, and debug logging enabled with automatic rotation. It works especially well with Git-based projects and local code/plugins workflows (for example FluentSnippets), while still letting you bootstrap the latest WordPress or a pinned version via `WORDPRESS_INITIAL_VERSION`.

Docker image that serves **WordPress** via **nginx + PHP-FPM** on port **8080**, plus a bundled **c9sdk** (Cloud9) file manager/server started via **pm2**.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/dSgrm2?referralCode=kmHOLH&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Ports

- **WordPress (nginx)**: container `8080` (nginx `listen 8080;`)
- **c9sdk**: container `3399` (started by pm2 in supervisor)

## Required environment variables

These must be provided at runtime (e.g. `docker run -e ...`).

### WordPress database

- **`WORDPRESS_DB_NAME`**: database name (replaces `database_name_here` in `wp-config.php`)
- **`WORDPRESS_DB_USER`**: database username (replaces `username_here`)
- **`WORDPRESS_DB_PASSWORD`**: database password (replaces `password_here`)
- **`WORDPRESS_DB_HOST`**: database host (e.g. `db`, `127.0.0.1`, `mysql`)
- **`WORDPRESS_DB_PORT`** (optional): database port (e.g. `3306`). If set, `wp-config.php` will use `${WORDPRESS_DB_HOST}:${WORDPRESS_DB_PORT}`.
- **`WORDPRESS_INITIAL_VERSION`** (optional): WordPress version to install on first initialization. Use `latest` (default) or an exact version like `6.6.2`.
- **`WP_HOME`** (optional): public site URL to force in `wp-config.php`. Useful when the container runs behind a reverse proxy or when the domain changes.
- **`WP_SITEURL`** (optional): WordPress core URL to force in `wp-config.php`. Set this alongside `WP_HOME` to stop redirects back to the original stored URL.

### c9sdk

- **`C9SDK_PASSWORD`**: password used by the `c9sdk` server (supervisor starts `pm2` with `-a c9sdk:$C9SDK_PASSWORD`)

## Build

```bash
docker build -t wordpress-with-file-manager .
```

## Run (example)

This example assumes you have a MySQL service reachable as `db:3306`.

```bash
docker run --rm \
  -p 8080:8080 \
  -p 3399:3399 \
  -e WORDPRESS_DB_NAME=wordpress \
  -e WORDPRESS_DB_USER=wordpress \
  -e WORDPRESS_DB_PASSWORD=changeme \
  -e WORDPRESS_DB_HOST=db \
  -e WORDPRESS_DB_PORT=3306 \
  -e WORDPRESS_INITIAL_VERSION=latest \
  -e WP_HOME=http://localhost:8080 \
  -e WP_SITEURL=http://localhost:8080 \
  -e C9SDK_PASSWORD=changeme \
  wordpress-with-file-manager
```

Then open:

- WordPress: `http://localhost:8080/`
- c9sdk: `http://localhost:3399/`

## More local run examples

### 0) Run with Docker Compose (recommended)

```bash
cp .env.example .env
# edit .env with your own passwords
docker compose up -d --build
```

Then open:

- WordPress: `http://localhost:8080/`
- c9sdk: `http://localhost:3399/`

### 1) Build and run directly from local `Dockerfile`

Useful when you just changed the Dockerfile and want to test immediately:

```bash
docker build -f Dockerfile -t wp-local-test . && \
docker run --rm \
  -p 8080:8080 \
  -p 3399:3399 \
  -e WORDPRESS_DB_NAME=wordpress \
  -e WORDPRESS_DB_USER=wordpress \
  -e WORDPRESS_DB_PASSWORD=changeme \
  -e WORDPRESS_DB_HOST=host.docker.internal \
  -e WORDPRESS_DB_PORT=3306 \
  -e WP_HOME=http://localhost:8080 \
  -e WP_SITEURL=http://localhost:8080 \
  -e C9SDK_PASSWORD=changeme \
  wp-local-test
```

> For Linux hosts, `host.docker.internal` may not resolve by default. Use your host IP or a Docker network service name.

### 2) Use an env file for cleaner local runs

Create `.env.local`:

```bash
WORDPRESS_DB_NAME=wordpress
WORDPRESS_DB_USER=wordpress
WORDPRESS_DB_PASSWORD=changeme
WORDPRESS_DB_HOST=db
WORDPRESS_DB_PORT=3306
WORDPRESS_INITIAL_VERSION=latest
WP_HOME=http://localhost:8080
WP_SITEURL=http://localhost:8080
C9SDK_PASSWORD=changeme
```

Run:

```bash
docker build -t wordpress-with-file-manager . && \
docker run --rm \
  -p 8080:8080 \
  -p 3399:3399 \
  --env-file .env.local \
  wordpress-with-file-manager
```

### 3) Full local test with MySQL container

```bash
docker network create wp-net

docker run -d --name wp-mysql --network wp-net \
  -e MYSQL_ROOT_PASSWORD=rootpass \
  -e MYSQL_DATABASE=wordpress \
  -e MYSQL_USER=wordpress \
  -e MYSQL_PASSWORD=changeme \
  mysql:8.0

docker build -t wordpress-with-file-manager .

docker run --rm --name wp-app --network wp-net \
  -p 8080:8080 \
  -p 3399:3399 \
  -e WORDPRESS_DB_NAME=wordpress \
  -e WORDPRESS_DB_USER=wordpress \
  -e WORDPRESS_DB_PASSWORD=changeme \
  -e WORDPRESS_DB_HOST=wp-mysql \
  -e WORDPRESS_DB_PORT=3306 \
  -e WP_HOME=http://localhost:8080 \
  -e WP_SITEURL=http://localhost:8080 \
  -e C9SDK_PASSWORD=changeme \
  wordpress-with-file-manager
```

Cleanup after testing:

```bash
docker rm -f wp-mysql
docker network rm wp-net
```

## Notes

- On container start, `/root/config-wp.sh` updates `wp-config.php` DB settings and refreshes WordPress salts using `https://api.wordpress.org/secret-key/1.1/salt/`.
- If `WP_HOME` and/or `WP_SITEURL` are set, `/root/config-wp.sh` writes them into `wp-config.php` so WordPress uses the current public URL instead of redirecting to an older stored domain.
- `WORDPRESS_INITIAL_VERSION` is only used when `/var/www/html/wordpress` is not already initialized (for example, first run with an empty volume).
- instructions to use WP CLI: you need to open Cloud9 IDE and open a terminal there

```bash
su -s /bin/bash www-data
cd /var/www/html/wordpress
wp core version
```
