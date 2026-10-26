FROM lequanghuylc/c9sdk-pm2-ubuntu:latest

WORKDIR /var/www/html
ENV WORDPRESS_INITIAL_VERSION=latest

# PHP 8.4.27 fixes PHP2Shell (CVE-2026-109618, CVE-2026-109619).
# The base image is Ubuntu 22.04, which does not ship this release, so pin Ondřej Surý's Jammy build.
ARG PHP_VERSION=8.4.27
ARG PHP_DEB_VERSION=8.4.27-1+ubuntu22.04.1+deb.sury.org+1
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        ca-certificates \
        cron \
        curl \
        gettext-base \
        ghostscript \
        gnupg \
        software-properties-common \
        supervisor \
    && add-apt-repository -y ppa:ondrej/php \
    && apt-get update \
    && echo "Installing PHP ${PHP_DEB_VERSION}" \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        php8.4-bcmath=${PHP_DEB_VERSION} \
        php8.4-cli=${PHP_DEB_VERSION} \
        php8.4-curl=${PHP_DEB_VERSION} \
        php8.4-fpm=${PHP_DEB_VERSION} \
        php8.4-imagick \
        php8.4-intl=${PHP_DEB_VERSION} \
        php8.4-mbstring=${PHP_DEB_VERSION} \
        php8.4-mysql=${PHP_DEB_VERSION} \
        php8.4-xml=${PHP_DEB_VERSION} \
        php8.4-zip=${PHP_DEB_VERSION} \
    && php -r "exit(PHP_VERSION === '${PHP_VERSION}' ? 0 : 1);" \
    && rm -rf /var/lib/apt/lists/*

# Keep runtime directory ready; WordPress is initialized on container start.
RUN mkdir -p /var/www/html

# configure nginx
COPY nginx-conf/wordpress.conf /etc/nginx/sites-enabled/
COPY nginx-conf/project.conf /etc/nginx/sites-enabled/

# WordPress config bootstrap script (used by CMD).
COPY config-wp.sh /root/config-wp.sh
RUN chmod +x /root/config-wp.sh

# Supervisor config (uses %(ENV_...)s expansion at runtime).
COPY supervisord.conf.template /etc/supervisor/conf.d/supervisord.conf

# Install WP CLI
RUN curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/bin/wp \
    && chmod +x /usr/local/bin/wp

CMD ["/bin/bash", "-lc", "set -euo pipefail; \
    mkdir -p /var/www/html; \
    if [ ! -f /var/www/html/wordpress/wp-settings.php ]; then \
      wp_version=\"${WORDPRESS_INITIAL_VERSION:-latest}\"; \
      if [ \"$wp_version\" = \"latest\" ]; then \
        wp_archive_url=\"https://wordpress.org/latest.tar.gz\"; \
      else \
        wp_archive_url=\"https://wordpress.org/wordpress-${wp_version}.tar.gz\"; \
      fi; \
      echo \"Initializing WordPress from: ${wp_archive_url}\"; \
      curl -fSL \"${wp_archive_url}\" | tar -xz -C /var/www/html; \
    fi; \
    if [ ! -f /var/www/html/wordpress/wp-config.php ] && [ -f /var/www/html/wordpress/wp-config-sample.php ]; then \
      cp /var/www/html/wordpress/wp-config-sample.php /var/www/html/wordpress/wp-config.php; \
    fi; \
    chown -R www-data:www-data /var/www/html/wordpress; \
    /root/config-wp.sh /var/www/html/wordpress/wp-config.php; \
    exec supervisord -c /etc/supervisor/conf.d/supervisord.conf"]

EXPOSE 8080