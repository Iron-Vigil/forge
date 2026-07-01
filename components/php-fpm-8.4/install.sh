#!/bin/sh
# Component: php-fpm-8.4 — PHP-FPM 8.4 with the common-web extension set.
# Runs behind nginx over FastCGI (:9000). Pool config staged to /tmp/if_php_www.conf.

. /tmp/forge-lib/common.sh
. /tmp/forge-lib/apk.sh

require_root
log "component/php-fpm-8.4: installing"

# Pin php-fpm as the version anchor (Renovate tracks it). Extensions are left
# unpinned on purpose: each depends on php84-common, so apk resolves them to the
# same version as the pinned fpm — they can't drift within the Alpine branch.
apk_install "php84-fpm=8.4.22-r0"
apk_install \
    "php84-opcache" "php84-pdo" "php84-pdo_mysql" "php84-mysqli" \
    "php84-mbstring" "php84-curl" "php84-gd" "php84-intl" "php84-zip" \
    "php84-dom" "php84-xml" "php84-simplexml" "php84-bcmath" "php84-fileinfo" \
    "php84-session" "php84-ctype" "php84-iconv" "php84-phar" "php84-tokenizer" \
    "php84-openssl"
apk_install "ca-certificates-bundle" "tzdata"

# Non-root runtime user. fpm master + workers both run as app (no setuid needed).
addgroup -g 1000 app 2>/dev/null || true
adduser -u 1000 -G app -h /app -s /sbin/nologin -D -H app 2>/dev/null || true
getent passwd app > /dev/null 2>&1 || die "app user creation failed"
install -d -o app -g app -m 755 /app
log "component/php-fpm-8.4: app user + /app ready"

# Our pool config replaces the stock www.conf.
[ -f /tmp/if_php_www.conf ] || die "www.conf not staged — check file provisioner"
install -m 644 /tmp/if_php_www.conf /etc/php84/php-fpm.d/www.conf
rm -f /tmp/if_php_www.conf

php-fpm84 -t || die "php-fpm config test failed"

log "component/php-fpm-8.4: done"
