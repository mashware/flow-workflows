# Adaptador flow para Gemini CLI

Este adaptador lleva los 22 comandos del plugin `flow` (`/feat:*`, `/bug:*`, `/work:*`, `/save-knowledge`) al formato de **Gemini CLI**.

Los comandos son un adaptador de formato, no una reimplementación: la lógica y la prosa son idénticas al plugin original. Lo que cambia es el fichero de destino y la traducción de las primitivas específicas de Claude Code. Consulta `PRIMITIVES.md` para el detalle completo.

---

## Requisitos previos

- [Gemini CLI](https://github.com/google-gemini/gemini-cli) instalado y autenticado.
- Node.js 18+ (para el servidor MCP `domain-memory`, si lo usas).
- Un fichero `FLOW.md` en la raíz del repo que quieres trabajar. Parte de la plantilla en:
  `../../plugins/flow/examples/FLOW.template.md`

---

## Instalación

### 1. Copia los comandos

**Instalación global** (disponible en cualquier repo):
```bash
cp -r commands/* ~/.gemini/commands/
```

**Instalación local** (solo para el repo actual):
```bash
mkdir -p .gemini/commands
cp -r commands/* .gemini/commands/
```

Gemini CLI carga comandos de ambas ubicaciones. Los locales tienen precedencia sobre los globales.

Tras la copia, la estructura queda así:
```
~/.gemini/commands/          (o .gemini/commands/ en el repo)
├── feat/
│   ├── start.toml          → /feat:start
│   ├── brainstorm.toml     → /feat:brainstorm
│   ├── design.toml         → /feat:design
│   ├── plan.toml           → /feat:plan
│   ├── build.toml          → /feat:build
│   ├── review.toml         → /feat:review
│   ├── validate.toml       → /feat:validate
│   └── ship.toml           → /feat:ship
├── bug/
│   ├── start.toml          → /bug:start
│   ├── diagnose.toml       → /bug:diagnose
│   ├── investigate.toml    → /bug:investigate
│   ├── fix.toml            → /bug:fix
│   ├── review.toml         → /bug:review
│   ├── validate.toml       → /bug:validate
│   ├── ship.toml           → /bug:ship
│   └── postmortem.toml     → /bug:postmortem
├── work/
│   ├── README.toml         → /work:README
│   ├── resume.toml         → /work:resume
│   ├── status.toml         → /work:status
│   ├── abandon.toml        → /work:abandon
│   └── watch.toml          → /work:watch
└── save-knowledge.toml     → /save-knowledge
```

### 2. Configura el servidor MCP domain-memory

Fusiona el bloque de `settings.snippet.json` en tu `~/.gemini/settings.json`:

```bash
# Si settings.json no existe aún:
cp settings.snippet.json ~/.gemini/settings.json

# Si ya existe, fusiona manualmente el bloque "mcpServers":
# Abre ~/.gemini/settings.json y añade dentro de "mcpServers":
#   "domain-memory": {
#     "command": "npx",
#     "args": ["-y", "@mashware/domain-memory@latest"],
#     "env": { "DOMAIN_MEMORY_DIR": ".domain-memory" }
#   }
```

Si no quieres usar `domain-memory`, puedes omitir este paso. Los comandos comprueban `domain_memory.enabled` en `FLOW.md` y degradan sin avisar si el MCP no está disponible.

### 3. Crea FLOW.md en el repo

Todos los comandos leen `FLOW.md` en la raíz del repo en su paso 0. Sin él, cada comando usa comportamiento por defecto o autodescubre lo que puede.

Copia y rellena la plantilla:
```bash
cp ../../plugins/flow/examples/FLOW.template.md ./FLOW.md
```

Campos clave que rellenar: `tracker`, `git.default_base`, `git.branch_pattern`, `git.request_term`, `git.cli`, `quality.*`, `conventions`, `agents.*`, `domain_memory.enabled`.

---

## Subagentes (opcional pero recomendado para M/L)

Los comandos delegan trabajo en subagentes usando `@nombre`, donde `nombre` viene del mapa `agents.<rol>` de FLOW.md. Para que funcione el fan-out paralelo en `/feat:brainstorm`, `/bug:investigate` y las verificaciones adversariales de los review, declara los subagentes en `.gemini/agents/`:

```
.gemini/agents/
├── architecture.md    # agente de diseño de arquitectura
├── persistence.md     # agente de Doctrine / ORM / DB
├── api.md             # agente de endpoints HTTP
├── testing.md         # agente de tests
├── security.md        # agente de seguridad
├── performance.md     # agente de rendimiento / N+1
└── review.md          # agente de code review del proyecto
```

Consulta `PRIMITIVES.md` para el formato exacto del frontmatter de cada fichero.

Sin subagentes declarados, los comandos ejecutan las tareas secuencialmente en el mismo contexto. El resultado es funcionalmente equivalente para features pequeñas (XS/S).

---

## Vigilancia post-despliegue (`/work:watch`)

`/work:watch` no se autopilota en Gemini CLI (no hay `ScheduleWakeup` en sesión). El comando hace un ciclo de vigilancia y termina. Para repetirlo automáticamente:

```bash
# Ejemplo: vigilar TICKET cada 5 minutos durante 30 minutos
*/5 * * * * gemini -p "/work:watch TICKET 30m" >> ~/.gemini/watch-TICKET.log 2>&1
```

El estado entre ciclos (superficie vigilada, línea base, plan aprobado) se persiste en `.claude/work/TICKET/monitor.md`. Cada ciclo lee ese fichero para no repetir el descubrimiento inicial.

---

## Uso rápido

```
# Arranca una feature
/feat:start PROJ-12345

# Flujo completo para una feature M
/feat:start PROJ-12345
/feat:brainstorm
/feat:design
/feat:plan
/feat:build
/feat:review
/feat:validate
/feat:ship

# Flujo de incidencia S
/bug:start PROJ-99999
/bug:diagnose
/bug:fix
/bug:validate
/bug:review
/bug:ship

# Estado de todos los trabajos abiertos
/work:status

# Retomar trabajo tras un parón
/work:resume
```

---

## Más información

- `PRIMITIVES.md` — tabla de traducción completa y qué se recortó.
- `../../plugins/flow/examples/FLOW.template.md` — plantilla de FLOW.md.
- `../../plugins/flow/commands/work/README.md` — guía completa del sistema de flujos.
