# The six long-running services. depends_on in the docker provider waits
# for container creation, not health, so the app containers also use
# restart = "unless-stopped" to recover if they start before their
# dependencies accept connections. Healthchecks mirror the compose file.

resource "docker_container" "mongo" {
  name    = "${var.network_name}-mongo"
  image   = docker_image.mongo.image_id
  restart = "unless-stopped"

  env = [
    "MONGO_INITDB_ROOT_USERNAME=${var.mongo_root_user}",
    "MONGO_INITDB_ROOT_PASSWORD=${var.mongo_root_password}",
    "MONGO_INITDB_DATABASE=pokedex",
  ]

  volumes {
    volume_name    = docker_volume.mongo_data.name
    container_path = "/data/db"
  }

  networks_advanced {
    name    = docker_network.pin.name
    aliases = ["mongo"]
  }

  healthcheck {
    test         = ["CMD", "mongosh", "--quiet", "--eval", "db.adminCommand('ping')"]
    interval     = "10s"
    timeout      = "5s"
    retries      = 5
    start_period = "15s"
  }
}

resource "docker_container" "redis" {
  name    = "${var.network_name}-redis"
  image   = docker_image.redis.image_id
  restart = "unless-stopped"

  command = ["redis-server", "--requirepass", var.redis_password, "--maxmemory", "128mb", "--maxmemory-policy", "allkeys-lru"]

  volumes {
    volume_name    = docker_volume.redis_data.name
    container_path = "/data"
  }

  networks_advanced {
    name    = docker_network.pin.name
    aliases = ["redis"]
  }

  healthcheck {
    test         = ["CMD", "redis-cli", "-a", var.redis_password, "--no-auth-warning", "ping"]
    interval     = "10s"
    timeout      = "5s"
    retries      = 5
    start_period = "15s"
  }
}

resource "docker_container" "api" {
  name    = "${var.network_name}-api"
  image   = docker_image.api.image_id
  restart = "unless-stopped"

  env = [
    "NODE_ENV=production",
    "PORT=3000",
    "LOG_LEVEL=info",
    "MONGODB_URI=mongodb://${var.mongo_root_user}:${var.mongo_root_password}@mongo:27017/pokedex?authSource=admin",
    "REDIS_URL=redis://:${var.redis_password}@redis:6379",
    "JWT_SECRET=${var.jwt_secret}",
    "JWT_EXPIRES_IN=1h",
    "ADMIN_NAME=${var.admin_name}",
    "ADMIN_EMAIL=${var.admin_email}",
    "ADMIN_USERNAME=${var.admin_username}",
    "ADMIN_PASSWORD=${var.admin_password}",
    "POKEAPI_BASE_URL=https://pokeapi.co/api/v2",
    "POKEAPI_CACHE_TTL_SECONDS=3600",
    "RATE_LIMIT_WINDOW_MS=60000",
    "RATE_LIMIT_MAX=${var.rate_limit_max}",
    "CORS_ORIGIN=http://localhost:${var.api_host_port}",
  ]

  ports {
    internal = 3000
    external = var.api_host_port
  }

  networks_advanced {
    name    = docker_network.pin.name
    aliases = ["api"]
  }

  healthcheck {
    test         = ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:3000/health"]
    interval     = "10s"
    timeout      = "5s"
    retries      = 5
    start_period = "15s"
  }

  depends_on = [docker_container.mongo, docker_container.redis]
}

resource "docker_container" "prometheus" {
  name    = "${var.network_name}-prometheus"
  image   = docker_image.prometheus.image_id
  restart = "unless-stopped"

  upload {
    content = file("${path.module}/../../observability/prometheus/prometheus.yml")
    file    = "/etc/prometheus/prometheus.yml"
  }

  volumes {
    volume_name    = docker_volume.prometheus_data.name
    container_path = "/prometheus"
  }

  ports {
    internal = 9090
    external = var.prometheus_host_port
  }

  networks_advanced {
    name    = docker_network.pin.name
    aliases = ["prometheus"]
  }

  depends_on = [docker_container.api]
}

resource "docker_container" "grafana" {
  name    = "${var.network_name}-grafana"
  image   = docker_image.grafana.image_id
  restart = "unless-stopped"

  env = [
    "GF_SECURITY_ADMIN_USER=${var.grafana_admin_user}",
    "GF_SECURITY_ADMIN_PASSWORD=${var.grafana_admin_password}",
    "GF_USERS_ALLOW_SIGN_UP=false",
  ]

  upload {
    content = file("${path.module}/../../observability/grafana/provisioning/datasources/datasource.yml")
    file    = "/etc/grafana/provisioning/datasources/datasource.yml"
  }

  upload {
    content = file("${path.module}/../../observability/grafana/provisioning/dashboards/dashboards.yml")
    file    = "/etc/grafana/provisioning/dashboards/dashboards.yml"
  }

  upload {
    content = file("${path.module}/../../observability/grafana/dashboards/pokedex-api.json")
    file    = "/var/lib/grafana/dashboards/pokedex-api.json"
  }

  volumes {
    volume_name    = docker_volume.grafana_data.name
    container_path = "/var/lib/grafana"
  }

  ports {
    internal = 3000
    external = var.grafana_host_port
  }

  networks_advanced {
    name    = docker_network.pin.name
    aliases = ["grafana"]
  }

  depends_on = [docker_container.prometheus]
}
