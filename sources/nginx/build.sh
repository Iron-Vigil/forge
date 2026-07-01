#!/bin/sh
# Build nginx from source inside Alpine 3.21.
# Reads:  /build/{version,sha256,pgp-key.asc}
# Writes: /output/nginx
#
# Deliberately excludes --with-http_v2_module — eliminates HTTP/2 attack surface
# (e.g. CVE-2026-42055) at the binary level.

set -eu

WORKDIR=/tmp/build
mkdir -p "$WORKDIR" /output
cd "$WORKDIR"

VERSION=$(cat /build/version)
TARBALL="nginx-${VERSION}.tar.gz"
URL="https://nginx.org/download/${TARBALL}"

apk add --no-cache gcc musl-dev make perl pcre2-dev zlib-dev openssl-dev linux-headers gnupg wget

echo "Fetching ${URL}"
wget -q -O "$TARBALL" "$URL"

EXPECTED=$(awk '{print $1}' /build/sha256)
if [ "$EXPECTED" = "PLACEHOLDER" ]; then
    echo "ERROR: sources/nginx/sha256 contains PLACEHOLDER — compute and replace it:"
    echo "  sha256sum ${TARBALL}"
    exit 1
fi
echo "${EXPECTED}  ${TARBALL}" | sha256sum -c -
echo "SHA256 OK"

if [ -s /build/pgp-key.asc ]; then
    gpg --import /build/pgp-key.asc
    wget -q -O "${TARBALL}.asc" "${URL}.asc"
    gpg --verify "${TARBALL}.asc" "$TARBALL"
    echo "PGP OK"
else
    echo "WARN: pgp-key.asc is empty — skipping PGP verification"
fi

tar xzf "$TARBALL"
cd "nginx-${VERSION}"

CFLAGS="-O2 -fstack-protector-strong -fPIE -D_FORTIFY_SOURCE=2 -Wformat -Wformat-security"
LDFLAGS="-Wl,-z,relro -Wl,-z,now -pie"

./configure \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --http-client-body-temp-path=/var/lib/nginx/tmp/client_body \
    --http-proxy-temp-path=/var/lib/nginx/tmp/proxy \
    --http-fastcgi-temp-path=/var/lib/nginx/tmp/fastcgi \
    --http-scgi-temp-path=/var/lib/nginx/tmp/scgi \
    --http-uwsgi-temp-path=/var/lib/nginx/tmp/uwsgi \
    --user=nginx \
    --group=nginx \
    --with-pcre \
    --with-http_ssl_module \
    --with-http_realip_module \
    --with-http_stub_status_module \
    --with-http_auth_request_module \
    --with-http_gzip_static_module \
    --without-http_autoindex_module \
    --without-http_browser_module \
    --without-http_geo_module \
    --without-http_map_module \
    --without-http_memcached_module \
    --without-http_split_clients_module \
    --without-http_ssi_module \
    --without-http_userid_module \
    --without-http_uwsgi_module \
    --without-http_scgi_module \
    --without-http_grpc_module \
    CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS"

make -j$(nproc)
install -Dm755 objs/nginx /output/nginx

echo "Built: /output/nginx"
/output/nginx -v
