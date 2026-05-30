# Compose Stack (`compose/`)

Este directorio define el entorno local completo del proyecto con Docker Compose.

## Objetivo

Levantar, con un solo comando, todos los servicios del entregable:

- base de datos (`mongo`)
- cache (`redis`)
- backend (`api`)
- frontend (`web`)
- observabilidad (`prometheus`, `grafana`)
- carga de prueba bajo demanda (`k6`)

## Archivo principal

- [`docker-compose.yml`](/home/pepe/proyectos/pin-equipo4/compose/docker-compose.yml)

## Servicios y funcion de cada uno

### `mongo` (MongoDB 7)

- Guarda los datos persistentes de la aplicacion.
- Usa volumen `mongo_data`.
- Se inicializa con usuario/password root via variables de entorno.
- Tiene healthcheck con `mongosh` (`db.adminCommand('ping')`).

### `redis` (Redis 7)

- Cache y almacenamiento rapido para la API.
- Requiere password (`--requirepass`) para paridad con produccion.
- Usa volumen `redis_data`.
- Tiene healthcheck con `redis-cli ping`.

### `api` (`ghcr.io/lucasidev/pokedex-api:latest`)

- Backend Node/Express del sistema.
- Depende de `mongo` y `redis` saludables.
- Expone `3000` interno y publica en `API_HOST_PORT` (default `3000`).
- Endpoints relevantes:
  - `/health` (salud)
  - `/metrics` (metricas Prometheus)
- Configura:
  - conexion a Mongo y Redis
  - JWT
  - usuario admin seed
  - rate limit por IP
  - CORS para el frontend local

### `web` (`ghcr.io/lucasidev/pokedex-web:latest`)

- Frontend React servido por nginx.
- Depende de `api` saludable.
- Expone `80` interno y publica en `WEB_HOST_PORT` (default `8080`).
- Se conecta al backend por red interna Compose (`http://api:3000`).

### `prometheus` (`prom/prometheus:v3.1.0`)

- Recolecta metricas del stack.
- Scrapea al `api` en `/metrics`.
- Monta configuracion desde:
  - `../observability/prometheus/prometheus.yml`
- Usa volumen `prometheus_data`.
- Publica en `PROMETHEUS_HOST_PORT` (default `9090`).

### `grafana` (`grafana/grafana:11.5.1`)

- Visualizacion de metricas y dashboards.
- Depende de `prometheus`.
- Carga provisioning y dashboard desde:
  - `../observability/grafana/provisioning`
  - `../observability/grafana/dashboards`
- Usa volumen `grafana_data`.
- Publica en `GRAFANA_HOST_PORT` (default `3001`).

### `k6` (`grafana/k6:latest`) - perfil `load`

- Generador de carga para pruebas.
- No queda corriendo: se ejecuta bajo demanda.
- Solo corre con profile `load`.
- Script:
  - `../k6/load-test.js`

## Orden de arranque (dependencias)

1. `mongo` y `redis`
2. `api` (cuando `mongo` y `redis` estan healthy)
3. `web` y `prometheus`
4. `grafana`
5. `k6` solo cuando se invoca manualmente

## Variables de entorno

Template:

- [`compose/.env.example`](/home/pepe/proyectos/pin-equipo4/compose/.env.example)

Uso:

```bash
cp compose/.env.example compose/.env
```

Variables clave:

- Secrets:
  - `MONGO_ROOT_PASSWORD`
  - `REDIS_PASSWORD`
  - `JWT_SECRET` (min 32 chars recomendado)
  - `ADMIN_PASSWORD`
  - `GRAFANA_ADMIN_PASSWORD`
- Operativas:
  - `RATE_LIMIT_MAX` (subir para pruebas de carga, ej. `2000`)
- Puertos host:
  - `API_HOST_PORT`
  - `WEB_HOST_PORT`
  - `PROMETHEUS_HOST_PORT`
  - `GRAFANA_HOST_PORT`

## URLs por defecto

- Frontend: `http://127.0.0.1:8080`
- API: `http://127.0.0.1:3000`
- Health API: `http://127.0.0.1:3000/health`
- Metrics API: `http://127.0.0.1:3000/metrics`
- Prometheus: `http://127.0.0.1:9090`
- Grafana: `http://127.0.0.1:3001`

## Comandos recomendados (via `just`)

Desde la raiz del repo:

```bash
just up        # levanta el stack
just status    # estado de contenedores
just logs api  # logs de un servicio
just load      # ejecuta k6 (perfil load)
just down      # baja el stack
just reset     # baja + borra volumenes + vuelve a levantar
```

## Notas operativas

- `just up` ejecuta antes `ensure-ports`, que ajusta puertos en `compose/.env`
  para evitar conflictos de "port already allocated".
- Los datos de Mongo/Redis/Prometheus/Grafana persisten en volumenes Docker.
- `just reset` es destructivo para datos persistidos.
