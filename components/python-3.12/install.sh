#!/bin/sh
# Component: python-3.12 — CPython 3.12 runtime (no pip; consumers bring their deps)
# Back-version: built on Alpine 3.23 (the last stable branch that packages python 3.12).

. /tmp/forge-lib/common.sh
. /tmp/forge-lib/apk.sh

require_root
log "component/python-3.12: installing"

# python3 pulls its native deps (libssl, libffi, sqlite-libs, ...) transitively.
# ca-certificates-bundle (TLS) and tzdata are not transitive — add them unpinned.
apk_install "python3=3.12.13-r0"
apk_install "ca-certificates-bundle" "tzdata"

# Non-root runtime user.
addgroup -g 1000 app 2>/dev/null || true
adduser -u 1000 -G app -h /app -s /sbin/nologin -D -H app 2>/dev/null || true
getent passwd app > /dev/null 2>&1 || die "app user creation failed"
install -d -o app -g app -m 755 /app
log "component/python-3.12: app user + /app ready"

python3 --version || die "python runtime not functional"

log "component/python-3.12: done"
