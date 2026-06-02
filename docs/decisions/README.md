# Architecture Decision Records

Registro de las decisiones de arquitectura del meta-repo: por qué la infra,
el pipeline y la observabilidad son como son. Cada ADR captura una decisión
con sus alternativas reales y el tradeoff que asumimos, para que dentro de
unos meses (o en la defensa del PIN) se entienda el porqué sin arqueología.

## Criterio: cuándo una decisión merece un ADR

Una decisión se documenta como ADR si cumple al menos dos de estas tres:

1. **Había alternativas reales.** Se eligió entre opciones con tradeoffs, no
   fue el único camino posible.
2. **Alguien querría romperla en 3 meses sin entender por qué.** Si el cambio
   parece "obvio" pero rompe algo no evidente, el ADR lo previene.
3. **El "por qué" se olvida fácil.** La razón no es deducible del código solo.

Lo que es consecuencia técnica forzada o best practice estándar de bajo
riesgo no lleva ADR: vive en el README o en un comentario inline.

## Índice

| ADR | Decisión |
|---|---|
| [0001](0001-oidc-over-static-aws-keys.md) | OIDC en vez de access keys estáticas para autenticar el CI contra AWS (supersedida por 0004) |
| [0002](0002-dual-terraform-modules-local-and-aws.md) | Dos módulos Terraform paralelos: `local` (docker) y `aws` (EC2 + VPC) |
| [0003](0003-aws-single-host-ec2-with-compose-userdata.md) | EC2 single-host con compose en `user_data` y exposición pública declarada |
| [0004](0004-static-keys-for-aws-deploy-now.md) | Access keys estáticas para el deploy a AWS por ahora (supersede a 0001) |

## Formato

Cada ADR sigue la misma estructura: Contexto, Decisión, Alternativas
consideradas, Consecuencias. Estado y fecha en el encabezado.
