#!/bin/sh
# Component: php-fpm-8.3 — PHP-FPM 8.3 with the common-web extension set.
# Runs behind nginx over FastCGI (:9000). Pool config staged to /tmp/if_php_www.conf.

. /tmp/forge-lib/common.sh
. /tmp/forge-lib/apk.sh

require_root
log "component/php-fpm-8.3: installing"

# Pin php-fpm as the version anchor (Renovate tracks it). Extensions are left
# unpinned on purpose: each depends on php83-common, so apk resolves them to the
# same version as the pinned fpm — they can't drift within the Alpine branch.
apk_install "php83-fpm=8.3.31-r1"
apk_install \
    "php83-opcache" "php83-pdo" "php83-pdo_mysql" "php83-mysqli" \
    "php83-mbstring" "php83-curl" "php83-gd" "php83-intl" "php83-zip" \
    "php83-dom" "php83-xml" "php83-simplexml" "php83-bcmath" "php83-fileinfo" \
    "php83-session" "php83-ctype" "php83-iconv" "php83-phar" "php83-tokenizer" \
    "php83-openssl"
apk_install "ca-certificates-bundle" "tzdata"

# Non-root runtime user. fpm master + workers both run as app (no setuid needed).
addgroup -g 1000 app 2>/dev/null || true
adduser -u 1000 -G app -h /app -s /sbin/nologin -D -H app 2>/dev/null || true
getent passwd app > /dev/null 2>&1 || die "app user creation failed"
install -d -o app -g app -m 755 /app
log "component/php-fpm-8.3: app user + /app ready"

# Our pool config replaces the stock www.conf.
[ -f /tmp/if_php_www.conf ] || die "www.conf not staged — check file provisioner"
install -m 644 /tmp/if_php_www.conf /etc/php83/php-fpm.d/www.conf
rm -f /tmp/if_php_www.conf

php-fpm83 -t || die "php-fpm config test failed"

log "component/php-fpm-8.3: done"
