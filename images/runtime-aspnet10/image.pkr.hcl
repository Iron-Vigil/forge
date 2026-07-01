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

source "docker" "runtime_aspnet10" {
  image  = "alpine:${var.alpine_version}"
  commit = true

  changes = [
    "LABEL org.opencontainers.image.source=https://github.com/Iron-Vigil/forge",
    "LABEL org.opencontainers.image.vendor=IronVigil",
    "LABEL org.opencontainers.image.title=runtime-aspnet10",
    "LABEL org.opencontainers.image.version=${var.image_version}",
    "EXPOSE 8080",
    "USER app",
    "ENTRYPOINT [\"/usr/lib/dotnet/dotnet\"]"
  ]
}

build {
  sources = ["source.docker.runtime_aspnet10"]

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

  # ASP.NET Core 10 runtime component
  provisioner "shell" {
    script = "${path.root}/../../components/aspnet-runtime10/install.sh"
  }

  # Final strip
  provisioner "shell" {
    script = "${path.root}/../../base/hardening/06-strip.sh"
  }

  post-processor "docker-tag" {
    repository = "${var.registry}/runtime-aspnet10"
    tags       = [var.image_version, "latest"]
  }
}
