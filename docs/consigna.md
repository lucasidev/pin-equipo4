# Consigna: Proyecto Integrador Final (PIN)

> Transcripcion de la consigna oficial del PIN (diplomatura DevOps, mundosE).
> El equipo eligio el Proyecto 1.

## Objetivo general

Que los estudiantes integren los contenidos de la diplomatura mediante
proyectos practicos que combinen IaC, CI/CD, contenedores, seguridad y
monitoreo, aplicando buenas practicas de trazabilidad y entrega continua.

Cada equipo elige un (1) proyecto, sube la documentacion (entregables) al
drive "PIN" y lo presenta en el encuentro final como requisito para la
certificacion.

Cada proyecto practico incluye: objetivo, herramientas (una por
categoria), entregables claros, opcion local y nube, y rubrica detallada.
Seguridad siempre incluida. Aplicacion base simple generada con IA.

## Proyecto 1: CI/CD con GitHub Actions + Terraform + Docker

**Objetivo:** construir un pipeline en GitHub Actions que compile, testee
y despliegue una aplicacion en un contenedor Docker. La infraestructura se
gestiona con Terraform. Incluir controles de seguridad en el pipeline.

### Herramientas (una por categoria)

| Categoria | Herramienta |
|---|---|
| CI/CD | GitHub Actions |
| IaC | Terraform |
| Contenedores | Docker |
| Seguridad | SonarQube/ESLint + Snyk |
| Monitoreo | Prometheus + Grafana |

### Entregables

Presentar en un archivo comprimido (`.zip` o `.tar.gz`):

- Workflow `.yml` de GitHub Actions.
- Archivos Terraform (`.tf`) para levantar la infraestructura.
- `Dockerfile` y artefacto generado.
- SBOM (CycloneDX/SPDX).
- Captura del dashboard de metricas basicas.
- README claro + capturas o video demostrativo.

Nombrar el comprimido como `Proyecto 1_Equipo4.zip`.

**Opcion local:** Docker + Terraform en VirtualBox.
**Opcion nube:** AWS (si se desea cambiar, consultar al docente).

### Rubrica

| Criterio | Descripcion | Aporte |
|---|---|---|
| Pipeline CI/CD | Workflow ejecuta build, tests y despliegue correctamente | 25% |
| Infraestructura | Terraform despliega entorno local/nube correctamente | 20% |
| Seguridad | SBOM + analisis de codigo/dependencias en pipeline | 20% |
| Contenedor | Imagen Docker reproducible, con Dockerfile documentado | 15% |
| Observabilidad | Dashboard en Prometheus/Grafana con metricas visibles | 10% |
| Documentacion | README claro + capturas/video demostrativo | 10% |
