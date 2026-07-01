packer {
  required_plugins {
    docker = {
      source  = "github.com/hashicorp/docker"
      version = ">= 1.0.9"
    }
  }
}

variable "alpine_version" {
  type    = string
  default = "3.24"
}

variable "image_version" {
  type    = string
  default = "18-init"
}

variable "registry" {
  type    = string
  default = "ghcr.io/iron-vigil/forge"
}

source "docker" "hardened_postgres_18_init" {
  image  = "alpine:${var.alpine_version}"
  commit = true

  # No USER — the init entrypoint starts as root, initializes the data dir, then
  # drops to postgres via su-exec before exec'ing the server.
  changes = [
    "LABEL org.opencontainers.image.source=https://github.com/Iron-Vigil/forge",
    "LABEL org.opencontainers.image.vendor=IronVigil",
    "LABEL org.opencontainers.image.title=hardened-postgres",
    "LABEL org.opencontainers.image.version=${var.image_version}",
    "EXPOSE 5432",
    "ENTRYPOINT [\"/usr/local/bin/docker-entrypoint.sh\"]"
  ]
}

build {
  sources = ["source.docker.hardened_postgres_18_init"]

  provisioner "file" {
    source      = "${path.root}/../../components/_lib/"
    destination = "/tmp/forge-lib/"
  }

  provisioner "shell" {
    scripts = [
      "${path.root}/../../base/hardening/01-packages.sh",
      "${path.root}/../../base/hardening/02-users.sh",
      "${path.root}/../../base/hardening/03-suid.sh",
      "${path.root}/../../base/hardening/04-network.sh",
      "${path.root}/../../base/hardening/05-permissions.sh",
    ]
  }

  # Stage the init entrypoint before install
  provisioner "file" {
    source      = "${path.root}/../../components/postgres-18-init/docker-entrypoint.sh"
    destination = "/tmp/if_entrypoint.sh"
  }

  provisioner "shell" {
    script = "${path.root}/../../components/postgres-18-init/install.sh"
  }

  provisioner "shell" {
    script = "${path.root}/../../base/hardening/06-strip.sh"
  }

  post-processor "docker-tag" {
    repository = "${var.registry}/hardened-postgres"
    tags       = [var.image_version]
  }
}
