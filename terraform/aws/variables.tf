variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix for all AWS resources."
  type        = string
  default     = "pokedex"
}

variable "instance_type" {
  description = "EC2 instance type. t3.micro is Free Tier eligible."
  type        = string
  default     = "t3.micro"
}

variable "ssh_public_key" {
  description = "Public SSH key contents to inject into the EC2 instance (e.g. file(\"~/.ssh/id_rsa.pub\"))."
  type        = string
}

variable "admin_cidr" {
  description = "CIDR allowed to reach SSH (22). Set to your IP/32; never leave 0.0.0.0/0 in production."
  type        = string
}

variable "api_image" {
  description = <<-EOT
    Container image for the api, published to GHCR by its CI. For a repeatable
    deploy, pass an immutable tag (e.g. ghcr.io/lucasidev/pokedex-api:sha-abc1234)
    via TF_VAR_api_image: changing it recreates the instance with the new image.
    The :latest default works for the first deploy but does not roll out new
    images on its own (it is not an immutable reference).
  EOT
  type        = string
  default     = "ghcr.io/lucasidev/pokedex-api:latest"
}

variable "mongo_root_user" {
  description = "MongoDB root username seeded on the instance."
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

variable "admin_email" {
  description = "Seed admin email."
  type        = string
  default     = "admin@pokedex.local"
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
