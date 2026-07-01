#!/bin/sh
# Hardening pass 2 — remove or lock unnecessary system accounts
# Alpine base ships with accounts that have no role in a container

. /tmp/forge-lib/common.sh

require_root
log "hardening: locking/removing unnecessary system accounts"

# Accounts with no runtime role — lock them
for u in bin daemon adm lp sync shutdown halt operator games news uucp; do
    lock_account "$u"
done

# ftp and guest can go entirely
remove_account ftp
remove_account guest

# Groups with no runtime role
for g in games news uucp; do
    remove_group "$g"
done

# nobody should not have a writable home
if getent passwd nobody > /dev/null 2>&1; then
    sed -i '/^nobody:/s|:[^:]*:[^:]*$|:/nonexistent:/sbin/nologin|' /etc/passwd
    log "nobody home dir set to /nonexistent"
fi

# Root locked in containers — processes should not run as root
passwd -l root 2>/dev/null || true
log "root account locked"

log "hardening: account cleanup done"
