# Forge — Hardened Image Factory

Public repository of hardened Docker images for the Iron Vigil platform. Images are built with [Packer](https://www.packer.io/), scanned with [Grype](https://github.com/anchore/grype), signed with [Cosign](https://github.com/sigstore/cosign) keyless signing, and published to GHCR.

**Registry:** `ghcr.io/iron-vigil/forge/<image>:<version>`

---

## Available Images

Images are tagged by the software version, like the official language images (`hardened-python:3.14`). The `:latest` tag tracks the newest version of each.

| Image | Tags | Description | Ports |
|---|---|---|---|
| `hardened-nginx` | `1.30` | Hardened nginx web server on Alpine | 80, 443 |
| `hardened-valkey` | `9` | Hardened Valkey cache on Alpine | 6379 |
| `hardened-dotnet` | `8`, `10` | Hardened .NET runtime on Alpine (base image) | — |
| `hardened-aspnet` | `8`, `10` | Hardened ASP.NET Core runtime on Alpine (base image) | 8080 |

---

## Pipeline

Every image goes through four stages automatically:

```
PR opened  →  Validate  (ShellCheck, packer validate, yamllint, component ref check)
Merge/dispatch  →  Build  (Packer + Alpine, push to GHCR)
                →  Scan   (Syft SBOM, Grype CVE scan, Cosign sign)
                →  Release (GitHub Release with SBOM + CVE report attached)
```

**CRITICAL CVEs block release.** HIGH CVEs produce a warning annotation but do not block. The Grype SARIF report is uploaded to the GitHub Security tab on every scan run.

Monthly rebuilds run the first Monday of each month at 02:00 UTC. They only fire if Grype finds CRITICAL advisories in the current published image.

---

## Pulling Images

```sh
# nginx
docker pull ghcr.io/iron-vigil/forge/hardened-nginx:1.30

# Valkey cache
docker pull ghcr.io/iron-vigil/forge/hardened-valkey:9

# .NET runtime base images (use as a FROM base for your published app)
docker pull ghcr.io/iron-vigil/forge/hardened-aspnet:10
```

The `hardened-dotnet` / `hardened-aspnet` images are distroless .NET base images
— no shell, non-root (uid 1654), `dotnet` on the entrypoint. Layer your app on top:

```dockerfile
FROM ghcr.io/iron-vigil/forge/hardened-aspnet:10
COPY --chown=1654:1654 ./publish/ /app/
ENTRYPOINT ["/usr/lib/dotnet/dotnet", "/app/MyApp.dll"]
```

Globalization (ICU) is included; ASP.NET Core listens on `8080` as uid 1654.

Verify the Cosign signature (same command for all images, swap the image ref):

```sh
cosign verify ghcr.io/iron-vigil/forge/hardened-valkey:9 \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp "https://github.com/Iron-Vigil/forge/.github/workflows/scan.yml"
```

Running the Valkey cache:

```sh
docker run -d --name valkey \
  --read-only \
  --network my-net \
  -p 6379:6379 \
  ghcr.io/iron-vigil/forge/hardened-valkey:9 \
  valkey-server /etc/valkey/valkey.conf --requirepass yourpassword --maxmemory 256mb
```

---

## Repository Layout

```
base/
  alpine.pkrvars.hcl        # single Alpine version pin — all images share this
  hardening/
    01-packages.sh          # remove unnecessary Alpine base packages
    02-users.sh             # lock/remove unnecessary system accounts
    03-suid.sh              # strip SUID/SGID bits
    04-network.sh           # sysctl hardening (IPv4 only, no forwarding)
    05-permissions.sh       # filesystem permission hardening
    06-strip.sh             # final strip: remove apk, compilers, network tools

components/
  _lib/
    common.sh               # log(), die(), warn(), verify_checksum(), etc.
    apk.sh                  # apk_install(), apk_del(), apk_selfremove()
  nginx/
    install.sh
    nginx.conf
    conf.d/default.conf
  openssh/
    install.sh
    sshd_config
  valkey/
    install.sh
    valkey.conf
  dotnet-runtime8/          # .NET runtime components — one apk pin each
    install.sh
  dotnet-runtime10/
    install.sh
  aspnet-runtime8/
    install.sh
  aspnet-runtime10/
    install.sh

images/                     # dir = hardened-<sw>-<ver>; published name/tag come from meta.yml
  hardened-nginx-1.30/
    image.pkr.hcl           # Packer template
    meta.yml                # name (repo), tag (sw version), latest, components, ports, entrypoint
    Dockerfile.strip        # post-Packer distroless strip (FROM scratch)
  hardened-valkey-9/
    ...
  hardened-dotnet-8/        # -> hardened-dotnet:8
  hardened-dotnet-10/       # -> hardened-dotnet:10   (latest)
  hardened-aspnet-8/        # -> hardened-aspnet:8
  hardened-aspnet-10/       # -> hardened-aspnet:10   (latest)

security/
  grype.yaml                # Grype scan config

.github/
  workflows/
    validate.yml            # runs on every PR
    build.yml               # builds and pushes to GHCR
    scan.yml                # Syft + Grype + Cosign
    release.yml             # creates GitHub Release with reports
    rebuild.yml             # monthly scheduled rebuild
    triage.yml              # issue triage
  renovate.json             # Renovate config for version tracking
  CODEOWNERS
```

---

## Hardening Passes

All six passes run on every image before any component installs (except the strip, which runs last):

| Pass | What it does |
|---|---|
| 01-packages | Removes Alpine packages with no container runtime role (openrc, kbd, mdadm, etc.) |
| 02-users | Locks/removes unnecessary system accounts; locks root |
| 03-suid | Strips SUID/SGID bits from all binaries except a small allowlist |
| 04-network | Sets sysctl hardening: no IP forwarding, no source routing, no ICMP redirects |
| 05-permissions | Tightens permissions on sensitive paths |
| 06-strip | Removes apk-tools, compilers, network tools (wget, curl, nc, telnet, ftp, env) |

Shell (`/bin/sh`, `/bin/busybox`) is intentionally left in place — true distroless via multi-stage `docker build` is planned as follow-on work.

---

## Components

Each component lives in `components/<name>/` with a single `install.sh` that sources the shared lib from `/tmp/forge-lib/`. The lib is staged into the container by a Packer `file` provisioner before any shell provisioner runs.

APK packages are pinned to exact versions (`nginx=1.26.3-r0`). Renovate tracks these pins and opens PRs when new versions land in Alpine.

To add a new component:

1. Create `components/<name>/install.sh` — source `. /tmp/forge-lib/common.sh` and `. /tmp/forge-lib/apk.sh`, call `require_root`, use `apk_install` with an exact version pin.
2. Add any config files alongside `install.sh`.
3. Reference the component in a `meta.yml` under `components:`.
4. Add `file` provisioner(s) to the image's `image.pkr.hcl` to stage configs before `install.sh` runs.

---

## Adding a New Image

1. Create `images/hardened-<sw>-<ver>/image.pkr.hcl` — follow `hardened-nginx-1.30` as the template. Stage the `_lib` file provisioner first, run hardening passes, then component installs, then `06-strip.sh` last.
2. Create `images/<name>/meta.yml` with `name` (published repo), `tag` (software version), `latest`, `components`, `expose`, `run_as`, `entrypoint`.
3. Open a PR — validate runs automatically.
4. After merge, trigger `Build Images` from Actions with `image=<name>`.

---

## Version Pinning

- **Alpine base:** `base/alpine.pkrvars.hcl` — one line, shared by all images.
- **APK packages:** exact pins in each `install.sh` (e.g. `nginx=1.26.3-r0`).
- **Packer plugin:** `>= 1.0.9` in each `image.pkr.hcl`.

Renovate manages all three with custom regex managers and opens PRs automatically.

To find the current exact pin for an APK package:

```sh
docker run --rm alpine:3.21 sh -c "apk update -q && apk search --exact <package>"
```

---

## Security

- Grype config: `security/grype.yaml` — scans all layers, external sources disabled.
- CVE gate: CRITICAL = release blocked; HIGH = warning annotation only.
- SARIF results uploaded to the repo Security tab on every scan.
- SBOM attached to the GHCR image manifest via `cosign attach sbom`.
- Cosign keyless signing — signature is tied to the GitHub Actions OIDC identity, no private key stored anywhere.
- Known false positives or unmitigated CVEs go in the `ignore:` block in `security/grype.yaml` with a justification comment and an expiry date.

---

## Requesting Images or Components

Use GitHub Issues:

- **New image:** [Image Request](.github/ISSUE_TEMPLATE/image-request.yml)
- **New component:** [Component Request](.github/ISSUE_TEMPLATE/component-request.yml)
