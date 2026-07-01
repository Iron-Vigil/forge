packer {
  required_plugins {
    docker = {
      source  = "github.com/hashicorp/docker"
      version = ">= 1.0.9"
    }
  }
}

# Back-version: pinned to Alpine 3.22 (packages valkey 8.1).
# build.yml passes -var alpine_version from meta.yml, overriding this default.
variable "alpine_version" {
  type    = string
  default = "3.22"
}

variable "image_version" {
  type    = string
  default = "8"
}

variable "registry" {
  type    = string
  default = "ghcr.io/iron-vigil/forge"
}

source "docker" "hardened_valkey_8" {
  image  = "alpine:${var.alpine_version}"
  commit = true

  changes = [
    "LABEL org.opencontainers.image.source=https://github.com/Iron-Vigil/forge",
    "LABEL org.opencontainers.image.vendor=IronVigil",
    "LABEL org.opencontainers.image.title=hardened-valkey",
    "LABEL org.opencontainers.image.version=${var.image_version}",
    "EXPOSE 6379",
    "USER valkey",
    "ENTRYPOINT [\"/usr/bin/valkey-server\", \"/etc/valkey/valkey.conf\"]"
  ]
}

build {
  sources = ["source.docker.hardened_valkey_8"]

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

  # Stage valkey config before install
  provisioner "file" {
    source      = "${path.root}/../../components/valkey-8/valkey.conf"
    destination = "/tmp/if_valkey.conf"
  }

  provisioner "shell" {
    script = "${path.root}/../../components/valkey-8/install.sh"
  }

  provisioner "shell" {
    script = "${path.root}/../../base/hardening/06-strip.sh"
  }

  post-processor "docker-tag" {
    repository = "${var.registry}/hardened-valkey"
    tags       = [var.image_version]
  }
}
