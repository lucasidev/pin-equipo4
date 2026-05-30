# pin-equipo4

Proyecto Integrador Final (PIN) de la Diplomatura en DevOps de mundosE
(UNC / FCEFyN), Equipo 4. Proyecto 1: CI/CD con GitHub Actions + Terraform
+ Docker.

Este meta-repo orquesta el entregable: no contiene codigo de aplicacion,
sino la infraestructura, el pipeline, la observabilidad y las pruebas de
carga que integran los dos servicios del proyecto.

## Servicios

| Servicio | Origen | Rol |
|---|---|---|
| `pokedex-api` | [lucasidev/pokedex-api](https://github.com/lucasidev/pokedex-api) | Backend Node + Express + MongoDB + Redis |
| `pokedex-web` | [lucasidev/pokedex-web](https://github.com/lucasidev/pokedex-web) | Frontend React + Vite + Tailwind (nginx) |

Las imagenes Docker se publican en GHCR desde el CI de cada repo; este
meta-repo las consume (no las construye).

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
k6/                 script de carga contra el api/web
terraform/
  local/            provider docker: levanta el stack
  aws/              (Fase 2) despliegue en la nube
.github/workflows/  CI de infra (compose, terraform, SBOM, sonar, snyk)
docs/               runbook, capturas del dashboard, entrega
```

## Quick start (local)

Requiere Docker (o Podman) y just.

```bash
cp compose/.env.example compose/.env   # completar secrets
just up                                # levanta todo el stack
```

Servicios expuestos:

| URL | Servicio |
|---|---|
| http://localhost:8080 | pokedex-web |
| http://localhost:3000 | pokedex-api |
| http://localhost:3000/metrics | metricas Prometheus del api |
| http://localhost:9090 | Prometheus |
| http://localhost:3001 | Grafana |

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
| Contenedor Docker | 15% | Dockerfiles de api/web + `compose/` |
| Observabilidad | 10% | `observability/` |
| Documentacion | 10% | este README + `docs/` |
