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
  default = "3.21"
}

variable "image_version" {
  type    = string
  default = "0.1.0"
}

variable "registry" {
  type    = string
  default = "ghcr.io/iron-vigil/forge"
}

source "docker" "web_nginx" {
  image  = "alpine:${var.alpine_version}"
  commit = true

  changes = [
    "LABEL org.opencontainers.image.source=https://github.com/Iron-Vigil/forge",
    "LABEL org.opencontainers.image.vendor=IronVigil",
    "LABEL org.opencontainers.image.title=web-nginx",
    "LABEL org.opencontainers.image.version=${var.image_version}",
    "EXPOSE 80 443",
    "USER nginx",
    "ENTRYPOINT [\"/usr/sbin/nginx\", \"-g\", \"daemon off;\"]"
  ]
}

build {
  sources = ["source.docker.web_nginx"]

  # Base hardening — runs before any component
  provisioner "shell" {
    scripts = [
      "../../base/hardening/01-packages.sh",
      "../../base/hardening/02-users.sh",
      "../../base/hardening/03-suid.sh",
      "../../base/hardening/04-network.sh",
      "../../base/hardening/05-permissions.sh",
    ]
  }

  # Stage nginx configs before the install script runs
  # Packer uploads shell scripts to a temp path — configs must be staged separately
  provisioner "file" {
    source      = "../../components/nginx/nginx.conf"
    destination = "/tmp/if_nginx.conf"
  }

  provisioner "file" {
    source      = "../../components/nginx/conf.d/default.conf"
    destination = "/tmp/if_nginx_default.conf"
  }

  # nginx component
  provisioner "shell" {
    script = "../../components/nginx/install.sh"
  }

  # Final strip — no shell or apk after this
  provisioner "shell" {
    script = "../../base/hardening/06-strip.sh"
  }

  # Tag for GHCR — push is handled by the Actions workflow, not here
  post-processor "docker-tag" {
    repository = "${var.registry}/web-nginx"
    tags       = [var.image_version, "latest"]
  }
}
