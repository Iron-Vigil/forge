#!/bin/sh
# Component: openssh
# Installs and configures OpenSSH server with hardened defaults

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/../_lib/common.sh"
. "${SCRIPT_DIR}/../_lib/apk.sh"

require_root
log "component/openssh: installing"

# Pin exact version — Renovate will open a PR when a newer build is available
apk_install "openssh=9.9_p2-r0"

log "component/openssh: applying hardened sshd_config"
[ -f /tmp/if_sshd_config ] \
    || die "sshd_config not staged — check file provisioner in image.pkr.hcl"
install -m 600 /tmp/if_sshd_config /etc/ssh/sshd_config
rm -f /tmp/if_sshd_config

# Generate host keys — do this at build time so the image isn't waiting on first boot
log "component/openssh: generating host keys"
ssh-keygen -A

# Privilege separation dir
mkdir -p /var/empty/sshd
chmod 711 /var/empty
chmod 711 /var/empty/sshd
chown root:root /var/empty /var/empty/sshd

# sshd requires the privilege separation user
if ! getent passwd sshd > /dev/null 2>&1; then
    adduser -D -s /sbin/nologin -H -h /var/empty/sshd sshd
    log "component/openssh: sshd user created"
fi

log "component/openssh: done"
