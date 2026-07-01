#!/bin/sh
# Hardening pass 1 — remove unnecessary Alpine base packages
# Runs before any component installs. apk-tools stays until the strip step.

. /tmp/forge-lib/common.sh
. /tmp/forge-lib/apk.sh

require_root
log "hardening: removing unnecessary base packages"

# These are pulled in by Alpine base but have no role in a container runtime
apk_del \
    acct \
    alpine-baselayout-data \
    iproute2-ss \
    sysfsutils \
    openrc \
    logrotate \
    kbd \
    mdadm \
    lvm2 \
    pciutils \
    usbutils \
    wireless-tools \
    wpa_supplicant

# Remove docs and man pages — nothing to read in a production container
rm -rf /usr/share/man /usr/share/doc /usr/share/info

log "hardening: base package cleanup done"
