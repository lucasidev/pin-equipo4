# 0005. Recrear la instancia en cada deploy y estrategia de rollback

- Estado: Aceptada
- Fecha: 2026-06-01

## Contexto

La imagen de la app se hornea en el `user_data` de la EC2
(`terraform/aws/ec2.tf`), que solo se ejecuta en el primer boot. Con la imagen
fijada en `:latest`, un `terraform apply` posterior no veía ningún cambio y la
instancia seguía corriendo la imagen vieja: no había forma de rodar una imagen
nueva ni, por lo tanto, de volver atrás a una buena.

Hace falta resolver dos cosas juntas: cómo se actualiza la imagen, y cómo se
revierte cuando un deploy sale mal. Son la misma decisión: si no hay forma
determinista de elegir qué imagen corre, no hay rollback.

## Decisión

**Rollout por tag inmutable + recreación de la instancia:**

- La app se deploya por un tag inmutable `sha-<commit>` (no `:latest`), pasado
  como `TF_VAR_api_image`. Cada build de la API publica ese tag a GHCR.
- El `aws_instance` usa `user_data_replace_on_change = true`: cambiar el tag
  cambia el `user_data`, y Terraform **recrea la instancia** con la imagen
  nueva.

**Rollback = re-deploy del tag anterior.** Volver atrás es correr el deploy con
el `sha-<commit>` que sí funcionaba. Esto se apoya en dos cosas que ya existen:

- **Tags inmutables**: cada versión tiene un identificador estable, así que
  "la imagen anterior" es una referencia concreta, no un `latest` ambiguo.
- **State remoto versionado** (backend S3 con versioning): permite destruir
  limpio y restaurar revisiones de state si el propio state se corrompe.

Los procedimientos concretos de reversión (app rota, infra rota, state
corrupto, lock trabado, SSH perdido, bajar todo) están en
[`docs/runbook.md`](../runbook.md).

## Alternativas consideradas

- **Rolling update sin recrear** (SSM o remote-exec que hace
  `docker compose pull && up -d` en la instancia viva). Cero downtime y misma
  IP. Se descartó por complejidad: requiere SSM agent o SSH desde el runner, y
  para un host de demo no justifica el costo. Queda como mejora futura si el
  downtime molestara.
- **Seguir con `:latest`**. Es lo que había, y el problema es que no permite ni
  rollout ni rollback deterministas: `latest` apunta a algo que cambia. Sin
  inmutabilidad no hay "volver a la versión buena".

## Consecuencias

- **A favor:** rollout y rollback deterministas y simples (un tag, un dispatch).
  Reversión documentada para los casos reales. El state versionado da una red
  extra si el state mismo se daña.
- **En contra:** cada deploy de imagen **recrea la instancia**: hay un breve
  downtime y la IP pública cambia. Aceptable para un demo; no para producción.
- **Pérdida de datos en recreación**: Mongo/Redis viven en volúmenes de la
  instancia, así que recrear (o destruir) **borra esos datos**. Para el demo es
  el comportamiento esperado; preservarlos exigiría EBS separado o backups,
  fuera de alcance. Anotado en el runbook.
