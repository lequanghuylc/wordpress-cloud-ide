# Wordpress with File manager (Railway Template)

![intro](intro.png)

This template run latest Wordpress verions with developer-friendly experience
- File manager via Cloud9 IDE
- Full access to terminal and WP CLI
- Debug log enabled and rotatable
- Bundled with multiple dev tools (Git, zip, unzip, nodejs, pm2)
- Seamless deployment experience for non-tech users

Docker image that serves **WordPress** via **nginx + PHP-FPM** on port **8080**, plus a bundled **c9sdk** (Cloud9) file manager/server started via **pm2**.

## Ports

- **WordPress (nginx)**: container `8080` (nginx `listen 8080;`)
- **c9sdk**: container `3399` (started by pm2 in supervisor)

## Notes

- WordPress debug log is rotated daily via cron, with rotated files older than 7 days automatically removed.
- `WORDPRESS_INITIAL_VERSION` is only used when `/var/www/html/wordpress` is not already initialized (for example, first run with an empty volume).
