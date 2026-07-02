#!/bin/sh
# Detect or remove "phantom" apk packages. A phantom is a package whose
# executable files (anything under a bin/ or sbin/ dir) were all stripped out of
# the image, but whose record still sits in /lib/apk/db/installed. Syft builds
# the SBOM from that db, so a phantom keeps showing up and Grype flags CVEs for a
# binary the image no longer ships (that is how the busybox wget CVE-2025-60876
# stuck to every distroless image). Config/data files a package leaves behind are
# ignored on purpose; only stripped executables make a package a phantom.
#
# Usage:
#   phantom-apk.sh prune <db> <present-list> [also-gone]
#       Rewrite <db> in place, dropping phantom records. Logs each drop.
#   phantom-apk.sh check <db> <present-list>
#       Read-only. Exit 1 (and list them) if any phantom survives, else 0.
#
#   <present-list>  file of absolute paths that exist in the image, one per line.
#   <also-gone>     space-separated absolute paths to treat as already removed.
#                   Used during the strip, when busybox is deleted right after
#                   this runs, so its own record gets pruned in the same pass.
set -eu

mode=${1:?usage: phantom-apk.sh prune|check <db> <present-list> [also-gone]}
db=${2:?missing db path}
present=${3:?missing present-list path}
also=" ${4:-} "

scan() {
    awk -v also="$also" -v mode="$mode" -v presentfile="$present" '
        BEGIN {
            while ((getline p < presentfile) > 0) have[p] = 1
            close(presentfile)
            RS = ""
        }
        {
            n = split($0, L, "\n"); dir = ""; pkg = ""; nbin = 0; live = 0
            for (i = 1; i <= n; i++) {
                tag = substr(L[i], 1, 2); val = substr(L[i], 3)
                if (tag == "P:") pkg = val
                else if (tag == "F:") dir = val
                else if (tag == "R:") {
                    path = (dir == "" ? "/" val : "/" dir "/" val)
                    if (path ~ /(^|\/)s?bin\//) {
                        nbin++
                        if (index(also, " " path " ") == 0 && (path in have)) live++
                    }
                }
            }
            phantom = (nbin > 0 && live == 0)
            if (phantom) {
                printf("phantom-apk: %s %s (all bin/sbin files stripped)\n",
                       (mode == "prune" ? "pruned" : "FOUND"), pkg) > "/dev/stderr"
                found = 1
                if (mode == "prune") next
            }
            if (mode == "prune") printf "%s\n\n", $0
        }
        END { if (mode == "check" && found) exit 3 }
    ' "$db"
}

case "$mode" in
    prune)
        scan > "${db}.tmp"
        mv "${db}.tmp" "$db"
        ;;
    check)
        if scan > /dev/null; then
            echo "phantom-apk: no phantom packages" >&2
        else
            rc=$?
            if [ "$rc" = 3 ]; then
                echo "phantom-apk: phantom package(s) found above." >&2
                echo "  A stripped binary left its apk-db record behind; Syft/Grype will flag it." >&2
                echo "  Prune it in the image's Dockerfile.strip (the phantom-apk.sh prune step)." >&2
                exit 1
            fi
            exit "$rc"
        fi
        ;;
    *)
        echo "phantom-apk: unknown mode '$mode' (want prune|check)" >&2
        exit 2
        ;;
esac
