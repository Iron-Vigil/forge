#!/bin/sh
# Component: postgres-18-init — PostgreSQL 18 + first-run init entrypoint.
# NOT distroless: keeps /bin/sh + su-exec so the entrypoint can initialize the
# data dir and drop privileges. Entrypoint staged to /tmp/if_entrypoint.sh.

. /tmp/forge-lib/common.sh
. /tmp/forge-lib/apk.sh

require_root
log "component/postgres-18-init: installing"

apk_install "postgresql18=18.4-r0" "postgresql18-client=18.4-r0"
apk_install "su-exec"

addgroup -S postgres 2>/dev/null || true
adduser -S -D -H -h /var/lib/postgresql -s /sbin/nologin -G postgres postgres 2>/dev/null || true
getent passwd postgres > /dev/null 2>&1 || die "postgres user missing"

install -d -o postgres -g postgres -m 700 /var/lib/postgresql/data
install -d -m 755 /docker-entrypoint-initdb.d
# postgres opens its socket + lock file here (compiled-in default). Seed it in
# the image; the entrypoint recreates it at runtime in case /run is a tmpfs.
install -d -o postgres -g postgres -m 2775 /run/postgresql

[ -f /tmp/if_entrypoint.sh ] || die "entrypoint not staged — check file provisioner"
install -m 755 /tmp/if_entrypoint.sh /usr/local/bin/docker-entrypoint.sh
rm -f /tmp/if_entrypoint.sh

/usr/libexec/postgresql18/postgres --version || die "postgres binary not functional"

log "component/postgres-18-init: done"
