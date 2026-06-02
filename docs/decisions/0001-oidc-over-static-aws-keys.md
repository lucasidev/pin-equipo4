# 0001. OIDC en vez de access keys estáticas para autenticar el CI contra AWS

- Estado: Supersedida por [ADR 0004](0004-static-keys-for-aws-deploy-now.md)
- Fecha: 2026-06-01

> Nota: esta decisión se revirtió por pragmatismo al momento de deployar (ver
> ADR 0004). OIDC sigue siendo el objetivo a futuro; el razonamiento de este
> ADR sobre por qué OIDC es superior en seguridad se mantiene válido.

## Contexto

El pipeline necesita autenticarse contra AWS para correr Terraform (plan,
apply, destroy del módulo `terraform/aws`). La forma directa es generar un
IAM user con access key + secret key y guardarlas como GitHub secrets
(`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`). Es el atajo: cero setup en
AWS, el job arranca enseguida.

GitHub Actions soporta OpenID Connect (OIDC): el runner pide un token de
identidad de corta duración y AWS lo intercambia por credenciales temporales
asumiendo un IAM role. No hay ninguna clave de larga vida en el repo ni en
los secrets de GitHub.

El how-to completo (bootstrap del identity provider, trust policy, tabla de
secrets) está en [`docs/secrets.md`](../secrets.md). Este ADR registra la
decisión y su porqué.

## Decisión

El CI se autentica contra AWS por **OIDC**, asumiendo un IAM role vía
`aws-actions/configure-aws-credentials` con `role-to-assume`. Los jobs de AWS
declaran `permissions: id-token: write`. No se usan access keys estáticas
para el deploy.

Los secretos de la **aplicación** (Mongo, Redis, JWT, admin) siguen siendo
GitHub secrets y se pasan a Terraform como `TF_VAR_*`: esos no son
credenciales de AWS, son config de la app, y van por secrets en cualquiera de
los dos enfoques.

## Alternativas consideradas

- **Access keys estáticas como GitHub secrets.** Más simple de arrancar (no
  requiere crear el OIDC provider ni el role). Se descartó por seguridad: son
  credenciales permanentes que, si se filtran, dan acceso hasta que alguien
  las rote a mano; quedan guardadas como secreto real en GitHub. Es la
  regresión que se rechazó en la review del PR de deploy a AWS.
- **No deployar a la nube (solo local).** Cumpliría el mínimo de la rúbrica
  con la opción local, pero el PIN valora la opción nube y OIDC es justamente
  la práctica que demuestra criterio de seguridad cloud.

## Consecuencias

- **A favor:** ninguna credencial de larga vida vive en el repo ni en los
  secrets. El token OIDC dura minutos y es por job; si se filtra un log, es
  inservible al expirar. En GitHub solo se guarda el ARN del role, que no es
  secreto.
- **En contra:** hay un costo de bootstrap que las keys no tienen. Crear el
  OIDC identity provider y el IAM role con su trust policy requiere acceso a
  IAM en la cuenta (lo tiene el dueño de la cuenta). Es un setup de una sola
  vez, documentado paso a paso en `docs/secrets.md`.
- El `provider "aws"` de Terraform no cambia: toma las credenciales de la
  cadena estándar de AWS, le da igual si vienen de una key o de un token
  OIDC. La decisión es de seguridad, no de funcionalidad.
