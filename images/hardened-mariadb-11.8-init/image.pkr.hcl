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
  default = "11.8-init"
}

variable "registry" {
  type    = string
  default = "ghcr.io/iron-vigil/forge"
}

source "docker" "hardened_mariadb_11_init" {
  image  = "alpine:${var.alpine_version}"
  commit = true

  # No USER — the init entrypoint starts as root, initializes the data dir, then
  # drops to mysql via su-exec before exec'ing the server.
  changes = [
    "LABEL org.opencontainers.image.source=https://github.com/Iron-Vigil/forge",
    "LABEL org.opencontainers.image.vendor=IronVigil",
    "LABEL org.opencontainers.image.title=hardened-mariadb",
    "LABEL org.opencontainers.image.version=${var.image_version}",
    "EXPOSE 3306",
    "ENTRYPOINT [\"/usr/local/bin/docker-entrypoint.sh\"]"
  ]
}

build {
  sources = ["source.docker.hardened_mariadb_11_init"]

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

  # Stage the server config + init entrypoint before install
  provisioner "file" {
    source      = "${path.root}/../../components/mariadb-11-init/my.cnf"
    destination = "/tmp/if_mariadb.cnf"
  }

  provisioner "file" {
    source      = "${path.root}/../../components/mariadb-11-init/docker-entrypoint.sh"
    destination = "/tmp/if_entrypoint.sh"
  }

  provisioner "shell" {
    script = "${path.root}/../../components/mariadb-11-init/install.sh"
  }

  provisioner "shell" {
    script = "${path.root}/../../base/hardening/06-strip.sh"
  }

  post-processor "docker-tag" {
    repository = "${var.registry}/hardened-mariadb"
    tags       = [var.image_version]
  }
}
