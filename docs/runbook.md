# Runbook operativo (AWS)

Procedimientos manuales y de reversión para el deploy a AWS. El flujo normal es
automático con aprobación (ver [`.github/workflows/README.md`](../.github/workflows/README.md));
esto es el "qué hago cuando algo sale mal" o cuando necesito operar a mano.

Todo asume que el bucket de state existe (`action = bootstrap`, una vez) y que
los secrets de AWS están configurados.

## Glosario rápido

- **Deploy** = `terraform apply` del módulo `terraform/aws` (crea/actualiza la EC2).
- **State** = el archivo en S3 (`pin-equipo4-tfstate`) que recuerda qué se creó.
  Tiene versioning: cada cambio guarda una revisión recuperable.
- Disparadores: Actions > CI > Run workflow, con el input `action`.

## Deploy manual (sin esperar un push)

Actions > CI > Run workflow:

- `action = apply`, `image_tag` vacío -> deploya el default (`latest`), util
  para el primer deploy.
- `action = apply`, `image_tag = sha-<commit>` -> deploya esa imagen inmutable
  (recrea la instancia). El tag se ve en el package de GHCR o en el run del CI
  de pokedex-api.

Luego aprobar el environment `production`. Verificar:

```bash
curl -fsS http://<server_public_ip>:3000/health   # 200 cuando levantó
```

(la IP sale de `terraform output server_public_ip`, visible en el log del job).

## Reversión de las cagadas más probables

### 1. Un deploy rompió la app (imagen mala o config mala)

Síntoma: tras un deploy, `/health` no responde 200 o la API se comporta mal.

Reverción: re-deployar la **imagen anterior que sí funcionaba**.

1. Identificar el tag bueno anterior (GHCR muestra el historial de tags
   `sha-<commit>`, o el commit previo de la API).
2. Actions > CI > Run workflow > `action = apply`, `image_tag = sha-<commit-bueno>`.
3. Aprobar. Terraform recrea la instancia con la imagen vieja.

Esto es rollback de aplicación: volver atrás es deployar el tag previo. Por eso
importan los tags inmutables (no se puede "volver" a un `latest` ambiguo).

### 2. El apply dejó la infra en mal estado

Síntoma: el `apply` falló a mitad, o la EC2 quedó inconsistente.

Reverción: destruir y volver a crear.

1. Actions > CI > Run workflow > `action = destroy`. Aprobar.
2. Confirmar que bajó: el job termina ok; `aws ec2 describe-instances` no
   muestra la instancia.
3. `action = apply` de nuevo con el tag bueno.

El state en S3 permite el destroy limpio (sabe qué borrar). Sin state remoto
esto no se podría: de ahí el backend S3.

### 3. State corrupto o un apply lo dejó mal

Síntoma: Terraform se queja del state, o un apply escribió un state inconsistente.

Reverción: el bucket tiene **versioning**, así que se puede volver a una
revisión anterior del state.

```bash
# listar versiones del objeto de state
aws s3api list-object-versions --bucket pin-equipo4-tfstate \
  --prefix aws/terraform.tfstate

# restaurar una version anterior (copiando esa version sobre la actual)
aws s3api copy-object --bucket pin-equipo4-tfstate \
  --copy-source "pin-equipo4-tfstate/aws/terraform.tfstate?versionId=<VERSION_ID>" \
  --key aws/terraform.tfstate
```

Después correr `terraform plan` para confirmar que el state restaurado coincide
con la infra real antes de cualquier apply.

### 4. El lock quedó trabado (apply interrumpido)

Síntoma: `Error acquiring the state lock`. Pasa si un apply se cortó (runner
cancelado) y el lock quedó tomado.

Reverción: liberar el lock. El error imprime el `Lock ID`.

```bash
terraform -chdir=terraform/aws force-unlock <LOCK_ID>
```

Solo hacerlo si estás seguro de que no hay otro apply corriendo (sino corromper
el state de verdad).

### 5. Perdiste acceso SSH (tu IP cambió)

Síntoma: el SSH a la EC2 da timeout. La IP residencial suele ser dinámica y
`ADMIN_CIDR` apunta a la vieja.

Reverción: actualizar la variable y re-aplicar el security group.

```bash
# detectar tu IP actual
curl -s https://api.ipify.org
# setear la variable (reemplazar por tu IP)
gh variable set ADMIN_CIDR --body "<TU_IP>/32"
```

Luego `action = apply`: Terraform actualiza solo la regla del security group
(no recrea la EC2, porque el SG es un recurso aparte).

### 6. Bajar todo (fin del demo, no gastar)

Actions > CI > Run workflow > `action = destroy`. Aprobar. Baja la EC2, la VPC
y el security group. **El bucket de state NO se borra** (es del módulo
bootstrap, con `prevent_destroy`): así un futuro deploy reusa el mismo backend.

## Qué NO se puede revertir fácil

- **Datos en la EC2**: Mongo/Redis viven en volúmenes de la instancia. Un
  destroy o una recreación (deploy de imagen nueva) **borra esos datos**. Para
  un demo no importa; si hubiera datos a preservar, harían falta volúmenes EBS
  separados o backups, fuera del alcance del PIN.
- **El bucket de state**: protegido con `prevent_destroy`. Borrarlo a propósito
  requiere quitar esa protección y vaciar el bucket a mano. No hacerlo mientras
  haya infra viva.

## Local (sin AWS)

Para reproducir o revertir el stack local, no hay riesgo de costo ni state
remoto:

```bash
just up       # levanta
just down     # baja
just reset    # baja, borra volumenes y vuelve a levantar (DESTRUCTIVO local)
```
