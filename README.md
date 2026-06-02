# pin-equipo4

Proyecto Integrador Final (PIN) de la Diplomatura en DevOps de mundosE
(UNC / FCEFyN), Equipo 4. Proyecto 1: CI/CD con GitHub Actions + Terraform
+ Docker.

Este meta-repo orquesta el entregable: no contiene codigo de aplicacion,
sino la infraestructura, el pipeline, la observabilidad y las pruebas de
carga del proyecto.

## Servicios

| Servicio | Origen | Rol |
|---|---|---|
| `pokedex-api` | [lucasidev/pokedex-api](https://github.com/lucasidev/pokedex-api) | Backend Node + Express + MongoDB + Redis |

La imagen Docker del api se publica en GHCR desde su CI; este meta-repo la
consume (no la construye). El frontend [lucasidev/pokedex-web](https://github.com/lucasidev/pokedex-web)
existe como proyecto aparte pero no forma parte de este stack: el
entregable se evalua sobre el backend, que se ejercita por HTTP (k6,
`/metrics`, `/health`) sin necesidad de una UI.

## Stack del entregable

| Categoria | Herramienta |
|---|---|
| Orquestacion local | Docker Compose |
| IaC | Terraform (local + AWS) |
| Observabilidad | Prometheus + Grafana |
| Pruebas de carga | k6 |
| CI/CD | GitHub Actions |
| Seguridad | SBOM (CycloneDX) + SonarQube + Snyk |
| Datos | MongoDB 7 + Redis 7 |

## Estructura

```
compose/            docker-compose del stack completo + .env.example
observability/
  prometheus/       scrape config (/metrics del api)
  grafana/          provisioning: datasource + dashboards
k6/                 script de carga contra el api
terraform/
  local/            provider docker: levanta el stack
  aws/              EC2 + VPC: despliegue en la nube
  bootstrap/        bucket S3 para el state remoto del modulo aws
.github/workflows/  CI/CD de infra (validate, deploy AWS, SBOM, sonar, snyk)
docs/               runbook, capturas del dashboard, entrega
```

## Quick start (local)

Requisitos:

- Docker o Podman (el engine se autodetecta; `CONTAINER_ENGINE` lo fuerza).
- [`just`](https://github.com/casey/just) (task runner).
- Node.js (lo usa `just up` para elegir puertos libres vía `ensure-ports`).
- Las imágenes de GHCR deben ser accesibles (son públicas; si no, `docker login ghcr.io`).
- Para el camino IaC: Terraform >= 1.6 (ver [`terraform/local`](terraform/local/README.md)).

```bash
cp compose/.env.example compose/.env   # completar secrets
just up                                # levanta todo el stack
```

Servicios expuestos:

| URL | Servicio |
|---|---|
| http://localhost:3000 | pokedex-api |
| http://localhost:3000/metrics | metricas Prometheus del api |
| http://localhost:9090 | Prometheus |
| http://localhost:3001 | Grafana |

Verificar que levantó OK:

```bash
just status                            # todos los contenedores Up/healthy
curl -fsS http://localhost:3000/health # debe devolver 200 con mongo y redis ok
```

```bash
just load        # corre la prueba de carga k6 (genera trafico)
just down        # baja el stack
```

## Rubrica del Proyecto 1

| Criterio | Peso | Donde |
|---|---|---|
| Pipeline CI/CD | 25% | `.github/workflows/` + CI de los repos |
| Infraestructura (Terraform) | 20% | `terraform/` |
| Seguridad (SBOM + SonarQube + Snyk) | 20% | CI de los repos + `.github/workflows/` |
| Contenedor Docker | 15% | Dockerfile del api + `compose/` |
| Observabilidad | 10% | `observability/` |
| Documentacion | 10% | este README + `docs/` |
