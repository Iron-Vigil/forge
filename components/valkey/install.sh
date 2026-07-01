#!/bin/sh
# Component: valkey
# Configs are staged to /tmp/if_valkey.conf by the Packer file provisioner before this runs

. /tmp/forge-lib/common.sh
. /tmp/forge-lib/apk.sh

require_root
log "component/valkey: installing"

apk_install "libssl3"

addgroup -S valkey 2>/dev/null || true
mkdir -p /var/lib/valkey /etc/valkey
adduser -S -D -h /var/lib/valkey -s /sbin/nologin -G valkey valkey 2>/dev/null || true
getent passwd valkey > /dev/null 2>&1 || die "valkey user creation failed"
log "component/valkey: valkey user ok"

[ -f /tmp/forge-src-valkey ] \
    || die "valkey-server binary not staged — check file provisioner in image.pkr.hcl and build-sources.yml"
install -Dm755 /tmp/forge-src-valkey /usr/bin/valkey-server
rm -f /tmp/forge-src-valkey

# Apply staged config
[ -f /tmp/if_valkey.conf ] \
    || die "valkey.conf not staged — check file provisioner in image.pkr.hcl"

install -m 640 -o root -g valkey /tmp/if_valkey.conf /etc/valkey/valkey.conf
rm -f /tmp/if_valkey.conf

# Data dir
chown -R valkey:valkey /var/lib/valkey
chmod 750 /var/lib/valkey

# Remove the sentinel config and valkey.d — not used in this image
rm -f /etc/valkey/sentinel.conf
rmdir /etc/valkey/valkey.d 2>/dev/null || true

log "component/valkey: done"
