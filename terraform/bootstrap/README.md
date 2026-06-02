# terraform/bootstrap

Crea el bucket S3 que aloja el state remoto del modulo
[`terraform/aws`](../aws/README.md). Es un paso previo de una sola vez.

## Por que existe

`terraform/aws` usa un backend S3 para que su state persista entre corridas
(necesario para apply/destroy repetibles desde CI). Pero el bucket que aloja
ese state tiene que existir antes de que ese modulo pueda inicializar su
backend: es un huevo-y-gallina. Este modulo lo resuelve creando el bucket con
un state local, fuera del modulo principal.

## Que crea

- `aws_s3_bucket` (`var.state_bucket_name`, default `pin-equipo4-tfstate`).
- Versioning habilitado (permite recuperar states previos).
- Encryption en reposo (AES256).
- Public access block (el state es sensible, nada publico).
- `prevent_destroy` en el bucket: no se borra por accidente.

## Uso (una vez)

Requiere credenciales AWS (las access keys de la cuenta) y Terraform >= 1.10.

```bash
cd terraform/bootstrap
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_DEFAULT_REGION=us-east-1
terraform init
terraform apply
```

`terraform output state_bucket_name` confirma el nombre del bucket. Ese valor
es el que usa el bloque `backend "s3"` de `terraform/aws/provider.tf`.

## Notas

- **State de este modulo**: es local (`terraform.tfstate` en esta carpeta,
  gitignored). No se mueve a S3: es el plumbing que crea el S3. Para el
  alcance del PIN, queda en la maquina de quien lo corre.
- **No destruir el bucket** mientras `terraform/aws` tenga state ahi. El
  `prevent_destroy` lo protege; si realmente hay que borrarlo, primero
  `destroy` del modulo aws y vaciar el bucket a mano.
- La region del bucket debe coincidir con la region del backend en
  `terraform/aws`.
