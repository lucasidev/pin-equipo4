# 0002. Dos módulos Terraform paralelos: `local` (docker) y `aws` (EC2 + VPC)

- Estado: Aceptada
- Fecha: 2026-06-01

## Contexto

La consigna del PIN pide una opción local y una opción nube para la infra,
ambas con Terraform. Son dos targets muy distintos: localmente el stack corre
como contenedores en el engine de la máquina; en la nube corre en una EC2.

El módulo `terraform/local` usa el provider `kreuzwerker/docker` y declara los
servicios como `docker_container` / `docker_image` / `docker_volume`
(ver `terraform/local/main.tf`, `containers.tf`). El módulo `terraform/aws`
usa el provider `hashicorp/aws` y declara una VPC, un security group y una
EC2 (`terraform/aws/vpc.tf`, `ec2.tf`).

## Decisión

Mantener **dos módulos Terraform separados**, uno por target, en lugar de un
módulo único parametrizado. Cada uno con su provider, su state y su
`terraform.tfvars`. La regla de convivencia (declarada en el `CLAUDE.md` del
repo) es mantener coherencia entre ambos: el mismo stack lógico (mongo, redis,
api, observabilidad), las mismas decisiones de healthcheck y secrets, en dos
implementaciones.

## Alternativas consideradas

- **Un módulo único con una variable `target = local | aws`.** Menos
  duplicación aparente, pero los dos providers (docker vs aws) no comparten
  casi ningún recurso: un `docker_container` no tiene nada que ver con un
  `aws_instance`. El módulo terminaría siendo dos ramas enormes con `count`
  /`for_each` condicionales, más difícil de leer que dos módulos limpios. Es
  la abstracción equivocada: duplicación barata frente a una abstracción cara
  y forzada.
- **Solo el módulo local.** Cumpliría el mínimo, pero deja afuera la opción
  nube que la rúbrica valora (20% de Infra).
- **Solo compose, sin Terraform para local.** El compose ya existe y es el
  camino rápido de dev, pero la rúbrica pide IaC; `terraform/local` es la
  versión declarativa con state administrado.

## Consecuencias

- **A favor:** cada módulo es legible y idiomático para su provider. El local
  inyecta la config de observabilidad con bloques `upload` (portable, sin
  bind mounts a paths absolutos); el aws bootea la EC2 con `user_data`. Nada
  de condicionales cruzados.
- **En contra:** hay que mantener dos módulos en sincronía a mano. Un cambio
  en el stack (ej. una variable de entorno nueva del api) debe replicarse en
  los dos. El costo se asume conscientemente: la coherencia se cuida en cada
  PR, y es más barato que mantener un módulo único enredado.
- El compose (`compose/docker-compose.yml`) es una tercera vista del mismo
  stack (el camino de dev rápido). Las tres (compose, tf local, tf aws) deben
  contar la misma historia.
