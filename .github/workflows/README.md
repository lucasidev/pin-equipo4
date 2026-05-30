# Workflows de CI

Este directorio contiene los pipelines de GitHub Actions del proyecto.

## Archivo actual

- `ci.yml`: pipeline principal de integracion continua para validar infraestructura.

## Para que sirve `ci.yml`

Su objetivo es detectar errores de infraestructura temprano (en cada push/PR) antes de mergear a `main`.

Valida:

- formato de Terraform (`terraform fmt -check`)
- inicializacion y validacion del modulo local (`terraform/local`)
- sintaxis de Docker Compose (`compose/docker-compose.yml`)

Ademas, incluye un job opcional para planear infraestructura AWS.

## Cuando se ejecuta

- `push` a `main`
- `pull_request` hacia `main`
- ejecucion manual (`workflow_dispatch`)

## Control de concurrencia

Usa:

- `concurrency.group: ${{ github.workflow }}-${{ github.ref }}`
- `cancel-in-progress: true`

Esto evita ejecuciones duplicadas del mismo branch y cancela corridas viejas cuando llega un commit nuevo.

## Jobs

### 1) `validate`

Siempre corre y hace:

1. `checkout` del repo
2. instala Terraform `1.9.8`
3. `terraform fmt -check -recursive terraform`
4. `terraform -chdir=terraform/local init -backend=false`
5. `terraform -chdir=terraform/local validate`
6. `docker compose -f compose/docker-compose.yml config`

## 2) `plan-aws` (opcional)

Corre solo si la variable de repositorio `ENABLE_AWS_PLAN` es `"true"` y despues de `validate`.

Hace:

1. `checkout`
2. instala Terraform `1.9.8`
3. configura credenciales AWS via OIDC (si existe el secret `AWS_ROLE_TO_ASSUME`)
4. `terraform -chdir=terraform/aws init`
5. `terraform -chdir=terraform/aws plan -no-color`

Permisos:

- `id-token: write` (necesario para OIDC)
- `contents: read`

## Variables y secrets esperados

- Variable de repo:
  - `ENABLE_AWS_PLAN` (`"true"`/`"false"`)

- Secrets para AWS (si se habilita plan):
  - `AWS_ROLE_TO_ASSUME`
  - `AWS_REGION`

## Estado actual del repo

Hoy el repo tiene implementado `terraform/local`. Si aun no existe `terraform/aws`, no habilites `ENABLE_AWS_PLAN`, porque el job `plan-aws` fallaria al no encontrar ese modulo.
