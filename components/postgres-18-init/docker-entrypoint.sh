#!/bin/sh
# First-run init entrypoint for hardened-postgres:18-init.
# Adapted from the official postgres docker-entrypoint. Initializes an empty data
# dir once, sets the superuser password, runs /docker-entrypoint-initdb.d, then
# execs the server. Fails closed if no password is given and auth isn't 'trust'.
set -eu

PGDATA="${PGDATA:-/var/lib/postgresql/data}"
PGBIN=/usr/libexec/postgresql18

# Read VAR, or VAR_FILE (docker/k8s secret). Refuse if both are set.
file_env() {
    var="$1"
    fileVar="${var}_FILE"
    eval "val=\${$var:-}"
    eval "valFile=\${$fileVar:-}"
    if [ -n "$val" ] && [ -n "$valFile" ]; then
        echo "entrypoint: both $var and $fileVar are set; pick one" >&2
        exit 1
    fi
    [ -n "$valFile" ] && val="$(cat "$valFile")"
    eval "export $var=\"\$val\""
    unset "$fileVar" 2>/dev/null || true
}

# Started as root: own the data dir, then drop to postgres and re-exec ourselves.
# (postgres refuses to run as root, so the server never does.)
if [ "$(id -u)" = "0" ]; then
    mkdir -p "$PGDATA"
    chown postgres:postgres "$PGDATA"
    chmod 700 "$PGDATA"
    # Socket + lock dir for the final server; recreate every start so a tmpfs
    # /run doesn't leave postgres unable to open its listen socket.
    install -d -o postgres -g postgres -m 2775 /run/postgresql
    exec su-exec postgres "$0" "$@"
fi

file_env POSTGRES_PASSWORD
file_env POSTGRES_USER
file_env POSTGRES_DB
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-$POSTGRES_USER}"
AUTH="${POSTGRES_HOST_AUTH_METHOD:-scram-sha-256}"

# First run only — an initialized cluster leaves PG_VERSION in PGDATA.
if [ ! -s "$PGDATA/PG_VERSION" ]; then
    if [ -z "${POSTGRES_PASSWORD:-}" ] && [ "$AUTH" != "trust" ]; then
        echo "entrypoint: refusing to initialize without a password." >&2
        echo "  set POSTGRES_PASSWORD (or POSTGRES_PASSWORD_FILE), or" >&2
        echo "  set POSTGRES_HOST_AUTH_METHOD=trust to explicitly allow unauthenticated access." >&2
        exit 1
    fi

    if [ -n "${POSTGRES_PASSWORD:-}" ]; then
        pwfile="$(mktemp)"
        printf '%s' "$POSTGRES_PASSWORD" > "$pwfile"
        "$PGBIN/initdb" -D "$PGDATA" --username="$POSTGRES_USER" \
            --pwfile="$pwfile" --auth-host=scram-sha-256 --auth-local=trust
        rm -f "$pwfile"
    else
        "$PGBIN/initdb" -D "$PGDATA" --username="$POSTGRES_USER" \
            --auth-host=trust --auth-local=trust
    fi

    echo "listen_addresses = '*'" >> "$PGDATA/postgresql.conf"
    echo "host all all all $AUTH" >> "$PGDATA/pg_hba.conf"

    # Local-only server (unix socket in /tmp) for DB creation + init scripts.
    "$PGBIN/pg_ctl" -D "$PGDATA" -w -t 60 \
        -o "-c listen_addresses='' -c unix_socket_directories=/tmp" start

    if [ "$POSTGRES_DB" != "postgres" ]; then
        "$PGBIN/psql" -v ON_ERROR_STOP=1 -h /tmp -U "$POSTGRES_USER" -d postgres \
            -c "CREATE DATABASE \"$POSTGRES_DB\";"
    fi

    for f in /docker-entrypoint-initdb.d/*; do
        [ -e "$f" ] || continue
        # operator-supplied init scripts, sourced path is dynamic by design
        # shellcheck disable=SC1090
        case "$f" in
            *.sh)  echo "entrypoint: running $f"; . "$f" ;;
            *.sql) echo "entrypoint: running $f"; "$PGBIN/psql" -v ON_ERROR_STOP=1 -h /tmp -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$f" ;;
        esac
    done

    "$PGBIN/pg_ctl" -D "$PGDATA" -m fast -w stop
    unset POSTGRES_PASSWORD
    echo "entrypoint: init complete"
fi

exec "$PGBIN/postgres" -D "$PGDATA"
