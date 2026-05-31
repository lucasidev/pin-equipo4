# terraform/local

Declarative provisioning of the full stack on a local container engine,
using the [kreuzwerker/docker](https://registry.terraform.io/providers/kreuzwerker/docker/latest)
provider. This is the Infrastructure-as-Code deliverable: the same five
services the compose file runs (mongo, redis, api, prometheus, grafana),
defined as Terraform resources with managed state.

The observability config (`prometheus.yml`, the Grafana datasource and
dashboards) is injected with `upload` blocks instead of host bind mounts,
so the module is portable across Docker Desktop, Linux and podman without
depending on absolute host paths.

## Prerequisites

- Terraform >= 1.6
- A running container engine (Docker Desktop, Docker Engine, or podman).
- The GHCR app images must be reachable: either public, or the daemon
  authenticated with `docker login ghcr.io`.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars   # fill in the secrets
terraform init
terraform plan
terraform apply
```

`terraform output` prints the URLs:

| Output | Default |
|---|---|
| web_url | http://localhost:8080 |
| api_url | http://localhost:3000/api |
| api_metrics_url | http://localhost:3000/metrics |
| prometheus_url | http://localhost:9090 |
| grafana_url | http://localhost:3001 |

Tear down with `terraform destroy` (named volumes are removed too).

## Notes

- **Engine host**: `host` auto-detects via `DOCKER_HOST` or the platform
  default socket. On Windows or podman you may need to set `docker_host`
  (see `terraform.tfvars.example`).
- **Dependency ordering**: the docker provider's `depends_on` waits for
  container creation, not health. The app containers use
  `restart = "unless-stopped"`, so the api recovers if it starts before
  mongo/redis accept connections. Expect a restart cycle or two on first
  `apply`. The api image carries its own `/health` healthcheck.
- **State**: local backend (`terraform.tfstate`, gitignored). A remote
  backend is out of scope for the PIN.
- **Secrets**: passed via `terraform.tfvars` (gitignored) and marked
  `sensitive`, so they are not printed in plan/apply output.
- This mirrors `compose/docker-compose.yml`: compose is the quick dev
  path, this module is the IaC path. Keep them in sync.
