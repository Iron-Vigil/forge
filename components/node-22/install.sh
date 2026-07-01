#!/bin/sh
# Component: node-22 — Node.js 22 LTS runtime (no npm; consumers bring node_modules)
# Back-version: built on Alpine 3.22 (the last stable branch that packages nodejs 22).

. /tmp/forge-lib/common.sh
. /tmp/forge-lib/apk.sh

require_root
log "component/node-22: installing"

# nodejs pulls its native deps (libstdc++, icu-libs, openssl, c-ares, ...)
# transitively. ca-certificates-bundle (TLS) and tzdata are not transitive.
apk_install "nodejs=22.23.0-r0"
apk_install "ca-certificates-bundle" "tzdata"

# Non-root runtime user.
addgroup -g 1000 app 2>/dev/null || true
adduser -u 1000 -G app -h /app -s /sbin/nologin -D -H app 2>/dev/null || true
getent passwd app > /dev/null 2>&1 || die "app user creation failed"
install -d -o app -g app -m 755 /app
log "component/node-22: app user + /app ready"

node --version || die "node runtime not functional"

log "component/node-22: done"
