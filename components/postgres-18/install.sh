#!/bin/sh
# Component: postgres-18 — PostgreSQL 18 server (distroless, server-only).
# The data dir is a volume the operator / init-container initializes with initdb;
# this image just runs the server. Postgres refuses to run as root, so USER is
# set to postgres in the image config.

. /tmp/forge-lib/common.sh
. /tmp/forge-lib/apk.sh

require_root
log "component/postgres-18: installing"

apk_install "postgresql18=18.4-r0"

# postgresql-common (a dep) creates the postgres user; create it if it didn't.
addgroup -S postgres 2>/dev/null || true
adduser -S -D -H -h /var/lib/postgresql -s /sbin/nologin -G postgres postgres 2>/dev/null || true
getent passwd postgres > /dev/null 2>&1 || die "postgres user missing"
log "component/postgres-18: postgres user ok"

# Data-dir mountpoint, owned by postgres, 0700 (postgres refuses looser perms).
install -d -o postgres -g postgres -m 700 /var/lib/postgresql/data

/usr/libexec/postgresql18/postgres --version || die "postgres binary not functional"

log "component/postgres-18: done"
