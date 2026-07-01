#!/bin/sh
# Hardening pass 6 — final strip
# Runs last. Removes apk, compilers, caches, network tools.
# Does NOT remove /bin/sh — Packer needs it for post-script cleanup.

. /tmp/forge-lib/common.sh
. /tmp/forge-lib/apk.sh

require_root
log "hardening: beginning final strip — this is the point of no return"

# Remove package manager — nothing installs after this
apk_selfremove

# Remove compilers and build tooling first (while rm still works)
rm -f /usr/bin/gcc /usr/bin/g++ /usr/bin/make /usr/bin/ld /usr/bin/ar

# Clear caches and temp (keep /tmp itself — Packer needs it for script cleanup)
rm -rf /var/tmp/* /root/.cache /home/*/.cache
rm -rf /var/cache/apk /var/lib/apk /etc/apk

# Remove history files
find / -xdev -name ".*history" -delete 2>/dev/null || true

# Remove network tools (symlinks to busybox — removing these leaves busybox intact)
rm -f \
    /usr/bin/wget \
    /usr/bin/curl \
    /usr/bin/nc \
    /usr/bin/ncat \
    /usr/bin/telnet \
    /usr/bin/ftp \
    /usr/bin/tftp \
    /usr/bin/env

# Clean staging lib — all scripts are done
rm -rf /tmp/forge-lib

log "hardening: strip complete — apk removed, network tools removed, image ready for commit"
