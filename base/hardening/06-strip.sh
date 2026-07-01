#!/bin/sh
# Hardening pass 6 — final strip (distroless target)
# This runs LAST. After this, no shell, no apk. Image is committed immediately after.
# Do not add steps after this in the Packer build sequence.

. /tmp/forge-lib/common.sh
. /tmp/forge-lib/apk.sh

require_root
log "hardening: beginning final strip — this is the point of no return"

# Remove package manager — nothing installs after this
apk_selfremove

# Remove shell and interactive utilities
# busybox provides most of these on Alpine
log "removing shell and interactive utilities"
rm -f \
    /bin/ash \
    /bin/sh \
    /bin/busybox \
    /usr/bin/env \
    /sbin/apk \
    /usr/bin/wget \
    /usr/bin/curl \
    /usr/bin/nc \
    /usr/bin/ncat \
    /usr/bin/telnet \
    /usr/bin/ftp \
    /usr/bin/tftp

# Remove compilers and build tooling if somehow present
rm -f /usr/bin/gcc /usr/bin/g++ /usr/bin/make /usr/bin/ld /usr/bin/ar

# Clear caches and temp
rm -rf /tmp/* /var/tmp/* /root/.cache /home/*/.cache

# Remove history files
find / -name ".*history" -delete 2>/dev/null || true
find / -name ".bash_history" -delete 2>/dev/null || true

log "hardening: strip complete"
# Shell is gone after this line returns — Packer commits the container
