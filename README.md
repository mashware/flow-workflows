# flow-workflows

Flujos de desarrollo guiados para agentes de terminal: `feat` (idea → diseño → build → review →
ship) y `bug` (diagnóstico → causa raíz → fix → validación → ship → postmortem), más vigilancia
post-deploy y code-review multiagente. **Agnóstico de stack**: cada repo se configura con un
`FLOW.md` en su raíz.

Trae el plugin para **Claude Code** y adaptadores para **opencode**, **Gemini CLI** y **Codex CLI**.

## Claude Code

```
/plugin marketplace add mashware/flow-workflows
/plugin install flow@flow-plugins
```
Comandos namespaced: `/flow:feat:start`, `/flow:bug:diagnose`, `/flow:work:watch`, … Para
configurar el repo, ejecuta **`/flow:init`** (autodetecta host git, comandos de test, etc. y
escribe el `FLOW.md` por ti) — o copia `plugins/flow/examples/FLOW.template.md` a mano.

Probar sin instalar: `claude --plugin-dir <ruta>/flow-workflows/plugins/flow`.

## Otros harnesses (opencode, Gemini CLI, Codex CLI)

```bash
adapters/install.sh opencode      # o: gemini | codex
```
Copia los comandos al sitio de cada herramienta y te indica qué fragmento de config (MCP,
subagentes) fusionar. Ver `adapters/README.md`. Mismo contenido y misma lógica; cambia el
formato del envoltorio y, donde la herramienta no tiene la primitiva, se degrada (ver el
`PRIMITIVES.md` de cada adaptador).

## Configuración: `FLOW.md`

Un fichero en la raíz del repo describe tus convenciones: tracker de tickets, host git y CLI,
comandos de calidad (test/lint/análisis/BD), mapa de subagentes por rol, panel de code-review,
si usas el MCP [`domain-memory`](https://github.com/mashware/domain-memory), y el perfil de
observabilidad para la vigilancia post-deploy. **Todo lo que dejes vacío se autodescubre o se
pregunta** — un repo sin `FLOW.md` funciona igual, solo con más preguntas. Plantilla en
`plugins/flow/examples/FLOW.template.md`.

## Estructura

```
flow-workflows/
├── .claude-plugin/marketplace.json     # catálogo (Claude Code)
├── plugins/flow/                       # plugin de Claude Code
│   ├── commands/  (feat/ bug/ work/ + init + save-knowledge)
│   ├── hooks/     (guarda anti-push a la rama principal)
│   └── examples/FLOW.template.md
└── adapters/
    ├── install.sh
    ├── opencode/  ·  gemini/  ·  codex/
```

## Qué no trae (a propósito)

Para ser agnóstico, `flow` **no empaqueta agentes ni un skill de review concretos** (son
específicos de lenguaje/proyecto): los nombras en tu `FLOW.md` y deben existir en tu máquina. Sí
trae el hook anti-push a `master`/`main`, que es git genérico. Dependencias opcionales que
mejoran el flujo si están presentes: el MCP `domain-memory`, el CLI de tu host git, y un CLI de
tickets. Sin ellas, esos pasos concretos degradan; el resto funciona.

## Aviso

Los adaptadores de opencode/Gemini/Codex están generados fieles al formato documentado de cada
herramienta **pero sin probar dentro de ella**. Son una primera versión sólida; valídalos al
usarlos y ajusta rutas si tu versión del harness difiere (especialmente en Codex, donde la
ubicación de prompts cambia entre versiones — ver `adapters/codex/README.md`).

## Licencia

MIT.
