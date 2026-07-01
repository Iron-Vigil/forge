#!/bin/sh
# Component: node — Node.js 24 runtime (no npm; consumers bring their node_modules)
# Runtime BASE image: no config to stage; layer your app on top.

. /tmp/forge-lib/common.sh
. /tmp/forge-lib/apk.sh

require_root
log "component/node: installing"

# nodejs pulls its native deps (libstdc++, icu-libs, openssl, c-ares, ...)
# transitively. ca-certificates-bundle (TLS) and tzdata are not transitive.
apk_install "nodejs=24.17.0-r0"
apk_install "ca-certificates-bundle" "tzdata"

# Non-root runtime user.
addgroup -g 1000 app 2>/dev/null || true
adduser -u 1000 -G app -h /app -s /sbin/nologin -D -H app 2>/dev/null || true
getent passwd app > /dev/null 2>&1 || die "app user creation failed"
install -d -o app -g app -m 755 /app
log "component/node: app user + /app ready"

node --version || die "node runtime not functional"

log "component/node: done"
