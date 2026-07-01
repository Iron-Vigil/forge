#!/bin/sh
# Component: nginx
# Configs are staged to /tmp/if_nginx_* by the Packer file provisioner before this runs

. /tmp/forge-lib/common.sh
. /tmp/forge-lib/apk.sh

require_root
log "component/nginx: installing"

apk_install "pcre2 zlib libssl3"

addgroup -S nginx 2>/dev/null || true
adduser -S -D -H -h /dev/null -s /sbin/nologin -G nginx -g nginx nginx 2>/dev/null || true
getent passwd nginx > /dev/null 2>&1 || die "nginx user creation failed"
log "component/nginx: nginx user ok"

[ -f /tmp/forge-src-nginx ] \
    || die "nginx binary not staged — check file provisioner in image.pkr.hcl and build-sources.yml"
install -Dm755 /tmp/forge-src-nginx /usr/sbin/nginx
rm -f /tmp/forge-src-nginx

# Apply staged configs (staged by Packer file provisioner)
[ -f /tmp/if_nginx.conf ] \
    || die "nginx.conf not staged — check file provisioner in image.pkr.hcl"
[ -f /tmp/if_nginx_default.conf ] \
    || die "default.conf not staged — check file provisioner in image.pkr.hcl"
# Source build ships only the binary, so mime.types (normally from the tarball's
# conf/) must be staged here or nginx.conf's include fails validation.
[ -f /tmp/if_nginx_mime.types ] \
    || die "mime.types not staged — check file provisioner in image.pkr.hcl"

mkdir -p /etc/nginx/conf.d
install -m 640 -o root -g nginx /tmp/if_nginx.conf /etc/nginx/nginx.conf
install -m 640 -o root -g nginx /tmp/if_nginx_default.conf /etc/nginx/conf.d/default.conf
install -m 644 -o root -g nginx /tmp/if_nginx_mime.types /etc/nginx/mime.types

rm -f /tmp/if_nginx.conf /tmp/if_nginx_default.conf /tmp/if_nginx_mime.types

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
