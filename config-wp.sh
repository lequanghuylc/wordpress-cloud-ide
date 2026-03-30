#!/bin/bash

set -euo pipefail

# Script arguments
wp_config_file="$1"

if [ -z "${wp_config_file}" ] || [ ! -f "${wp_config_file}" ]; then
  echo "Error: wp-config.php path is missing or invalid."
  exit 1
fi

: "${WORDPRESS_DB_NAME:?WORDPRESS_DB_NAME is required}"
: "${WORDPRESS_DB_USER:?WORDPRESS_DB_USER is required}"
: "${WORDPRESS_DB_PASSWORD:?WORDPRESS_DB_PASSWORD is required}"
: "${WORDPRESS_DB_HOST:?WORDPRESS_DB_HOST is required}"

db_host="${WORDPRESS_DB_HOST}"
if [ -n "${WORDPRESS_DB_PORT:-}" ]; then
  db_host="${WORDPRESS_DB_HOST}:${WORDPRESS_DB_PORT}"
fi

sed -i "s/database_name_here/${WORDPRESS_DB_NAME}/g" "${wp_config_file}"
sed -i "s/username_here/${WORDPRESS_DB_USER}/g" "${wp_config_file}"
sed -i "s/password_here/${WORDPRESS_DB_PASSWORD}/g" "${wp_config_file}"
sed -i "s/localhost/${db_host}/g" "${wp_config_file}"

salt_file="$(mktemp)"
tmp_config_file="$(mktemp)"
trap 'rm -f "${salt_file}" "${tmp_config_file}"' EXIT

curl -fsSL https://api.wordpress.org/secret-key/1.1/salt/ -o "${salt_file}"

awk -v salt_file="${salt_file}" '
  BEGIN { inserted = 0 }
  # Remove all existing key/salt defines to avoid duplication.
  /^define\(\x27(AUTH_KEY|SECURE_AUTH_KEY|LOGGED_IN_KEY|NONCE_KEY|AUTH_SALT|SECURE_AUTH_SALT|LOGGED_IN_SALT|NONCE_SALT)\x27/ {
    next
  }
  # Insert fresh key/salt block before the standard marker.
  /That\x27s all, stop editing!/ && !inserted {
    while ((getline line < salt_file) > 0) print line
    close(salt_file)
    inserted = 1
  }
  { print }
  END {
    if (!inserted) {
      while ((getline line < salt_file) > 0) print line
      close(salt_file)
    }
  }
' "${wp_config_file}" > "${tmp_config_file}"

mv "${tmp_config_file}" "${wp_config_file}"

# Enable WP debug logging and keep it idempotent.
tmp_wp_debug_file="$(mktemp)"
trap 'rm -f "${salt_file}" "${tmp_config_file}" "${tmp_wp_debug_file}"' EXIT
awk '
  BEGIN { inserted = 0 }
  /^define\(\x27(WP_DEBUG|WP_DEBUG_LOG|WP_DEBUG_DISPLAY)\x27/ { next }
  /That\x27s all, stop editing!/ && !inserted {
    print "define(\x27WP_DEBUG\x27, true);"
    print "define(\x27WP_DEBUG_LOG\x27, \x27/var/log/wordpress/debug.log\x27);"
    print "define(\x27WP_DEBUG_DISPLAY\x27, false);"
    inserted = 1
  }
  { print }
  END {
    if (!inserted) {
      print "define(\x27WP_DEBUG\x27, true);"
      print "define(\x27WP_DEBUG_LOG\x27, \x27/var/log/wordpress/debug.log\x27);"
      print "define(\x27WP_DEBUG_DISPLAY\x27, false);"
    }
  }
' "${wp_config_file}" > "${tmp_wp_debug_file}"
mv "${tmp_wp_debug_file}" "${wp_config_file}"

# Prepare WordPress log directory and debug log permissions.
mkdir -p /var/log/wordpress
touch /var/log/wordpress/debug.log
chown -R www-data:www-data /var/log/wordpress
chmod 0755 /var/log/wordpress
chmod 0644 /var/log/wordpress/debug.log

# Rotate wordpress debug log daily and keep 7 days.
cat <<'EOF' > /etc/cron.daily/wordpress-debug-log-rotate
#!/bin/bash
set -euo pipefail

log_dir="/var/log/wordpress"
log_file="${log_dir}/debug.log"

mkdir -p "${log_dir}"
touch "${log_file}"

if [ -s "${log_file}" ]; then
  rotated="${log_dir}/debug.log.$(date +%Y%m%d%H%M%S)"
  cp "${log_file}" "${rotated}"
  : > "${log_file}"
  chown www-data:www-data "${rotated}" "${log_file}" || true
  chmod 0644 "${rotated}" "${log_file}" || true
fi

find "${log_dir}" -maxdepth 1 -type f -name 'debug.log.*' -mtime +7 -delete
EOF
chmod +x /etc/cron.daily/wordpress-debug-log-rotate

# Ensure PHP-FPM (www-data) can read wp-config.php.
chown www-data:www-data "${wp_config_file}" || true
chmod 0644 "${wp_config_file}" || true
echo "Database, salts, WP debug config, and log rotation are updated."

