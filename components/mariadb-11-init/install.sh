#!/bin/sh
# Component: mariadb-11-init — MariaDB 11.8 + first-run init entrypoint.
# NOT distroless: keeps /bin/sh + su-exec. Entrypoint staged to /tmp/if_entrypoint.sh.

. /tmp/forge-lib/common.sh
. /tmp/forge-lib/apk.sh

require_root
log "component/mariadb-11-init: installing"

apk_install "mariadb=11.8.8-r0" "mariadb-client=11.8.8-r0"
apk_install "su-exec"

addgroup -S mysql 2>/dev/null || true
adduser -S -D -H -h /var/lib/mysql -s /sbin/nologin -G mysql mysql 2>/dev/null || true
getent passwd mysql > /dev/null 2>&1 || die "mysql user missing"

install -d -o mysql -g mysql -m 750 /var/lib/mysql
install -d -m 755 /docker-entrypoint-initdb.d

# Server config (bind all, datadir, socket in the volume). The temp init server
# overrides socket + networking on the CLI; this is what the final mariadbd reads.
[ -f /tmp/if_mariadb.cnf ] || die "my.cnf not staged — check file provisioner in image.pkr.hcl"
install -m 644 /tmp/if_mariadb.cnf /etc/my.cnf.d/60-forge.cnf
rm -f /tmp/if_mariadb.cnf

# Alpine ships mariadb-server.cnf with a bare `skip-networking` (TCP off). The
# includedir loads it AFTER our 60-forge.cnf (digits sort before letters), so it
# wins and the server never listens on TCP. Kill the stock line so ours sticks.
sed -i 's/^skip-networking/#skip-networking/' /etc/my.cnf.d/mariadb-server.cnf

[ -f /tmp/if_entrypoint.sh ] || die "entrypoint not staged — check file provisioner"
install -m 755 /tmp/if_entrypoint.sh /usr/local/bin/docker-entrypoint.sh
rm -f /tmp/if_entrypoint.sh

/usr/bin/mariadbd --version || die "mariadbd not functional"

log "component/mariadb-11-init: done"
