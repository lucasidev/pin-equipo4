variable "docker_host" {
  description = "Docker/Podman daemon host. Leave null to auto-detect. Windows Docker Desktop: npipe:////./pipe/docker_engine. Windows podman: npipe:////./pipe/podman-machine-default. Linux podman: unix:///run/user/1000/podman/podman.sock."
  type        = string
  default     = null
}

variable "network_name" {
  description = "Name of the bridge network and the prefix for container/volume names."
  type        = string
  default     = "pin-equipo4"
}

# ─── Images ────────────────────────────────────────────────────────
# App images come from GHCR (published by each repo CI). Data and
# observability images are pinned upstream tags.

variable "api_image" {
  description = "pokedex-api image reference."
  type        = string
  default     = "ghcr.io/lucasidev/pokedex-api:latest"
}

variable "web_image" {
  description = "pokedex-web image reference."
  type        = string
  default     = "ghcr.io/lucasidev/pokedex-web:latest"
}

variable "mongo_image" {
  description = "MongoDB image."
  type        = string
  default     = "mongo:7"
}

variable "redis_image" {
  description = "Redis image."
  type        = string
  default     = "redis:7-alpine"
}

variable "prometheus_image" {
  description = "Prometheus image."
  type        = string
  default     = "prom/prometheus:v3.1.0"
}

variable "grafana_image" {
  description = "Grafana image."
  type        = string
  default     = "grafana/grafana:11.5.1"
}

# ─── Secrets ───────────────────────────────────────────────────────
# Provided via terraform.tfvars (gitignored). See terraform.tfvars.example.

variable "mongo_root_user" {
  description = "MongoDB root username."
  type        = string
  default     = "pokedex"
}

variable "mongo_root_password" {
  description = "MongoDB root password."
  type        = string
  sensitive   = true
}

variable "redis_password" {
  description = "Redis AUTH password."
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT signing secret (the api requires at least 32 characters)."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.jwt_secret) >= 32
    error_message = "jwt_secret must be at least 32 characters (enforced by the api at boot)."
  }
}

variable "admin_name" {
  description = "Seed admin display name."
  type        = string
  default     = "admin"
}

variable "admin_email" {
  description = "Seed admin email."
  type        = string
  default     = "admin@pokedex.local"
}

variable "admin_username" {
  description = "Seed admin username."
  type        = string
  default     = "pokeadmin"
}

variable "admin_password" {
  description = "Seed admin password (the api requires at least 8 characters)."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.admin_password) >= 8
    error_message = "admin_password must be at least 8 characters (enforced by the api at boot)."
  }
}

variable "grafana_admin_user" {
  description = "Grafana admin username."
  type        = string
  default     = "admin"
}

variable "grafana_admin_password" {
  description = "Grafana admin password."
  type        = string
  sensitive   = true
}

# ─── Host ports ────────────────────────────────────────────────────

variable "api_host_port" {
  description = "Host port mapped to the api container."
  type        = number
  default     = 3000
}

variable "web_host_port" {
  description = "Host port mapped to the web container."
  type        = number
  default     = 8080
}

variable "prometheus_host_port" {
  description = "Host port mapped to Prometheus."
  type        = number
  default     = 9090
}

variable "grafana_host_port" {
  description = "Host port mapped to Grafana."
  type        = number
  default     = 3001
}
