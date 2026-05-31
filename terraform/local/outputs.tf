output "api_url" {
  description = "Backend API (pokedex-api)."
  value       = "http://localhost:${var.api_host_port}/api"
}

output "api_metrics_url" {
  description = "Prometheus metrics exposed by the api."
  value       = "http://localhost:${var.api_host_port}/metrics"
}

output "prometheus_url" {
  description = "Prometheus UI."
  value       = "http://localhost:${var.prometheus_host_port}"
}

output "grafana_url" {
  description = "Grafana UI (dashboard: Pokedex API)."
  value       = "http://localhost:${var.grafana_host_port}"
}

output "containers" {
  description = "Names of the created containers."
  value = [
    docker_container.mongo.name,
    docker_container.redis.name,
    docker_container.api.name,
    docker_container.prometheus.name,
    docker_container.grafana.name,
  ]
}
