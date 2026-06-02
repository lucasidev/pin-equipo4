# Workflows de CI/CD

Pipelines de GitHub Actions del meta-repo. La estructura es un orquestador
(`ci.yml`) que llama a workflows reusables para las acciones de AWS.

## Archivos

| Archivo | Tipo | Qué hace |
|---|---|---|
| `ci.yml` | orquestador | Entry point. Valida infra y enruta las acciones de AWS según el evento. |
| `aws-deploy.yml` | reusable (`workflow_call`) | `terraform apply` del módulo aws. Gated por el environment `production`. |
| `aws-destroy.yml` | reusable | `terraform destroy` del módulo aws. Gated por `production`. |
| `aws-bootstrap.yml` | reusable | Crea el bucket S3 del state (una vez, idempotente). Gated por `production`. |
| `security.yml` | independiente | SBOM (CycloneDX), Snyk IaC, SonarCloud. |

## Flujo según el evento

| Evento | Qué corre |
|---|---|
| Pull request a `main` | `validate` (+ `plan-aws` si `ENABLE_AWS_PLAN=true`). No toca AWS. |
| Push a `main` que toca la infra | `validate` -> `deploy` (espera aprobación del environment). |
| Push a `main` de solo docs/k6/observabilidad | `validate`. **No** dispara deploy. |
| Run workflow, `action = apply` | redeploy manual (ej. tomar imagen `:latest` nueva). |
| Run workflow, `action = bootstrap` | crea el bucket de state (una vez). |
| Run workflow, `action = destroy` | baja la infra. |

## El gate de aprobación (`environment: production`)

Los jobs que tocan AWS (`deploy`, `destroy`, `bootstrap`) corren bajo el
environment `production`, configurado con **required reviewer** = el owner.
GitHub pausa el job y pide aprobación manual antes de ejecutar. Así, un push a
main que cambia la infra no aplica solo: queda "Waiting" hasta que alguien
aprueba en la pestaña Actions. Es CD, pero con freno humano.

## El filtro de cambios (job `changes`)

Un push a main solo **propone** deploy si tocó `terraform/aws/**` o
`compose/docker-compose.yml`. Un merge de solo docs no dispara nada. El job
`changes` lo decide con un `git diff` del push.

Caso límite: el filtro mira la infra de **este** repo, no la imagen de la app.
Si `pokedex-api` publica una imagen `:latest` nueva (en su propio repo), eso no
es un push acá, así que no auto-deploya. Para tomar la imagen nueva sin cambiar
infra, usar el deploy manual (`action = apply`).

## Autenticación a AWS

Access keys estáticas (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` /
`AWS_REGION` como secrets). Ver [ADR 0004](../../docs/decisions/0004-static-keys-for-aws-deploy-now.md)
para el porqué (OIDC es el objetivo futuro) y [`docs/secrets.md`](../../docs/secrets.md)
para la tabla completa de secrets/vars.

## State de Terraform

El módulo aws usa backend S3 (`pin-equipo4-tfstate`) con lock nativo
(`use_lockfile`, Terraform 1.13). El bucket lo crea `aws-bootstrap.yml` una
vez. Ver [`terraform/bootstrap`](../../terraform/bootstrap/README.md).

## Primer deploy (orden)

1. Run workflow `action = bootstrap` (crea el bucket de state).
2. Mergear un cambio de infra a main (o `action = apply`): dispara el deploy.
3. Aprobar el environment `production` en la pestaña Actions.
4. Esperar ~2-3 min al `user_data` y verificar: `curl http://<ip>:3000/health`.

## Variables y secrets

Secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`,
`SSH_PUBLIC_KEY`, `MONGO_ROOT_PASSWORD`, `REDIS_PASSWORD`, `JWT_SECRET`,
`ADMIN_PASSWORD`. Variables: `ADMIN_CIDR` (IP del owner en /32),
`ENABLE_AWS_PLAN` (opt-in del plan en PRs). Detalle en
[`docs/secrets.md`](../../docs/secrets.md).
