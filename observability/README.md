# Observability (`observability/`)

Este directorio define la observabilidad del proyecto con Prometheus + Grafana.

## Objetivo

Medir y visualizar el comportamiento de la API en tiempo real:

- volumen de requests
- latencia (p50, p95, p99)
- tasa de errores por status HTTP
- comportamiento del cache Redis
- llamadas proxy hacia PokeAPI

## Estructura

- [`prometheus/prometheus.yml`](prometheus/prometheus.yml)
  - Configuracion de scrapes.
- [`grafana/provisioning/datasources/datasource.yml`](grafana/provisioning/datasources/datasource.yml)
  - Datasource Prometheus provisionado automaticamente.
- [`grafana/provisioning/dashboards/dashboards.yml`](grafana/provisioning/dashboards/dashboards.yml)
  - Provider de dashboards por archivo.
- [`grafana/dashboards/pokedex-api.json`](grafana/dashboards/pokedex-api.json)
  - Dashboard principal de la API.

## Como funciona el flujo completo

1. `api` expone metricas en `GET /metrics`.
2. Prometheus scrapea `api:3000/metrics` cada `15s`.
3. Grafana consulta a Prometheus (datasource `uid: prometheus`).
4. Grafana carga automaticamente el dashboard `Pokedex API` desde JSON.

Todo esto se monta en `docker-compose` con bind mounts:

- Prometheus config -> `/etc/prometheus/prometheus.yml`
- Grafana provisioning -> `/etc/grafana/provisioning`
- Grafana dashboards -> `/var/lib/grafana/dashboards`

## Configuracion de Prometheus

En `prometheus.yml` hay 2 jobs:

- `prometheus`: auto-monitoreo de Prometheus (`localhost:9090`)
- `pokedex-api`: scrape del backend en `api:3000`, ruta `/metrics`

Frecuencias:

- `scrape_interval: 15s`
- `evaluation_interval: 15s`

## Configuracion de Grafana (provisioning)

Datasource:

- nombre: `Prometheus`
- `uid: prometheus`
- URL interna: `http://prometheus:9090`
- `isDefault: true`

Dashboards:

- provider `pin-equipo4` de tipo `file`
- ruta monitoreada: `/var/lib/grafana/dashboards`
- refresco del provider: cada `30s`

## Dashboard incluido: `Pokedex API`

Paneles principales:

- `HTTP request rate by status`
- `HTTP latency (p50 / p95 / p99)`
- `Redis cache hit ratio`
- `PokeAPI proxy requests by status`

Refresh del dashboard:

- cada `10s`

## Como levantarlo y usarlo

Desde la raiz del repo:

```bash
cp compose/.env.example compose/.env
just up
```

URLs:

- Prometheus: `http://127.0.0.1:9090`
- Grafana: `http://127.0.0.1:3001`
- API metrics endpoint: `http://127.0.0.1:3000/metrics`

Generar trafico para poblar paneles:

```bash
just load
```

## Credenciales Grafana

Se toman de `compose/.env`:

- `GRAFANA_ADMIN_USER`
- `GRAFANA_ADMIN_PASSWORD`

## Buenas practicas operativas

- Verificar que `api` este `healthy` antes de analizar graficos.
- Correr `just load` para pruebas repetibles y comparables.
- Si no ves datos:
  - revisar `docker compose ps`
  - revisar scrape target en Prometheus (`Status -> Targets`)
  - revisar logs de `api`, `prometheus` y `grafana`
