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
# Valkey 7.2.x publishes no signed release asset — the git tag archive is the
# only upstream source. GitHub auto-archives aren't guaranteed byte-stable, so
# the pinned sha256 is the integrity gate: if GitHub re-rolls the archive the
# checksum breaks the build (fail-closed) rather than silently accepting it.
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

apk add --no-cache binutils
echo "Verifying hardening landed:"
readelf -d /output/valkey-server | grep -q 'BIND_NOW' || { echo "FAIL: no BIND_NOW (relro/now missing)"; exit 1; }
readelf -h /output/valkey-server | grep -q 'DYN' || { echo "FAIL: not PIE"; exit 1; }
readelf -s /output/valkey-server | grep -q '__stack_chk_fail' || { echo "FAIL: no stack protector"; exit 1; }
echo "Hardening OK: PIE + BIND_NOW + stack protector present"

echo "Built: /output/valkey-server"
/output/valkey-server --version
