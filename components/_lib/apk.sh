#!/bin/sh
# Forge — APK wrapper
# Enforces exact version pins, logs every install, fails loud

. /tmp/forge-lib/common.sh

# Install one or more packages — caller must pass exact version pins
# e.g. apk_install "nginx=1.26.2-r0" "nginx-mod-http-headers-more=1.26.2-r0"
apk_install() {
    require_root
    log "apk add: $*"
    apk add --no-cache "$@" || die "apk install failed: $*"
}

# Remove packages — non-fatal if package isn't installed
apk_del() {
    log "apk del: $*"
    apk del --no-cache --purge "$@" 2>/dev/null || true
}

# Resolve latest version of a package — for use during version discovery only,
# not in install scripts. Install scripts must hard-pin the version string.
apk_latest() {
    apk search --exact "$1" 2>/dev/null | head -1
}

# Remove apk itself — call this as the very last step of the strip provisioner
# Nothing can install packages after this runs
apk_selfremove() {
    require_root
    log "removing apk-tools from final image"
    apk del --no-cache --purge apk-tools 2>/dev/null || true
    rm -rf /var/cache/apk /var/lib/apk /etc/apk
    log "apk removed"
}
