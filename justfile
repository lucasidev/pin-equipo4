set windows-shell := ["powershell.exe", "-NoLogo", "-NoProfile", "-Command"]

# Container engine: podman or docker. Override with CONTAINER_ENGINE.
engine := env("CONTAINER_ENGINE", "docker")
compose := engine + " compose -f compose/docker-compose.yml --env-file compose/.env"

default:
    @just --list

# ═══════════════════════════════════════════════════════════════
# Stack (docker compose)
# ═══════════════════════════════════════════════════════════════

# Pull images and start the full stack (api, web, mongo, redis,
# prometheus, grafana).
up:
    {{compose}} up -d

down:
    {{compose}} down

# Wipe volumes too (DESTRUCTIVE: loses mongo/redis/grafana data).
reset:
    {{compose}} down -v
    {{compose}} up -d

status:
    {{compose}} ps

logs service="":
    {{compose}} logs -f {{service}}

pull:
    {{compose}} pull

config:
    {{compose}} config

# ═══════════════════════════════════════════════════════════════
# Load testing (k6)
# ═══════════════════════════════════════════════════════════════

# Run the k6 load test against the running stack (generates traffic
# visible in Grafana).
load:
    {{compose}} --profile load run --rm k6

# ═══════════════════════════════════════════════════════════════
# Terraform (local)
# ═══════════════════════════════════════════════════════════════

tf-init:
    terraform -chdir=terraform/local init

tf-plan:
    terraform -chdir=terraform/local plan

tf-apply:
    terraform -chdir=terraform/local apply

tf-destroy:
    terraform -chdir=terraform/local destroy

tf-fmt:
    terraform fmt -recursive terraform

tf-validate:
    terraform -chdir=terraform/local validate

# ═══════════════════════════════════════════════════════════════
# Security
# ═══════════════════════════════════════════════════════════════

sbom:
    {{engine}} sbom --version >/dev/null 2>&1 || true
