#!/bin/sh
# Hardening pass 3 — strip SUID/SGID bits
# Allowlist anything that legitimately needs it; strip everything else

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/../../components/_lib/common.sh"

require_root
log "hardening: stripping SUID/SGID bits"

find / \( -perm /4000 -o -perm /2000 \) -type f 2>/dev/null | while IFS= read -r _f; do
    case "$_f" in
        /bin/su|/usr/bin/newgrp|/usr/bin/passwd)
            log "SUID/SGID allowed: $_f"
            ;;
        *)
            log "stripping SUID/SGID: $_f"
            chmod a-s "$_f"
            ;;
    esac
done

log "hardening: SUID/SGID strip done"
