# 0003. EC2 single-host con compose en `user_data` y exposición pública declarada

- Estado: Aceptada
- Fecha: 2026-06-01

## Contexto

La opción nube necesita correr el stack (mongo, redis, api) en AWS. Hay un
rango amplio de cómo: desde un orquestador administrado (ECS, EKS) hasta una
sola máquina con Docker. El alcance del PIN es demostrar un deploy
reproducible con Terraform, no operar un cluster.

El módulo `terraform/aws` levanta una VPC con una subnet pública, un internet
gateway, un security group y una sola EC2 (`terraform/aws/vpc.tf`,
`ec2.tf`). La EC2 se autoconfigura por `user_data`: instala Docker y escribe
un `docker-compose.yml` inline que espeja `compose/docker-compose.yml`, con
los secrets viniendo de variables Terraform (no hardcodeados).

## Decisión

Deployar a un **EC2 single-host** que corre el stack vía un compose escrito
en `user_data`. La exposición de red se declara explícitamente en el security
group: HTTP (80) y la API (3000) abiertos a internet (es un demo público),
SSH (22) restringido a `var.admin_cidr`.

El `associate_public_ip_address = true` se declara de forma explícita en
`ec2.tf` (commit `fix(terraform): declare associate_public_ip_address
explicitly on the EC2 host`) para que la IP pública sea una decisión revisada
y no un default implícito.

## Alternativas consideradas

- **ECS Fargate / EKS.** Es el camino "de producción", pero agrega una
  complejidad enorme (task definitions, cluster, networking, IAM por servicio)
  que no aporta nada a lo que la rúbrica evalúa y que excede el scope del PIN.
  Sobreingeniería para un demo de un solo stack.
- **AMI pre-horneada con Packer / Ansible.** Más reproducible que `user_data`,
  pero suma otra herramienta y un paso de build. Para el alcance, `user_data`
  bootea el host de forma autocontenida y verificable.
- **SSH abierto a `0.0.0.0/0`.** Más cómodo, pero deja el puerto de
  administración expuesto a todo internet. Se descartó: SSH queda limitado a
  `var.admin_cidr`.

## Consecuencias

- **A favor:** el módulo es chico y autocontenido; un `terraform apply` levanta
  todo el stack en un host. El compose en `user_data` reusa la misma forma que
  el stack local, así que las tres vistas (compose, tf local, tf aws) cuentan
  la misma historia.
- **En contra:** un solo host no tiene alta disponibilidad ni escala
  horizontal; si la EC2 cae, el stack cae. Es aceptable para un demo del PIN,
  no para producción. La exposición pública de 80/3000 es intencional (es un
  demo accesible), pero está declarada como decisión, no heredada de un
  default.
- Los datos viven en volúmenes de la instancia: destruir la EC2 destruye el
  estado. Para el alcance no hay backend remoto ni persistencia externa.
