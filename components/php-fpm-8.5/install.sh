#!/bin/sh
# Component: php-fpm-8.5 — PHP-FPM 8.5 with the common-web extension set.
# Runs behind nginx over FastCGI (:9000). Pool config staged to /tmp/if_php_www.conf.

. /tmp/forge-lib/common.sh
. /tmp/forge-lib/apk.sh

require_root
log "component/php-fpm-8.5: installing"

# Pin php-fpm as the version anchor (Renovate tracks it). Extensions are left
# unpinned on purpose: each depends on php85-common, so apk resolves them to the
# same version as the pinned fpm — they can't drift within the Alpine branch.
apk_install "php85-fpm=8.5.7-r0"
apk_install \
    "php85-opcache" "php85-pdo" "php85-pdo_mysql" "php85-mysqli" \
    "php85-mbstring" "php85-curl" "php85-gd" "php85-intl" "php85-zip" \
    "php85-dom" "php85-xml" "php85-simplexml" "php85-bcmath" "php85-fileinfo" \
    "php85-session" "php85-ctype" "php85-iconv" "php85-phar" "php85-tokenizer" \
    "php85-openssl"
apk_install "ca-certificates-bundle" "tzdata"

# Non-root runtime user. fpm master + workers both run as app (no setuid needed).
addgroup -g 1000 app 2>/dev/null || true
adduser -u 1000 -G app -h /app -s /sbin/nologin -D -H app 2>/dev/null || true
getent passwd app > /dev/null 2>&1 || die "app user creation failed"
install -d -o app -g app -m 755 /app
log "component/php-fpm-8.5: app user + /app ready"

# Our pool config replaces the stock www.conf.
[ -f /tmp/if_php_www.conf ] || die "www.conf not staged — check file provisioner"
install -m 644 /tmp/if_php_www.conf /etc/php85/php-fpm.d/www.conf
rm -f /tmp/if_php_www.conf

php-fpm85 -t || die "php-fpm config test failed"

log "component/php-fpm-8.5: done"
