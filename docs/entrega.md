# Entrega: Proyecto Integrador Final (PIN) - Equipo 4

Documento integrador del entregable. Mapea cada criterio de la rúbrica del
Proyecto 1 a la evidencia concreta (archivo, workflow o captura) donde se
demuestra. Es la guía de lectura para la defensa.

> Consigna oficial transcripta en [`consigna.md`](consigna.md). El equipo
> eligió el Proyecto 1: CI/CD con GitHub Actions + Terraform + Docker.

## Arquitectura del entregable

El entregable es un stack de tres capas orquestado por este meta-repo, que no
contiene código de aplicación: el backend (`pokedex-api`) se construye y
publica como imagen en GHCR desde su propio CI, y acá se consume.

```
GitHub Actions (CI/CD)
  ├── pokedex-api repo: build + test + scan + Docker + publish a GHCR (firmado)
  └── pin-equipo4 (este repo):
        ├── terraform/local  -> stack en contenedores (docker provider)
        ├── terraform/aws    -> stack en EC2 (aws provider, auth por OIDC)
        ├── compose/         -> stack de dev rápido
        ├── observability/   -> Prometheus (scrape /metrics) + Grafana
        └── k6/              -> prueba de carga contra el api
```

## Mapa rúbrica -> evidencia

| Criterio | Peso | Dónde se demuestra |
|---|---|---|
| Pipeline CI/CD | 25% | `pokedex-api/.github/workflows/ci.yml` (build, test, Docker, publish), `.github/workflows/ci.yml` y `security.yml` de este repo (validación infra + escaneos) |
| Infraestructura (Terraform) | 20% | `terraform/local/` (docker) y `terraform/aws/` (EC2 + VPC). Ver [ADR 0002](decisions/0002-dual-terraform-modules-local-and-aws.md), [ADR 0003](decisions/0003-aws-single-host-ec2-with-compose-userdata.md) |
| Seguridad | 20% | SBOM CycloneDX + SonarCloud + Snyk en los CI; OIDC para AWS ([ADR 0001](decisions/0001-oidc-over-static-aws-keys.md), [`secrets.md`](secrets.md)); firma cosign de la imagen |
| Contenedor Docker | 15% | `pokedex-api/Dockerfile` (multi-stage, non-root, healthcheck); `compose/docker-compose.yml` |
| Observabilidad | 10% | `observability/` (Prometheus + Grafana provisionado, alert rules); capturas en [`img/`](img/) |
| Documentación | 10% | Este documento, el [README](../README.md), los [ADRs](decisions/) y las capturas |

## Evidencia por criterio

### 1. Pipeline CI/CD (25%)

- **Build, test y publish**: el CI de `pokedex-api` corre el quality gate
  (lint Biome + typecheck + Jest), construye la imagen Docker, y en push a
  `main` la publica a GHCR. Captura: `img/api-ci-green.png`.
- **CI de infra**: el `ci.yml` de este repo valida Terraform (`fmt`, `init`,
  `validate` de los dos módulos) y el compose en cada PR. Captura:
  `img/pin-ci-green.png`.
- **Trazabilidad**: Conventional Commits + Oneflow, validados por hooks
  locales y por workflows de CI.

### 2. Infraestructura con Terraform (20%)

- Dos módulos (`terraform/local`, `terraform/aws`) con su README cada uno.
  La decisión de mantenerlos paralelos está en [ADR 0002](decisions/0002-dual-terraform-modules-local-and-aws.md).
- El módulo AWS levanta VPC + security group + EC2 con bootstrap por
  `user_data`, decisión en [ADR 0003](decisions/0003-aws-single-host-ec2-with-compose-userdata.md).

### 3. Seguridad (20%)

- **SBOM (CycloneDX)**: generado en el CI del api (`just sbom` local, job
  dedicado en CI). Captura: `img/sbom-artifact.png`.
- **SAST + SCA**: SonarCloud (calidad + security hotspots) y Snyk
  (dependencias e IaC) corren en los pipelines. Capturas:
  `img/sonarcloud-passed.png`, `img/snyk.png`.
- **Auth a la nube sin claves**: OIDC en vez de access keys estáticas
  ([ADR 0001](decisions/0001-oidc-over-static-aws-keys.md), how-to en
  [`secrets.md`](secrets.md)).
- **Supply chain**: la imagen se publica con provenance, SBOM embebido y
  firma cosign keyless. Captura: `img/ghcr-cosign.png`.

### 4. Contenedor Docker (15%)

- `pokedex-api/Dockerfile`: multi-stage, usuario non-root, healthcheck contra
  `/health`. El compose y los dos módulos Terraform corren esa misma imagen.

### 5. Observabilidad (10%)

- Prometheus scrapea `/metrics` del api; Grafana se provisiona por archivo
  (datasource + dashboard). El dashboard cubre golden signals y métricas de
  dominio/infra/seguridad. Capturas: `img/grafana-dashboard.png` y los
  paneles solo en `img/`.
- Alert rules en Prometheus (disponibilidad, latencia, errores, dependencias,
  fuerza bruta de auth). Captura: `img/prometheus-alerts.png`.

### 6. Documentación (10%)

- Este documento integrador, el README del repo, los READMEs por carpeta
  (`observability/`, `compose/`, `k6/`, `terraform/local`, `terraform/aws`),
  los [ADRs](decisions/) y `secrets.md`.

## Cómo reproducir el stack

```bash
cp compose/.env.example compose/.env   # completar secrets
just up                                # levanta el stack completo
just load                              # genera tráfico (k6)
```

Servicios: api en `:3000`, Prometheus en `:9090`, Grafana en `:3001`.
Detalle en el [README](../README.md).

## Armado del entregable

El comprimido final `Proyecto 1_Equipo4.zip` incluye: los workflows `.yml`,
los archivos `.tf` de ambos módulos, el `Dockerfile`, el SBOM CycloneDX, las
capturas del dashboard y este conjunto de documentación.
