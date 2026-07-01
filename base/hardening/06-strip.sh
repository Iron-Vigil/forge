#!/bin/sh
# Hardening pass 6 — final strip (distroless target)
# This runs LAST. After this, no shell or apk. Image is committed immediately after.
#
# NOTE: We remove shell symlinks and network tools but keep /bin/busybox itself.
# Packer needs to run `rm` on its temp script after this provisioner exits.
# Busybox still provides rm/find/date via applets — we just sever the shell entry points.

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

# Remove shell entry points — rm/date/find remain via busybox applets
# /bin/ash and /bin/sh are the shell binaries; remove them explicitly
rm -f /bin/ash /bin/sh

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

log "hardening: strip complete — shell removed, apk removed, image ready for commit"
# Packer removes its own /tmp/script_xxx.sh after this exits — rm is still available via busybox
