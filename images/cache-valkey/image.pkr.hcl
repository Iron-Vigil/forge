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
  default = "0.1.0"
}

variable "registry" {
  type    = string
  default = "ghcr.io/iron-vigil/forge"
}

source "docker" "cache_valkey" {
  image  = "alpine:${var.alpine_version}"
  commit = true

  changes = [
    "LABEL org.opencontainers.image.source=https://github.com/Iron-Vigil/forge",
    "LABEL org.opencontainers.image.vendor=IronVigil",
    "LABEL org.opencontainers.image.title=cache-valkey",
    "LABEL org.opencontainers.image.version=${var.image_version}",
    "EXPOSE 6379",
    "USER valkey",
    "ENTRYPOINT [\"/usr/bin/valkey-server\", \"/etc/valkey/valkey.conf\"]"
  ]
}

build {
  sources = ["source.docker.cache_valkey"]

  # Stage shared lib — must be first
  provisioner "file" {
    source      = "${path.root}/../../components/_lib/"
    destination = "/tmp/forge-lib/"
  }

  # Base hardening
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
    source      = "${path.root}/../../components/valkey/valkey.conf"
    destination = "/tmp/if_valkey.conf"
  }

  # Valkey component
  provisioner "shell" {
    script = "${path.root}/../../components/valkey/install.sh"
  }

  # Final strip
  provisioner "shell" {
    script = "${path.root}/../../base/hardening/06-strip.sh"
  }

  post-processor "docker-tag" {
    repository = "${var.registry}/cache-valkey"
    tags       = [var.image_version, "latest"]
  }
}
