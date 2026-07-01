#!/bin/sh
# Build valkey-server from source inside Alpine 3.21.
# Reads:  /build/{version,sha256}
# Writes: /output/valkey-server

set -eu

WORKDIR=/tmp/build
mkdir -p "$WORKDIR" /output
cd "$WORKDIR"

VERSION=$(cat /build/version)
TARBALL="valkey-${VERSION}.tar.gz"
URL="https://github.com/valkey-io/valkey/archive/refs/tags/${VERSION}.tar.gz"

apk add --no-cache gcc musl-dev make openssl-dev linux-headers wget

echo "Fetching ${URL}"
wget -q -O "$TARBALL" "$URL"

EXPECTED=$(awk '{print $1}' /build/sha256)
if [ "$EXPECTED" = "PLACEHOLDER" ]; then
    echo "ERROR: sources/valkey/sha256 contains PLACEHOLDER — compute and replace it:"
    echo "  sha256sum ${TARBALL}"
    exit 1
fi
echo "${EXPECTED}  ${TARBALL}" | sha256sum -c -
echo "SHA256 OK"

tar xzf "$TARBALL"
cd "valkey-${VERSION}"

OPT="-O2 -fstack-protector-strong -fPIE -D_FORTIFY_SOURCE=2 -Wformat -Wformat-security"
LDFLAGS="-Wl,-z,relro -Wl,-z,now -pie"

make BUILD_TLS=yes USE_SYSTEMD=no MALLOC=libc \
    OPT="$OPT" LDFLAGS="$LDFLAGS" \
    -j$(nproc)

install -Dm755 src/valkey-server /output/valkey-server

echo "Built: /output/valkey-server"
/output/valkey-server --version
