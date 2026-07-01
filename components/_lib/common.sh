#!/bin/sh
# Forge — shared shell utilities
# All component install scripts source this first

log()  { printf '[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"; }
die()  { log "FATAL: $*" >&2; exit 1; }
warn() { log "WARN: $*" >&2; }

require_root() {
    [ "$(id -u)" -eq 0 ] || die "must run as root"
}

verify_checksum() {
    _chk_actual=$(sha256sum "$1" | cut -d' ' -f1)
    [ "$_chk_actual" = "$2" ] || die "checksum mismatch on $1 — got $_chk_actual, expected $2"
    log "checksum ok: $1"
}

# Strip SUID/SGID bits from all files under a path
strip_suid() {
    find "${1:-/}" \( -perm /4000 -o -perm /2000 \) -type f 2>/dev/null | while IFS= read -r _f; do
        log "stripping SUID/SGID: $_f"
        chmod a-s "$_f"
    done
}

# Lock an account — set shell to nologin, expire password
lock_account() {
    if getent passwd "$1" > /dev/null 2>&1; then
        # Change shell field (field 7 of /etc/passwd) — busybox has no usermod
        sed -i "/^${1}:/s|:[^:]*$|:/sbin/nologin|" /etc/passwd
        passwd -l "$1" 2>/dev/null || true
        log "locked account: $1"
    fi
}

# Remove an account entirely if it exists
remove_account() {
    if getent passwd "$1" > /dev/null 2>&1; then
        deluser "$1" 2>/dev/null && log "removed account: $1"
    fi
}

# Remove a group if it exists
remove_group() {
    if getent group "$1" > /dev/null 2>&1; then
        delgroup "$1" 2>/dev/null && log "removed group: $1"
    fi
}
