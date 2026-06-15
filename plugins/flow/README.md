# flow — flujos de desarrollo guiados (agnóstico de stack)

Flujos `feat`/`bug`/`work` con un esqueleto común (`start → … → ship`,
`diagnose → … → postmortem`, vigilancia post-deploy) y los mismos patrones (loop-until-done en
review, cuarentena de input no confiable, verificación adversarial, puerta humana antes del
MR/PR), **sin nada pegado a un repo concreto**. Cada repositorio se configura con un `FLOW.md`.

## Configuración: `FLOW.md`

Lo más fácil: ejecuta **`/flow:init`**, que autodetecta lo que puede del repo (host git, rama
base, comandos de test, si hay migraciones, si `domain-memory` está activo) y escribe el
`FLOW.md` preguntándote solo lo no deducible. A mano: copia `examples/FLOW.template.md` a la raíz
del repo. Los comandos lo leen en su paso 0. Cubre:

- **tracker**: prefijo de ticket y cómo leerlo.
- **git**: host y CLI (GitHub, GitLab, Bitbucket, Azure, Gitea, self-hosted…), término (MR/PR), base por defecto, patrón de rama, asignee, squash, secciones de la descripción, freno de pre-deploy.
- **quality**: comandos de test/análisis/estilo/BD del repo (vacío = autodescubrir).
- **agents** / **review**: mapa rol→agente y panel de code-review.
- **conventions**: convenciones de código que los comandos deben respetar (texto libre).
- **domain_memory**: si el MCP [`domain-memory`](https://github.com/mashware/domain-memory) está activo.
- **observability**: perfil para `work:watch` (servicios, plataforma, detección de deploy, colas). Vacío = autodescubrir.

**Lo vacío o ausente degrada con elegancia**: cada comando dice qué hace si falta un dato
(autodescubrir, usar default, o preguntarte). Un repo sin `FLOW.md` sigue funcionando, solo con
más preguntas y autodescubrimiento.

## Instalar

```
/plugin marketplace add mashware/flow-workflows
/plugin install flow@flow-plugins
```
Comandos namespaced: `/flow:init`, `/flow:feat:start`, `/flow:bug:diagnose`, `/flow:work:watch`, etc.
Conviven con cualquier otro plugin o comando local.

Probar sin instalar: `claude --plugin-dir <ruta>/flow-workflows/plugins/flow`.

## Qué NO trae (a propósito)

Para ser agnóstico, `flow` **no empaqueta agentes ni el skill de review** (son específicos de
lenguaje/proyecto). El review invoca el skill/agentes que declares en `FLOW.md` (`review.*`,
`agents.*`), o el `code-review` built-in si no defines ninguno. Los agentes de refuerzo
(rendimiento, colas, frontend…) se usan solo si tu proyecto los tiene; los comandos los
referencian por rol, no por nombre propio.

Sí trae el hook anti-push a `master`/`main` (`hooks/`) — es git genérico.

## Otros harnesses

Para opencode, Gemini CLI o Codex CLI, ver `../../adapters/`.
