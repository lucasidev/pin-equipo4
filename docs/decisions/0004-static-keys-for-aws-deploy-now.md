# 0004. Access keys estáticas para el deploy a AWS (por ahora)

- Estado: Aceptada
- Fecha: 2026-06-01
- Supersede a [ADR 0001](0001-oidc-over-static-aws-keys.md)

## Contexto

El [ADR 0001](0001-oidc-over-static-aws-keys.md) decidió usar OIDC para
autenticar el CI contra AWS, y ese razonamiento de seguridad sigue siendo
correcto (token de corta vida vs clave permanente). Pero al momento de
deployar de verdad, OIDC tiene un costo de bootstrap que no estaba hecho:
crear el OIDC identity provider y el IAM role con su trust policy en la cuenta.

El equipo ya validó el flujo de deploy con access keys estáticas en otro
proyecto, y necesita levantar el stack en AWS ahora. Trabarse en el bootstrap
de OIDC bloquea el entregable sin aportar a lo que la rúbrica evalúa en este
momento.

## Decisión

Usar **access keys estáticas** (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`
como GitHub secrets) para que el CI se autentique contra AWS, en los jobs
`plan-aws`, `apply-aws` y `destroy-aws`. OIDC queda pendiente para una
iteración futura.

Es una aplicación del pragmatismo: una regla fuerte (OIDC, ADR 0001) se anula
con una razón explícita (desbloquear el deploy ya, con un método ya validado),
no por dogma. La decisión es reversible: volver a OIDC es cambiar el bloque de
auth de los jobs y correr el bootstrap, sin tocar el resto.

## Alternativas consideradas

- **Hacer el bootstrap de OIDC ahora.** Es lo correcto a largo plazo y está
  documentado paso a paso en [`secrets.md`](../secrets.md). Se pospone porque
  agrega trabajo de setup en AWS justo cuando lo que se necesita es deployar,
  y el equipo ya tiene un camino con keys que funciona.
- **No deployar a la nube.** Cumpliría el mínimo con la opción local, pero
  deja afuera la opción nube que la rúbrica valora.

## Consecuencias

- **A favor:** desbloquea el deploy a AWS de inmediato, con un método ya
  probado por el equipo. Cero bootstrap de IAM/OIDC.
- **En contra:** las access keys son credenciales de larga vida en los GitHub
  secrets. Si se filtran (ej. un log mal manejado), dan acceso hasta que
  alguien las rote a mano. Mitigaciones: la IAM user debería tener el scope
  mínimo necesario (EC2 + VPC + S3 del state), y rotar las keys periódicamente.
- **Deuda explícita:** migrar a OIDC queda como mejora pendiente. El ADR 0001
  conserva el cómo y el por qué; este ADR registra por qué se pospuso.

## Nota: cómo se dispara el deploy

El deploy no es manual puro ni auto-push sin freno. Es **CD con gate de
aprobación y filtro de cambios**:

- Un push a `main` dispara el workflow, pero el `apply` solo se **propone** si
  el push tocó la infra que se deploya: `terraform/aws/**` o
  `compose/docker-compose.yml` (lo detecta el job `changes` con un `git diff`).
  Un merge de solo-docs, k6 u observabilidad **no** dispara deploy.
- Cuando sí se propone, el job de `apply` declara `environment: production`,
  que exige la aprobación del owner antes de tocar AWS.
- El `destroy` y el `bootstrap` del bucket de state son manuales
  (`workflow_dispatch`).

Caso límite a tener presente: el filtro detecta cambios en la **infra de este
repo**, no en la **imagen** de la app. La imagen (`pokedex-api:latest`) la
publica el CI de su propio repo a GHCR; eso no es un push a pin-equipo4, así
que no auto-deploya. Para tomar una imagen nueva sin cambiar la infra, se usa
el deploy manual: Actions > CI > Run workflow > `action = apply`.

Los workflows están modularizados en reusables (`aws-deploy.yml`,
`aws-destroy.yml`, `aws-bootstrap.yml`) orquestados desde `ci.yml`, patrón
inspirado en el repo del equipo pero con el gate de aprobación y el filtro de
cambios que aquel no tiene.
