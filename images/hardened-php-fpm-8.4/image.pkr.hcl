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
  default = "8.4"
}

variable "registry" {
  type    = string
  default = "ghcr.io/iron-vigil/forge"
}

source "docker" "hardened_php_fpm_84" {
  image  = "alpine:${var.alpine_version}"
  commit = true

  changes = [
    "LABEL org.opencontainers.image.source=https://github.com/Iron-Vigil/forge",
    "LABEL org.opencontainers.image.vendor=IronVigil",
    "LABEL org.opencontainers.image.title=hardened-php-fpm",
    "LABEL org.opencontainers.image.version=${var.image_version}",
    "EXPOSE 9000",
    "USER app",
    "ENTRYPOINT [\"/usr/sbin/php-fpm84\", \"-F\"]"
  ]
}

build {
  sources = ["source.docker.hardened_php_fpm_84"]

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

  # Stage the fpm pool config before install
  provisioner "file" {
    source      = "${path.root}/../../components/php-fpm-8.4/www.conf"
    destination = "/tmp/if_php_www.conf"
  }

  # PHP-FPM 8.4 component
  provisioner "shell" {
    script = "${path.root}/../../components/php-fpm-8.4/install.sh"
  }

  # Final strip
  provisioner "shell" {
    script = "${path.root}/../../base/hardening/06-strip.sh"
  }

  post-processor "docker-tag" {
    repository = "${var.registry}/hardened-php-fpm"
    tags       = [var.image_version]
  }
}
