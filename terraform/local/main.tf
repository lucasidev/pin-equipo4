# Network, volumes and images. Containers live in containers.tf.

resource "docker_network" "pin" {
  name = var.network_name
}

resource "docker_volume" "mongo_data" {
  name = "${var.network_name}_mongo_data"
}

resource "docker_volume" "redis_data" {
  name = "${var.network_name}_redis_data"
}

resource "docker_volume" "prometheus_data" {
  name = "${var.network_name}_prometheus_data"
}

resource "docker_volume" "grafana_data" {
  name = "${var.network_name}_grafana_data"
}

# ─── Images ────────────────────────────────────────────────────────
# keep_locally = true avoids re-pulling on every apply. The GHCR app
# images must be public, or the daemon authenticated (docker login ghcr.io).

resource "docker_image" "mongo" {
  name         = var.mongo_image
  keep_locally = true
}

resource "docker_image" "redis" {
  name         = var.redis_image
  keep_locally = true
}

resource "docker_image" "api" {
  name         = var.api_image
  keep_locally = true
}

resource "docker_image" "web" {
  name         = var.web_image
  keep_locally = true
}

resource "docker_image" "prometheus" {
  name         = var.prometheus_image
  keep_locally = true
}

resource "docker_image" "grafana" {
  name         = var.grafana_image
  keep_locally = true
}
