#!/bin/sh
# Component: valkey-8 — Valkey 8.1 cache
# Back-version: built on Alpine 3.22 (packages valkey 8.1). Config staged to /tmp/if_valkey.conf.

. /tmp/forge-lib/common.sh
. /tmp/forge-lib/apk.sh

require_root
log "component/valkey-8: installing"

apk_install "valkey=8.1.7-r0"

# Package creates the valkey user — verify it landed
getent passwd valkey > /dev/null 2>&1 || die "valkey user missing after package install"
log "component/valkey-8: valkey user ok"

# Apply staged config
[ -f /tmp/if_valkey.conf ] \
    || die "valkey.conf not staged — check file provisioner in image.pkr.hcl"

install -m 640 -o root -g valkey /tmp/if_valkey.conf /etc/valkey/valkey.conf
rm -f /tmp/if_valkey.conf

# Data dir — already created by package, just enforce ownership and permissions
chown -R valkey:valkey /var/lib/valkey
chmod 750 /var/lib/valkey

# Remove the sentinel config and valkey.d — not used in this image
rm -f /etc/valkey/sentinel.conf
rmdir /etc/valkey/valkey.d 2>/dev/null || true

log "component/valkey-8: done"
