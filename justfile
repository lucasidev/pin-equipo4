set windows-shell := ["powershell.exe", "-NoLogo", "-NoProfile", "-Command"]

# Container engine: podman or docker. Override with CONTAINER_ENGINE.
engine := env("CONTAINER_ENGINE", "docker")
compose := engine + " compose -f compose/docker-compose.yml --env-file compose/.env"

default:
    @just --list

# ═══════════════════════════════════════════════════════════════
# Stack (docker compose)
# ═══════════════════════════════════════════════════════════════

# Pick free host ports and write them to compose/.env, so `up` never
# crashes on "port already allocated" when another project holds a default.
ensure-ports:
    node scripts/ensure-ports.mjs

# Pull images and start the full stack (api, mongo, redis,
# prometheus, grafana). Resolves host ports first.
up: ensure-ports
    {{compose}} up -d

down:
    {{compose}} down

# Wipe volumes too (DESTRUCTIVE: loses mongo/redis/grafana data).
reset: ensure-ports
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
