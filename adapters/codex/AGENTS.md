# AGENTS.md — guía de repo para Codex

Codex lee este fichero como guía de proyecto. Apunta a los recursos clave para entender las convenciones y flujos de trabajo.

## Guía de flujos de trabajo

Lee `FLOW.md` en la raíz del repo antes de hacer cualquier cosa. Contiene:

- **tracker**: cómo leer tickets (herramienta, comando, prefijo).
- **git**: convenciones de rama, MR/PR, squash, assignee, rama base.
- **quality**: comandos de estilo, análisis estático, tests, actualización de BD.
- **conventions**: skills o skills de código que aplican a este proyecto.
- **agents**: mapa de roles de subagentes (architecture, persistence, api, testing, security, performance, queues, frontend, frontend_test).
- **review**: skill de revisión de código del proyecto.
- **domain_memory**: si está habilitado, usa el MCP `domain-memory` en los pasos indicados.
- **observability**: perfil de servicios, queries y umbrales para la vigilancia post-despliegue.

Si `FLOW.md` no existe, cada comando del flujo autodescubre los valores o usa comportamiento por defecto.

## Flujos disponibles

Los flujos se invocan como prompts personalizados con el prefijo `/`:

| Comando | Descripción |
|---------|-------------|
| `/feat-start {TICKET}` | Arranca una feature nueva |
| `/feat-brainstorm` | Genera opciones y riesgos antes de diseñar |
| `/feat-design` | Diseño técnico (sin código) |
| `/feat-plan` | Trocea el trabajo en MRs/PRs independientes (M/L) |
| `/feat-build` | Implementa la feature |
| `/feat-review` | Code review multiagente obligatorio |
| `/feat-validate` | Valida tests, casos límite e integridad |
| `/feat-ship` | Commit, push, MR/PR y oferta de guardar conocimiento |
| `/bug-start {TICKET}` | Arranca una incidencia |
| `/bug-diagnose` | Reproduce el fallo y delimita qué está roto |
| `/bug-investigate` | Encuentra la causa raíz |
| `/bug-fix` | Aplica el arreglo mínimo |
| `/bug-validate` | Test de regresión y verificación |
| `/bug-review` | Code review del arreglo |
| `/bug-postmortem` | Lecciones aprendidas (M/L) |
| `/bug-ship` | Commit, push, MR/PR del arreglo |
| `/work-status` | Panorámica de todos los trabajos abiertos |
| `/work-resume` | Retoma el trabajo de la rama actual |
| `/work-watch {TICKET} [duración]` | Vigilancia post-despliegue (un ciclo) |
| `/work-abandon` | Cierra un work sin enviar |
| `/save-knowledge` | Consolida hallazgos al almacén de domain-memory |

## Estructura de artefactos

Cada trabajo vive en `.claude/work/{TICKET}/`:

```
meta.json              — estado del trabajo (fase, tamaño, rama)
01-context.md          — contexto del ticket
02-brainstorm.md       — opciones consideradas (feat)
02-diagnose.md         — diagnóstico del fallo (bug)
03-design.md           — diseño técnico
03-investigation.md    — investigación causa raíz (bug)
04-mr-plan.md          — plan de entrega (M/L)
04-fix.md              — arreglo (bug)
05-implementation.md   — bitácora de implementación
05-validation.md       — validación del arreglo (bug)
06-review.md           — resultados del code review
07-validation.md       — validación de la feature
99-postmortem.md       — postmortem (bug M/L)
99-abandoned.md        — motivo de abandono
monitor.md             — estado de vigilancia post-despliegue
```

## Configuración de subagentes

Los subagentes que usan los flujos se configuran en `~/.codex/config.toml` bajo `[agents.<nombre>]`. Los nombres de los agentes los define el usuario en el mapa `agents` de `FLOW.md`. Ver `config.snippet.toml` en este directorio para el formato y ejemplos comentados.
