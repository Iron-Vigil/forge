packer {
  required_plugins {
    docker = {
      source  = "github.com/hashicorp/docker"
      version = ">= 1.0.9"
    }
  }
}

# Back-version: pinned to Alpine 3.23 (last stable branch shipping python 3.12).
# build.yml passes -var alpine_version from meta.yml, overriding this default.
variable "alpine_version" {
  type    = string
  default = "3.23"
}

variable "image_version" {
  type    = string
  default = "3.12"
}

variable "registry" {
  type    = string
  default = "ghcr.io/iron-vigil/forge"
}

source "docker" "hardened_python_3_12" {
  image  = "alpine:${var.alpine_version}"
  commit = true

  changes = [
    "LABEL org.opencontainers.image.source=https://github.com/Iron-Vigil/forge",
    "LABEL org.opencontainers.image.vendor=IronVigil",
    "LABEL org.opencontainers.image.title=hardened-python",
    "LABEL org.opencontainers.image.version=${var.image_version}",
    "USER app",
    "ENTRYPOINT [\"/usr/bin/python3\"]"
  ]
}

build {
  sources = ["source.docker.hardened_python_3_12"]

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

  provisioner "shell" {
    script = "${path.root}/../../components/python-3.12/install.sh"
  }

  provisioner "shell" {
    script = "${path.root}/../../base/hardening/06-strip.sh"
  }

  post-processor "docker-tag" {
    repository = "${var.registry}/hardened-python"
    tags       = [var.image_version]
  }
}
