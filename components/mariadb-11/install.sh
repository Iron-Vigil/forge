#!/bin/sh
# Component: mariadb-11 — MariaDB 11.8 server (distroless, server-only).
# The data dir is a volume the operator / init-container initializes with
# mariadb-install-db; this image just runs mariadbd. Config staged to
# /tmp/if_mariadb.cnf.

. /tmp/forge-lib/common.sh
. /tmp/forge-lib/apk.sh

require_root
log "component/mariadb-11: installing"

apk_install "mariadb=11.8.8-r0"

# The mariadb package creates the mysql user; create it if it didn't.
addgroup -S mysql 2>/dev/null || true
adduser -S -D -H -h /var/lib/mysql -s /sbin/nologin -G mysql mysql 2>/dev/null || true
getent passwd mysql > /dev/null 2>&1 || die "mysql user missing"
log "component/mariadb-11: mysql user ok"

# Data dir, owned by mysql. Socket lives under the data dir (a persisted volume)
# so it survives a tmpfs /run in k8s.
install -d -o mysql -g mysql -m 750 /var/lib/mysql

# Our server config (bind all, datadir, socket in the volume).
[ -f /tmp/if_mariadb.cnf ] || die "my.cnf not staged — check file provisioner in image.pkr.hcl"
install -m 644 /tmp/if_mariadb.cnf /etc/my.cnf.d/60-forge.cnf
rm -f /tmp/if_mariadb.cnf

/usr/bin/mariadbd --version || die "mariadbd not functional"

log "component/mariadb-11: done"
