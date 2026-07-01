#!/bin/sh
# Hardening pass 4 — network sysctl hardening
# Docker containers share the host kernel but have their own network namespace.
# These settings apply within the container's namespace where supported.

. /tmp/forge-lib/common.sh

require_root
log "hardening: applying network sysctl settings"

sysctl_set() {
    if sysctl -w "${1}=${2}" > /dev/null 2>&1; then
        log "sysctl: ${1}=${2}"
    else
        warn "sysctl: ${1} not available in this context (skipping)"
    fi
}

# Disable IP source routing
sysctl_set net.ipv4.conf.all.accept_source_route 0
sysctl_set net.ipv4.conf.default.accept_source_route 0

# Disable ICMP redirects
sysctl_set net.ipv4.conf.all.accept_redirects 0
sysctl_set net.ipv4.conf.default.accept_redirects 0
sysctl_set net.ipv4.conf.all.send_redirects 0

# Enable reverse path filtering
sysctl_set net.ipv4.conf.all.rp_filter 1
sysctl_set net.ipv4.conf.default.rp_filter 1

# Log martian packets
sysctl_set net.ipv4.conf.all.log_martians 1

# Disable IPv6 if not required — individual images can re-enable via meta.yml flag
sysctl_set net.ipv6.conf.all.disable_ipv6 1
sysctl_set net.ipv6.conf.default.disable_ipv6 1

# Protect against SYN flood
sysctl_set net.ipv4.tcp_syncookies 1

log "hardening: network sysctl done"
