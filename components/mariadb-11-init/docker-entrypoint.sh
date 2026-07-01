#!/bin/sh
# First-run init entrypoint for hardened-mariadb:11.8-init.
# Adapted from the official mariadb docker-entrypoint. Initializes an empty data
# dir once (root password, optional db/user, /docker-entrypoint-initdb.d/*.sql),
# then execs the server. Fails closed if no root password intent is given.
set -eu

DATADIR=/var/lib/mysql
SOCKET=/tmp/mysqld-init.sock

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

# escape single quotes for a SQL string literal
sql_str() { printf '%s' "$1" | sed "s/'/''/g"; }

# Started as root: own the data dir, drop to mysql, re-exec.
if [ "$(id -u)" = "0" ]; then
    mkdir -p "$DATADIR"
    chown mysql:mysql "$DATADIR"
    exec su-exec mysql "$0" "$@"
fi

file_env MARIADB_ROOT_PASSWORD
file_env MARIADB_PASSWORD
file_env MARIADB_DATABASE
file_env MARIADB_USER

# First run only — an initialized data dir has the mysql system database.
if [ ! -d "$DATADIR/mysql" ]; then
    if [ -z "${MARIADB_ROOT_PASSWORD:-}" ] \
       && [ "${MARIADB_ALLOW_EMPTY_ROOT_PASSWORD:-}" != "1" ] \
       && [ "${MARIADB_RANDOM_ROOT_PASSWORD:-}" != "1" ]; then
        echo "entrypoint: refusing to initialize without a root password." >&2
        echo "  set MARIADB_ROOT_PASSWORD (or _FILE), MARIADB_RANDOM_ROOT_PASSWORD=1, or" >&2
        echo "  MARIADB_ALLOW_EMPTY_ROOT_PASSWORD=1 to explicitly allow an empty root password." >&2
        exit 1
    fi

    /usr/bin/mariadb-install-db --user=mysql --datadir="$DATADIR" \
        --auth-root-authentication-method=normal --skip-test-db > /dev/null

    ROOTPW="${MARIADB_ROOT_PASSWORD:-}"
    if [ "${MARIADB_RANDOM_ROOT_PASSWORD:-}" = "1" ]; then
        ROOTPW="$(head -c 18 /dev/urandom | od -An -tx1 | tr -d ' \n')"
        echo "entrypoint: generated random root password: $ROOTPW"
    fi

    # Temp local-only server (socket only) for setup + init scripts.
    /usr/bin/mariadbd --user=mysql --datadir="$DATADIR" --skip-networking \
        --socket="$SOCKET" &
    initpid=$!

    ready=""
    for _ in $(seq 1 30); do
        if [ -S "$SOCKET" ] && /usr/bin/mariadb --socket="$SOCKET" -u root -e "SELECT 1" > /dev/null 2>&1; then
            ready=1; break
        fi
        sleep 1
    done
    [ -n "$ready" ] || { echo "entrypoint: temp server never came up" >&2; kill "$initpid" 2>/dev/null || true; exit 1; }

    # This connection authenticates while root still has no password (install-db
    # left it empty), so it needs no -p. It sets the password for every future
    # connection. NO_BACKSLASH_ESCAPES so sql_str's quote-doubling is the only
    # escaping the server applies to the password literal.
    {
        echo "SET @@SESSION.SQL_LOG_BIN=0;"
        echo "SET @@SESSION.sql_mode='NO_BACKSLASH_ESCAPES';"
        echo "DELETE FROM mysql.global_priv WHERE User='' OR (User='root' AND Host NOT IN ('localhost'));"
        echo "DROP DATABASE IF EXISTS test;"
        echo "ALTER USER 'root'@'localhost' IDENTIFIED BY '$(sql_str "$ROOTPW")';"
        echo "CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '$(sql_str "$ROOTPW")';"
        echo "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;"
        [ -n "${MARIADB_DATABASE:-}" ] && echo "CREATE DATABASE IF NOT EXISTS \`${MARIADB_DATABASE}\`;"
        if [ -n "${MARIADB_USER:-}" ] && [ -n "${MARIADB_PASSWORD:-}" ]; then
            echo "CREATE USER '${MARIADB_USER}'@'%' IDENTIFIED BY '$(sql_str "$MARIADB_PASSWORD")';"
            [ -n "${MARIADB_DATABASE:-}" ] && echo "GRANT ALL ON \`${MARIADB_DATABASE}\`.* TO '${MARIADB_USER}'@'%';"
        fi
        echo "FLUSH PRIVILEGES;"
    } | /usr/bin/mariadb --socket="$SOCKET" -u root

    # root now needs the password. Every reconnect below (init scripts, shutdown)
    # picks it up via MYSQL_PWD — an empty value is a valid empty-password login,
    # which -p"" can't express without hanging on a prompt.
    export MYSQL_PWD="$ROOTPW"

    for f in /docker-entrypoint-initdb.d/*; do
        [ -e "$f" ] || continue
        # operator-supplied init scripts, sourced path is dynamic by design
        # shellcheck disable=SC1090
        case "$f" in
            *.sh)  echo "entrypoint: running $f"; . "$f" ;;
            *.sql) echo "entrypoint: running $f"; /usr/bin/mariadb --socket="$SOCKET" -u root ${MARIADB_DATABASE:+"$MARIADB_DATABASE"} < "$f" ;;
        esac
    done

    /usr/bin/mariadb-admin --socket="$SOCKET" -u root shutdown
    wait "$initpid" 2>/dev/null || true
    unset MYSQL_PWD MARIADB_ROOT_PASSWORD MARIADB_PASSWORD
    echo "entrypoint: init complete"
fi

exec /usr/bin/mariadbd --user=mysql --datadir="$DATADIR"
