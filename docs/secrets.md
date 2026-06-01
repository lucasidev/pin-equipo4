# Manejo de secretos

Cómo el Equipo 4 maneja credenciales en este repo. Hay dos cosas distintas
que conviene no mezclar:

1. **Autenticación a AWS** (cómo el runner de CI se autentica contra AWS para
   correr Terraform).
2. **Secretos de la aplicación** (passwords y claves que la app necesita en
   runtime: Mongo, Redis, JWT, admin).

Ninguna de las dos vive en el repo. La diferencia es de dónde las toma cada
entorno.

## Regla de oro

- **Nada de credenciales en el repo.** Ni `.tfvars` con valores reales, ni
  `compose/.env`, ni claves en los workflows. Todo eso está en `.gitignore`.
- **Local** lee secretos de `compose/.env` (copia de `compose/.env.example`).
- **CI** lee secretos de *GitHub Actions secrets and variables*.
- **AWS** se autentica por OIDC, sin claves de larga vida en el repo ni en
  los secrets de GitHub.

## 1. Autenticación a AWS: OIDC, no access keys

El pipeline (`.github/workflows/ci.yml`) se autentica contra AWS con OIDC:

```yaml
permissions:
  id-token: write   # el runner pide un token OIDC de corta duración
  contents: read

steps:
  - name: Configure AWS credentials (OIDC)
    uses: aws-actions/configure-aws-credentials@<sha>  # v4
    with:
      role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}
      aws-region: ${{ secrets.AWS_REGION }}
```

### Por qué OIDC y no `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`

| | Access keys estáticas | OIDC |
|---|---|---|
| Vida útil | Permanentes hasta rotarlas a mano | Token de minutos, por job |
| Si se filtran | Acceso hasta que alguien las revoque | Inservible al expirar |
| Qué se guarda en GitHub | El secreto real (la key) | Solo el ARN del role (no es secreto) |
| Rotación | Manual | No aplica |

Terraform funciona igual con cualquiera de las dos: el `provider "aws"` solo
declara `region` y toma las credenciales de la cadena estándar de AWS. La
diferencia es de seguridad, no de funcionalidad.

### Bootstrap de OIDC (una sola vez)

OIDC tiene un costo inicial: hay que crear en AWS el identity provider y un
IAM role que confíe en este repo. Es lo que hace que el workflow tenga algo
que asumir. Se hace **una vez**, con tus credenciales locales (la cuenta es
IAM propio, así que tenés permiso para crearlo).

1. **Crear el OIDC identity provider** (si la cuenta no lo tiene ya):
   - Provider URL: `https://token.actions.githubusercontent.com`
   - Audience: `sts.amazonaws.com`

2. **Crear un IAM role** con una trust policy que limite quién puede asumirlo
   a este repo (ajustar `<AWS_ACCOUNT_ID>` y la rama/refs permitidas):

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Allow",
       "Principal": {
         "Federated": "arn:aws:iam::<AWS_ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
       },
       "Action": "sts:AssumeRoleWithWebIdentity",
       "Condition": {
         "StringEquals": {
           "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
         },
         "StringLike": {
           "token.actions.githubusercontent.com:sub": "repo:lucasidev/pin-equipo4:*"
         }
       }
     }]
   }
   ```

3. **Adjuntar permisos al role**: lo mínimo que necesita Terraform para crear
   la VPC, el security group y la EC2 (EC2, VPC). Para el alcance del PIN se
   puede empezar con una policy acotada a esos servicios.

4. **Guardar el ARN del role** como secret de GitHub: `AWS_ROLE_TO_ASSUME`.
   El ARN no es secreto en sí, pero se guarda como secret por prolijidad.

Con eso, cualquier job con `id-token: write` asume el role sin claves.

## 2. Secretos de la aplicación

Son distintos de la autenticación a AWS: son la config que la app necesita
para arrancar. Terraform los recibe como variables (`variable "..."` en
`terraform/aws/variables.tf`, todas marcadas `sensitive`) y los inyecta en el
`user_data` de la EC2, que escribe el `docker-compose.yml` del host.

Estos secretos van como GitHub secrets **en cualquiera de los dos enfoques de
auth**: no son claves de AWS, son config de la app. El pipeline los pasa a
Terraform vía `TF_VAR_*`:

```yaml
env:
  TF_VAR_mongo_root_password: ${{ secrets.MONGO_ROOT_PASSWORD }}
  TF_VAR_redis_password:      ${{ secrets.REDIS_PASSWORD }}
  TF_VAR_jwt_secret:          ${{ secrets.JWT_SECRET }}
  TF_VAR_admin_password:      ${{ secrets.ADMIN_PASSWORD }}
  TF_VAR_ssh_public_key:      ${{ secrets.SSH_PUBLIC_KEY }}
  TF_VAR_admin_cidr:          ${{ vars.ADMIN_CIDR }}
```

## 3. Guía operativa: pasar el deploy de access keys a OIDC

Esta es la receta concreta para reemplazar las access keys estáticas del
workflow de AWS por OIDC. Se corre una vez (el bootstrap necesita la consola
o el CLI de AWS con permisos de IAM, que tiene el dueño de la cuenta).

### Paso 1: crear el OIDC identity provider (si no existe)

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com
```

Si ya existe (otra action lo creó antes), este comando falla con
`EntityAlreadyExists`; es seguro ignorarlo.

### Paso 2: crear el IAM role con trust policy acotada al repo

Guardar esta trust policy como `trust.json` (reemplazar `<AWS_ACCOUNT_ID>`):

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::<AWS_ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:sub": "repo:lucasidev/pin-equipo4:*"
      }
    }
  }]
}
```

```bash
aws iam create-role \
  --role-name pin-equipo4-deploy \
  --assume-role-policy-document file://trust.json
```

El `sub` con `repo:lucasidev/pin-equipo4:*` limita quién puede asumir el role
a workflows de este repo. Se puede acotar más (a una rama o environment) si se
quiere, pero para el PIN con el repo completo alcanza.

### Paso 3: adjuntar permisos al role

Lo que Terraform necesita para crear la VPC, el security group y la EC2. Para
el alcance del PIN se puede empezar con las policies administradas de esos
servicios:

```bash
aws iam attach-role-policy --role-name pin-equipo4-deploy \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
aws iam attach-role-policy --role-name pin-equipo4-deploy \
  --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess
```

> Esto es amplio. Para producción se acotaría a las acciones exactas, pero
> para el demo del PIN es un punto de partida razonable.

### Paso 4: guardar el ARN del role como secret de GitHub

El comando anterior imprime el ARN (`arn:aws:iam::<id>:role/pin-equipo4-deploy`).
Guardarlo:

```bash
gh secret set AWS_ROLE_TO_ASSUME --body "arn:aws:iam::<AWS_ACCOUNT_ID>:role/pin-equipo4-deploy"
gh secret set AWS_REGION --body "us-east-1"
```

Y borrar las access keys que ya no se usan:

```bash
gh secret delete AWS_ACCESS_KEY_ID
gh secret delete AWS_SECRET_ACCESS_KEY
```

### Paso 5: cambiar el workflow de keys a OIDC

En cada job de AWS (`plan-aws`, `apply-aws`, `destroy-aws`), reemplazar el
bloque de access keys por el paso de OIDC. El cambio es el mismo en los tres:

```diff
   plan-aws:
     ...
+    permissions:
+      id-token: write   # pide el token OIDC; sin esto AWS rechaza el assume-role
+      contents: read
     steps:
       - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6
       - name: Setup Terraform
         uses: hashicorp/setup-terraform@b9cd54a3c349d3f38e8881555d616ced269862dd # v3
         with:
           terraform_version: "1.9.8"
+      - name: Configure AWS credentials (OIDC)
+        uses: aws-actions/configure-aws-credentials@7474bc4690e29a8392af63c5b98e7449536d5c3a # v4
+        with:
+          role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}
+          aws-region: ${{ secrets.AWS_REGION }}
       - name: Terraform init (aws)
-        env:
-          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
-          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
-          AWS_DEFAULT_REGION: "us-east-1"
         run: terraform -chdir=terraform/aws init
```

Los `TF_VAR_*` de la app (mongo, redis, jwt, admin, ssh) NO se tocan: siguen
viniendo de GitHub secrets como hasta ahora. Lo único que se reemplaza es la
autenticación contra AWS. Una vez configurado el role, el job `plan-aws` deja
de fallar por falta de credenciales.

## Referencia: qué va dónde

### GitHub Actions secrets (Settings > Secrets and variables > Actions)

| Nombre | Para qué | Tipo |
|---|---|---|
| `AWS_ROLE_TO_ASSUME` | ARN del IAM role que asume el runner por OIDC | secret |
| `AWS_REGION` | Región de despliegue (ej. `us-east-1`) | secret |
| `MONGO_ROOT_PASSWORD` | Password root de Mongo | secret |
| `REDIS_PASSWORD` | Password de Redis (AUTH) | secret |
| `JWT_SECRET` | Clave de firma JWT (>= 32 caracteres) | secret |
| `ADMIN_PASSWORD` | Password del admin sembrado (>= 8 caracteres) | secret |
| `SSH_PUBLIC_KEY` | Clave SSH pública para la EC2 | secret |

### GitHub Actions variables (no secretas)

| Nombre | Para qué |
|---|---|
| `ADMIN_CIDR` | CIDR autorizado para SSH (ej. `1.2.3.4/32`) |
| `ENABLE_AWS_PLAN` | `true` para activar el job `plan-aws` |

> `SSH_PUBLIC_KEY` y `ADMIN_CIDR` no son sensibles en el sentido estricto
> (una clave pública es pública), pero se gestionan junto al resto por
> comodidad. Lo crítico son los cuatro passwords y el role ARN.

### Local: `compose/.env`

Para correr el stack en la máquina, copiar `compose/.env.example` a
`compose/.env` y completar valores reales. Ese archivo está en `.gitignore` y
nunca se commitea. Cubre lo mismo que arriba más los valores de Grafana y los
puertos de host.

## Qué NO hacer

- No commitear `compose/.env`, `*.tfvars` con valores reales, ni `*.tfstate`
  (el state puede contener secretos en texto plano).
- No poner `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` como secrets de
  GitHub para el deploy: usar OIDC.
- No hardcodear passwords en `docker-compose.yml`, en los `.tf` ni en los
  workflows.
