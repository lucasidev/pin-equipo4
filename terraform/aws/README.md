# terraform/aws

Provisioning of the stack on AWS as a single EC2 host, using the
[hashicorp/aws](https://registry.terraform.io/providers/hashicorp/aws/latest)
provider. This is the cloud option of the Infrastructure-as-Code deliverable:
a VPC with a public subnet, a security group, and one EC2 instance that boots
the stack (mongo, redis, api) via `user_data`.

The instance self-configures on first boot: it installs Docker and writes a
`docker-compose.yml` inline that mirrors `compose/docker-compose.yml`. Secrets
come from Terraform variables (all marked `sensitive`), never hardcoded.

See [ADR 0003](../../docs/decisions/0003-aws-single-host-ec2-with-compose-userdata.md)
for why a single EC2 host instead of ECS/EKS, and why the public exposure is
an explicit decision.

## Prerequisites

- Terraform >= 1.6
- AWS credentials. In CI this is OIDC (see
  [`docs/secrets.md`](../../docs/secrets.md) and
  [ADR 0001](../../docs/decisions/0001-oidc-over-static-aws-keys.md)); locally
  it is your usual AWS profile or environment credentials.
- An SSH public key to inject into the instance (`var.ssh_public_key`).

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars   # fill in the secrets and ssh key
terraform init
terraform plan
terraform apply
```

`terraform output` prints how to reach the host:

| Output | Descripción |
|---|---|
| server_public_ip | IP pública de la EC2 |
| api_url | `http://<ip>:3000/api` |
| ssh_command | comando SSH al host (ajustar la clave privada) |

Tear down with `terraform destroy`.

## What it creates

| Recurso | Archivo |
|---|---|
| VPC + subnet pública + internet gateway + route table | `vpc.tf` |
| Security group (HTTP 80, API 3000 públicos; SSH 22 limitado a `admin_cidr`) | `vpc.tf` |
| EC2 instance + key pair, bootstrap por `user_data` | `ec2.tf` |

## Variables

Las sensibles (`mongo_root_password`, `redis_password`, `jwt_secret`,
`admin_password`) están marcadas `sensitive` y se pasan por
`terraform.tfvars` (gitignored) o, en CI, por `TF_VAR_*` desde GitHub secrets.
Ver `variables.tf` para la lista completa con descripciones y validaciones
(ej. `jwt_secret` exige >= 32 caracteres, igual que la app al boot).

## Notes

- **Exposición de red**: HTTP (80) y la API (3000) son públicos a propósito
  (es un demo accesible). SSH (22) queda restringido a `var.admin_cidr`:
  poner tu IP en `/32`, nunca `0.0.0.0/0`. El `associate_public_ip_address`
  se declara explícito para que la IP pública sea una decisión revisada.
- **State**: backend local (`terraform.tfstate`, gitignored). El state puede
  contener secretos en texto plano, por eso no se commitea. Un backend remoto
  está fuera del alcance del PIN.
- **Coherencia**: este módulo espeja `compose/docker-compose.yml` y
  `terraform/local`. Un cambio en el stack debe replicarse en los tres
  (ver [ADR 0002](../../docs/decisions/0002-dual-terraform-modules-local-and-aws.md)).
