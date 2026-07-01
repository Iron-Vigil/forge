#!/bin/sh
# Component: aspnet-runtime10 — ASP.NET Core 10 runtime (web/service apps)
# Runtime BASE image: no config to stage; consumers layer their published app on top.

. /tmp/forge-lib/common.sh
. /tmp/forge-lib/apk.sh

require_root
log "component/aspnet-runtime10: installing"

# aspnetcore10-runtime pulls dotnet10-runtime (and all native deps: icu-libs,
# libssl3, libstdc++, lttng-ust, brotli, ...) so globalization works out of the box.
# ca-certificates-bundle (TLS) and tzdata (TimeZoneInfo by id) are NOT transitive;
# add them unpinned so every build gets current CA and timezone data.
apk_install "aspnetcore10-runtime=10.0.9-r0"
apk_install "ca-certificates-bundle" "tzdata"

# Non-root runtime user at uid/gid 1654 — matches the .NET ecosystem's APP_UID so
# consumer Dockerfiles and k8s runAsUser: 1654 line up.
addgroup -g 1654 app 2>/dev/null || true
adduser -u 1654 -G app -h /app -s /sbin/nologin -D -H app 2>/dev/null || true
getent passwd app > /dev/null 2>&1 || die "app user creation failed"
install -d -o app -g app -m 755 /app
log "component/aspnet-runtime10: app user + /app ready"

# Fail the build if the host/runtime can't resolve (lists .NETCore + AspNetCore).
/usr/lib/dotnet/dotnet --list-runtimes || die "dotnet runtime not functional"

log "component/aspnet-runtime10: done"
