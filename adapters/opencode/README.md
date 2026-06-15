# Adaptador flow → opencode

Este directorio contiene el adaptador del plugin `flow` para [opencode](https://opencode.ai). Los 22 comandos del sistema de flujos `feat`/`bug`/`work` están convertidos al formato de opencode (markdown con frontmatter `description`).

## Requisitos

- opencode instalado y configurado.
- Un fichero `FLOW.md` en la raíz de cada repo donde quieras usar los flujos. Puedes partir de la plantilla:
  ```
  ../../plugins/flow/examples/FLOW.template.md
  ```
  Un ejemplo relleno para un proyecto concreto está en:
  ```
  ```
  Si `FLOW.md` no existe, los comandos funcionan con comportamiento por defecto (autodescubren convenciones del repo).

## Instalación

### Opción A: instalación global (disponible en todos los proyectos)

Copia los comandos al directorio global de opencode:

```bash
cp commands/*.md ~/.config/opencode/commands/
```

Copia la configuración MCP al directorio global (o fusiona con el `opencode.json` existente):

```bash
# Si no tienes opencode.json global todavía:
cp opencode.json ~/.config/opencode/opencode.json

# Si ya tienes uno, fusiona manualmente la sección "mcp":
# Añade a ~/.config/opencode/opencode.json:
# "mcp": { "domain-memory": { "command": "npx", "args": ["-y", "domain-memory-mcp"] } }
```

### Opción B: instalación por proyecto (solo en el repo actual)

Copia los comandos al directorio de opencode del proyecto:

```bash
mkdir -p .opencode/commands
cp /ruta/a/adapters/opencode/commands/*.md .opencode/commands/
```

Copia o fusiona el `opencode.json` en la raíz del proyecto:

```bash
cp /ruta/a/adapters/opencode/opencode.json .opencode/opencode.json
# o fusiona la sección "mcp" con el opencode.json existente
```

## Comandos disponibles

Una vez instalados, invócalos con `/` en opencode:

### Flujo de features
| Comando | Descripción |
|---------|-------------|
| `/feat-start <TICKET>` | Arranca una feature nueva |
| `/feat-brainstorm` | Genera opciones y riesgos antes de diseñar |
| `/feat-design` | Diseña la solución técnica |
| `/feat-plan` | Trocea el trabajo en MRs/PRs independientes |
| `/feat-build` | Implementa siguiendo el diseño aprobado |
| `/feat-review` | Code review multiagente obligatorio |
| `/feat-validate` | Valida tests, edge cases e integridad |
| `/feat-ship` | Commit, push, MR/PR y oferta de guardar conocimiento |

### Flujo de incidencias
| Comando | Descripción |
|---------|-------------|
| `/bug-start <TICKET>` | Arranca el flujo de incidencia |
| `/bug-diagnose` | Reproduce el fallo y delimita qué está roto |
| `/bug-investigate` | Encuentra la causa raíz del fallo |
| `/bug-fix` | Implementa el arreglo mínimo |
| `/bug-validate` | Test de regresión y verificación |
| `/bug-review` | Code review multiagente del arreglo |
| `/bug-postmortem` | Lecciones aprendidas y oferta de guardar conocimiento |
| `/bug-ship` | Commit, push, MR/PR del arreglo |

### Comandos transversales
| Comando | Descripción |
|---------|-------------|
| `/work-README` | Guía del sistema de flujos |
| `/work-status` | Panorámica de todos los trabajos abiertos |
| `/work-resume` | Retoma el trabajo de la rama actual |
| `/work-abandon` | Cierra un work sin shipear |
| `/work-watch <TICKET> [duración]` | Vigila la observabilidad tras un despliegue (un ciclo) |
| `/save-knowledge` | Consolida hallazgos al almacén de domain-memory |

## Configuración de subagentes

Los comandos invocan subagentes `@nombre` según los roles declarados en `FLOW.md` bajo `agents.*`. Si esos campos están vacíos, los comandos degradan a un subagente de propósito general.

Para sacar el máximo partido, declara los subagentes específicos de tu proyecto en `agents/<nombre>.md` (proyecto) o `~/.config/opencode/agents/<nombre>.md` (global). Ver `PRIMITIVES.md` para el formato exacto y la tabla de nombres que espera el adaptador.

## Vigilancia continua con work-watch

El comando `/work-watch` ejecuta **un ciclo** y persiste el estado en `monitor.md`. Para vigilancia continua, configura un cron:

```bash
# Ejemplo: vigilar cada 5 minutos (ajusta la ruta y el ticket)
*/5 * * * * cd /ruta/al/repo && opencode run -p "/work-watch PROJ-XXXXX"
```

Ver `PRIMITIVES.md` para más detalles sobre esta diferencia respecto al plugin original.

## Qué no se porta 1:1

Ver `PRIMITIVES.md` para el detalle completo. Resumen:

- `AskUserQuestion` → pregunta en texto; sin menú estructurado.
- Autopilot de `watch` → cron del SO + `opencode run -p`; el estado entre ciclos vive en `monitor.md`.
