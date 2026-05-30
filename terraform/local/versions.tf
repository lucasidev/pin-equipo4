terraform {
  required_version = ">= 1.6"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# host = null lets the provider auto-detect the engine via the DOCKER_HOST
# env var or the platform default socket. Override with var.docker_host for
# podman or a non-default Docker Desktop pipe (see terraform.tfvars.example).
provider "docker" {
  host = var.docker_host
}
