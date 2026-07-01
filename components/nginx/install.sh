#!/bin/sh
# Component: nginx
# Configs are staged to /tmp/if_nginx_* by the Packer file provisioner before this runs

. /tmp/forge-lib/common.sh
. /tmp/forge-lib/apk.sh

require_root
log "component/nginx: installing"

# Verify to get the exact pin: apk search --exact nginx
# Alpine 3.24 ships 1.30.3-r0 — CVE-2026-42055 fixed (never patched in the 1.26.x line 3.21 had).
apk_install "nginx=1.30.3-r0"

# Alpine's nginx package creates the nginx user — verify it landed
getent passwd nginx > /dev/null 2>&1 || die "nginx user missing after package install"
log "component/nginx: nginx user ok"

# Apply staged configs (staged by Packer file provisioner)
[ -f /tmp/if_nginx.conf ] \
    || die "nginx.conf not staged — check file provisioner in image.pkr.hcl"
[ -f /tmp/if_nginx_default.conf ] \
    || die "default.conf not staged — check file provisioner in image.pkr.hcl"

install -m 640 -o root -g nginx /tmp/if_nginx.conf /etc/nginx/nginx.conf
mkdir -p /etc/nginx/conf.d
install -m 640 -o root -g nginx /tmp/if_nginx_default.conf /etc/nginx/conf.d/default.conf

rm -f /tmp/if_nginx.conf /tmp/if_nginx_default.conf

# Webroot
mkdir -p /var/www/html
chown -R nginx:nginx /var/www/html
chmod 750 /var/www/html

# Log dirs — nginx will write here if logging isn't redirected to /dev/stdout
mkdir -p /var/log/nginx
chown -R nginx:nginx /var/log/nginx

# Runtime dirs nginx needs to start
mkdir -p \
    /var/lib/nginx/tmp/client_body \
    /var/lib/nginx/tmp/fastcgi \
    /var/lib/nginx/tmp/proxy \
    /var/lib/nginx/tmp/scgi \
    /var/lib/nginx/tmp/uwsgi
chown -R nginx:nginx /var/lib/nginx

# PID dir
mkdir -p /var/run
chown root:nginx /var/run
chmod 775 /var/run

log "component/nginx: validating config"
nginx -t || die "nginx config validation failed"

log "component/nginx: done"
