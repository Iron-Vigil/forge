#!/bin/sh
# Component: python — CPython 3.14 runtime (no pip; consumers bring their own deps)
# Runtime BASE image: no config to stage; layer your app on top.

. /tmp/forge-lib/common.sh
. /tmp/forge-lib/apk.sh

require_root
log "component/python: installing"

# python3 pulls its native deps (libssl, libffi, sqlite-libs, ...) transitively.
# ca-certificates-bundle (TLS) and tzdata are not transitive — add them unpinned
# so every build gets current CA and timezone data.
apk_install "python3=3.14.5-r0"
apk_install "ca-certificates-bundle" "tzdata"

# Non-root runtime user.
addgroup -g 1000 app 2>/dev/null || true
adduser -u 1000 -G app -h /app -s /sbin/nologin -D -H app 2>/dev/null || true
getent passwd app > /dev/null 2>&1 || die "app user creation failed"
install -d -o app -g app -m 755 /app
log "component/python: app user + /app ready"

python3 --version || die "python runtime not functional"

log "component/python: done"
