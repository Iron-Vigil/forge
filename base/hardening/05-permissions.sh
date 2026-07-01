#!/bin/sh
# Hardening pass 5 — filesystem permissions
# Tighten world-writable dirs, set umask, restrict sensitive files

. /tmp/forge-lib/common.sh

require_root
log "hardening: tightening filesystem permissions"

# Sticky bit on world-writable directories
for d in /tmp /var/tmp; do
    if [ -d "$d" ]; then
        chmod 1777 "$d"
        log "sticky bit set on $d"
    fi
done

# Restrict passwd and shadow
chmod 644 /etc/passwd 2>/dev/null || true
chmod 000 /etc/shadow 2>/dev/null || true
chmod 644 /etc/group 2>/dev/null || true

# No world-writable files outside of /tmp and /var/tmp
find / -xdev -type f -perm -0002 \
    ! -path "/tmp/*" \
    ! -path "/var/tmp/*" \
    2>/dev/null | while read -r f; do
    log "removing world-write on: $f"
    chmod o-w "$f"
done

# Remove world-readable sensitive files if present
for f in /etc/crontab /etc/cron.d /var/spool/cron; do
    if [ -e "$f" ]; then
        chmod 600 "$f" 2>/dev/null || chmod 700 "$f" 2>/dev/null || true
        log "restricted: $f"
    fi
done

log "hardening: permissions done"
