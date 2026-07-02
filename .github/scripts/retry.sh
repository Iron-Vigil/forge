#!/bin/sh
# Retry a command through transient CI network flakes — the Grype vuln-DB CDN and
# Sigstore signing both like to throw a one-off 502 / INTERNAL_ERROR that drops a
# whole build->scan->release cycle. Bounded on purpose: this is for infra hiccups,
# not real failures, so once the attempts are spent it exits with the command's
# own status and a genuine error still fails the build. Backoff doubles each round.
#
#   Usage: retry.sh <cmd> [args...]
#   Tunables (env): RETRY_ATTEMPTS (default 4), RETRY_DELAY seconds (default 5)
#
# No `set -e` — this wrapper manages exit codes by hand and set -e would fight it.
set -u

attempts=${RETRY_ATTEMPTS:-4}
delay=${RETRY_DELAY:-5}
n=1

while true; do
    "$@"
    rc=$?
    [ "$rc" -eq 0 ] && exit 0
    if [ "$n" -ge "$attempts" ]; then
        echo "retry: '$*' failed after ${attempts} attempt(s); last exit ${rc}" >&2
        exit "$rc"
    fi
    echo "retry: attempt ${n}/${attempts} of '$*' failed (exit ${rc}); retrying in ${delay}s" >&2
    sleep "$delay"
    n=$((n + 1))
    delay=$((delay * 2))
done
