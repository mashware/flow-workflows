# Adaptador de flujos `flow` para Codex CLI

Lleva los flujos `/feat-*`, `/bug-*` y `/work-*` del plugin `flow` al formato de **Codex CLI** (OpenAI).

## Contenido del adaptador

```
adapters/codex/
├── prompts/              — 22 prompts personalizados (uno por comando del flujo)
│   ├── feat-start.md
│   ├── feat-brainstorm.md
│   ├── feat-design.md
│   ├── feat-plan.md
│   ├── feat-build.md
│   ├── feat-review.md
│   ├── feat-validate.md
│   ├── feat-ship.md
│   ├── bug-start.md
│   ├── bug-diagnose.md
│   ├── bug-investigate.md
│   ├── bug-fix.md
│   ├── bug-validate.md
│   ├── bug-review.md
│   ├── bug-postmortem.md
│   ├── bug-ship.md
│   ├── work-README.md
│   ├── work-resume.md
│   ├── work-status.md
│   ├── work-abandon.md
│   ├── work-watch.md
│   └── save-knowledge.md
├── config.snippet.toml   — secciones para fusionar en ~/.codex/config.toml
├── AGENTS.md             — guía de repo que Codex lee como contexto
├── PRIMITIVES.md         — tabla de traducción de primitivas + recortes
└── README.md             — este fichero
```

## Instalación

### 1. Prompts personalizados

> **Aviso sobre la ruta de prompts**: la ruta exacta donde Codex CLI busca los prompts personalizados **puede variar según la versión de Codex**. La ruta habitual en versiones recientes es `~/.codex/prompts/`, pero confírmala con `/help` dentro de Codex o consultando la documentación de tu versión antes de copiar.
>
> **Alternativa con skills**: si tu versión de Codex admite skills en `.agents/skills/` del repo (formato `$nombre`), copia los ficheros de `prompts/` a `.agents/skills/<nombre>/SKILL.md` dentro del repositorio. Los flujos funcionarán igual, invocados como `$feat-start`, `$bug-fix`, etc.

Copia los ficheros de `prompts/` a la ruta de prompts de Codex:

```bash
# Ruta habitual (confirma con /help o la doc de tu versión):
cp prompts/*.md ~/.codex/prompts/

# Si la ruta es distinta, sustitúyela:
cp prompts/*.md /ruta/que-indique-tu-version/de/codex/prompts/
```

Los prompts se invocan con `/feat-start {TICKET}`, `/bug-diagnose`, `/work-status`, etc.

### 2. Configuración de MCP y subagentes

Fusiona el contenido de `config.snippet.toml` en tu `~/.codex/config.toml` existente:

```bash
# Lee config.snippet.toml y copia las secciones que necesites a mano en tu config.toml
cat config.snippet.toml
```

Ajusta los valores de `command` y `args` de `[mcp_servers.domain-memory]` con la instalación real de domain-memory en tu máquina.

Para los subagentes, define en `~/.codex/config.toml` las secciones `[agents.<nombre>]` que necesites, usando los nombres que pongas en el mapa `agents.*` de `FLOW.md`.

### 3. FLOW.md en el repo

Cada repo que use estos flujos necesita un `FLOW.md` en su raíz. Sin él, los flujos funcionan con valores por defecto (autodescubrimiento), pero se recomienda tenerlo para convenciones específicas del proyecto.

Puedes partir de la plantilla:

```bash
cp ../../plugins/flow/examples/FLOW.template.md FLOW.md
# Edita FLOW.md con las convenciones de tu proyecto
```

### 4. AGENTS.md en el repo (opcional)

Copia o enlaza `AGENTS.md` a la raíz del repo para que Codex lo lea como guía de contexto:

```bash
cp /ruta/a/adapters/codex/AGENTS.md /raiz/de/tu/repo/AGENTS.md
```

## Uso rápido

```
# Arrancar una feature
/feat-start PROJ-12345

# Continuar donde lo dejaste
/work-resume

# Ver todos los trabajos abiertos
/work-status

# Arrancar una incidencia
/bug-start PROJ-99999

# Vigilar tras un despliegue (un ciclo; configura cron para repetirlo)
/work-watch PROJ-12345 30m
```

## Dependencias

- **Codex CLI** instalado y configurado con tu API key de OpenAI.
- **domain-memory MCP** instalado si quieres usar `domain_memory.enabled: true` en FLOW.md. Proyecto: https://github.com/mashware/domain-memory
- **CLI de git** configurado (`glab`, `gh`, u otro según `git.cli` en FLOW.md) para crear MRs/PRs desde terminal.

## Diferencias respecto al plugin original (Claude Code)

Ver `PRIMITIVES.md` para la tabla completa. Los puntos más importantes:

- **AskUserQuestion**: no hay UI estructurada → preguntas en texto normal.
- **ScheduleWakeup** (autopilot de watch): no existe en Codex → `/work-watch` ejecuta un ciclo y termina; usa cron del SO o las Automations de la app de Codex para repetirlo.
- **Workflow DSL**: la orquestación paralela se expresa en instrucciones de lenguaje natural al agente.
