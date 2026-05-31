# k6 Load Testing (`k6/`)

Este directorio contiene la prueba de carga del proyecto para validar
rendimiento basico del backend y generar trafico observable en Prometheus/Grafana.

## Objetivo

El test verifica que la API:

- responda correctamente bajo carga moderada
- mantenga baja tasa de errores
- mantenga latencia aceptable en p95
- ejerza rutas que usan autenticacion JWT y cache en Redis

## Archivo principal

- [`load-test.js`](load-test.js)

## Que hace el escenario

### 1) `setup()` (una sola vez)

- Hace login del admin seed en `POST /api/auth/signin`
- Obtiene un token JWT
- Comparte el token con todos los VUs

Esto asegura que la prueba use endpoints protegidos por JWT.

### 2) Flujo por iteracion (`default`)

Cada VU, en cada iteracion:

1. `GET /api` (endpoint base de API)
2. `GET /api/pokemon/:name` con `Authorization: Bearer <token>`
3. `sleep(1)`

Los nombres Pokemon salen de un pool chico (8 nombres), para mezclar:

- primeros hits como cache miss (consulta externa)
- siguientes hits como cache hit (Redis)

Con eso se prueban metodos y metricas de cache en un patron realista.

## Perfil de carga configurado

En `options.stages`:

1. `30s` hasta `10` VUs (ramp-up)
2. `1m` en `10` VUs (steady load)
3. `15s` hasta `0` VUs (ramp-down)

## Umbrales (pass/fail)

El test falla si no cumple:

- `http_req_failed: rate < 0.05` (menos de 5% errores)
- `http_req_duration: p(95) < 1500ms`

## Integracion con Compose

El servicio `k6` vive en `compose/docker-compose.yml` con:

- imagen: `grafana/k6:latest`
- profile: `load` (no corre por defecto)
- script montado en `/scripts/load-test.js`
- `BASE_URL=http://api:3000` dentro de la red Compose

## Como ejecutarlo

Desde la raiz del repo:

```bash
cp compose/.env.example compose/.env
just up
just load
```

Comando equivalente directo:

```bash
docker compose -f compose/docker-compose.yml --env-file compose/.env --profile load run --rm k6
```

## Variables usadas por el test

- `BASE_URL` (default interno: `http://localhost:3000`)
- `ADMIN_EMAIL` (default: `admin@pokedex.local`)
- `ADMIN_PASSWORD` (default: `changeme12345`)

En Compose se inyectan `ADMIN_EMAIL` y `ADMIN_PASSWORD` desde `compose/.env`.

## Recomendacion importante para carga

Subir `RATE_LIMIT_MAX` en `compose/.env` (ej. `2000`) antes de correr `k6`.

Motivo:

- el test sale desde una sola IP dentro de Compose
- con rate limit bajo (ej. 120) vas a ver errores 429 que no reflejan
  capacidad real de la API, sino la proteccion anti abuso

## Donde mirar resultados

1. Resumen final en consola de `k6` (latencias, errores, throughput)
2. Prometheus (`/metrics`) para series de tiempo
3. Grafana dashboard `Pokedex API` para request rate, latencia y error rate
