---
description: Guía del sistema de flujos /feat-* y /bug-*
---

# Sistema de flujos `/feat-*` y `/bug-*`

Este sistema **orquesta** los subagentes y skills que ya existen en el proyecto (no los reemplaza). Su trabajo es persistir contexto entre fases, evitar que cada paso empiece de cero, y forzar un final con code review.

## Configuración por repo: `FLOW.md`

Coloca un fichero `FLOW.md` en la raíz del repo para adaptar el plugin a tus convenciones. Define el tracker de tickets, las convenciones de rama y MR/PR, los comandos de calidad, las convenciones de código, el MCP de domain-memory y el perfil de observabilidad. Todos los comandos leen este fichero en su paso 0.

Puedes partir de la plantilla en `flow/examples/FLOW.template.md`.

Si el fichero no existe o una clave está vacía, cada comando autodescubre el valor o usa el comportamiento por defecto descrito en su sección correspondiente.

## Principios

- **Una carpeta por ticket**: `.claude/work/{TICKET}/` contiene `meta.json` y los artefactos en markdown.
- **Artefactos numerados**: cada fase escribe un `NN-fase.md` que el siguiente paso lee.
- **`meta.json` es la fuente de verdad** del estado (fase actual, tamaño, rama). Sin él, los comandos se niegan a continuar.
- **Tamaño manda**: en `/feat-start` y `/bug-start` se clasifica XS/S/M/L y se sugiere saltar fases en cambios pequeños.
- **Rama con base explícita y sin upstream a la base**: crear una rama ya provocó un despliegue accidental, así que `/feat-start` §5 y `/bug-start` §4 imponen dos reglas. (1) **Base explícita**: nunca `git checkout -b` desde "donde estoy" — la base es `git.default_base` de FLOW.md (caso normal) o una rama padre confirmada (modo tren, anotado en `meta.json.stacked_on`). Si la rama actual no es la base, se pregunta la base antes de crear. (2) **`--no-track` obligatorio**: con `branch.autoSetupMerge=true`, crear desde la base sin `--no-track` deja el upstream en la base remota; un envío que resuelva el upstream acaba en la base y puede desplegar. El primer envío es siempre `git push -u origin HEAD` (rama propia), y `/feat-ship` §4.0 / `/bug-ship` §3.0 bloquean si HEAD es la rama base o el upstream apunta a ella.
- **MR/PRs pequeñas, con sentido y poco acopladas**: el objetivo por defecto es cerrar la feature en MR/PRs lo más pequeñas posible, cada una con un propósito claro, fusionables de forma independiente cuando se pueda. Acoplamiento entre MR/PRs solo cuando sea inevitable; entonces hay que justificarlo en `04-mr-plan.md` y dejar el orden de fusión anotado. Una MR/PR enorme "porque no se puede partir" es señal de que `/feat-plan` no se ha pensado bien — vuelve a esa fase antes de seguir.
- **Entender antes de empezar**: si tras leer el ticket, `domain-memory` y el código quedan dudas que afectan al diseño (qué casos cubre, qué pasa con ciertos roles/planes, qué hace si el usuario X, qué métrica/evento se considera "éxito"), **se pregunta al usuario** antes de cerrar `/feat-start` o `/feat-brainstorm`. Inventar respuestas que el usuario tendría que rectificar luego es peor que la pregunta. Se pregunta de golpe, no goteando.
- **Reutilizar antes de crear**: en `/feat-design`, antes de proponer entidades, columnas, repositorios, servicios o eventos nuevos, hay que verificar si ya existe algo equivalente en el módulo afectado o en módulos vecinos. Cada pieza nueva en `03-design.md` debe llevar implícito "no encontré nada que sirva". Si se duplica a sabiendas, hay que justificarlo.
- **Resolver el problema real del proyecto, no el genérico (encaje + YAGNI)**: antes de añadir cualquier mecanismo defensivo (validación, guard, reintento, cerrojo, alternativa de respaldo, caché, idempotencia, cola, indicador), hay que responder **dos preguntas con evidencia**:
  - **(a) ¿Encaja? ¿Este escenario puede ocurrir realmente dado cómo funciona este proyecto?** La evidencia sale de `domain-memory` y del código, **no** de patrones genéricos de libro ni de "podría pasar que…". Si el sistema actual ya impide ese escenario, la protección **sobra**.
  - **(b) ¿Lo necesitamos ahora, para lo que pide el ticket?** Si resuelve un problema futuro hipotético en vez del de hoy, **no se añade** (YAGNI). Lo futuro se anota como "idea para ticket aparte", no se construye.

  El sesgo por defecto del diseño es **quitar, no añadir**.
- **El tamaño es revisable**: la clasificación XS/S/M/L se hace en `/feat-start` o `/bug-start` con info parcial. Cualquier fase posterior que vea desajuste claro debe **proponer al usuario reclasificar** antes de avanzar, y actualizar `meta.json.size`.
- **Si la implementación invalida el diseño, vuelve a design**: durante `/feat-build` es normal descubrir cosas. Si las desviaciones acumuladas en `05-implementation.md` son 2+ significativas, o una que cambia una decisión del ADR-light del diseño, **pausa la construcción y vuelve a `/feat-design`** para actualizar el documento antes de seguir.
- **El diseño/investigación se desafía antes de ejecutar**: al final de `/feat-design` y `/bug-investigate` se lanza un *challenger* (un subagente de propósito general con prompt afilado). Su **primer y dominante** ángulo es **"Encaje y necesidad"** — busca lo que **sobra**. Los otros ángulos (supuestos frágiles, simplificación, operación en producción) buscan lo que falta. El resultado se anota en el propio artefacto bajo "Cuestionamientos". Hallazgos de severidad **alta** sin respuesta bloquean el avance; el usuario decide si reabrir, recortar, o asumir y documentar.
- **Brief de negocio antes de teclear código**: justo antes de empezar a editar archivos (en `/feat-build` y `/bug-fix`), redactar 3-5 bullets **en lenguaje de negocio** (no técnico) explicando qué va a poder hacer el usuario/sistema tras esta tarea, y qué **NO** está incluido. Pedir confirmación antes del primer commit.
- **El MR/PR comunica funcionalidad, no implementación**: el título y la descripción del MR/PR (en `/feat-ship` y `/bug-ship`) parten del **Brief** del artefacto correspondiente, no del diseño técnico. Los detalles técnicos van en una sección colapsada al final.
- **Previsualización del MR/PR obligatoria antes de crear**: en `/feat-ship` y `/bug-ship`, antes de invocar la creación, se imprime al usuario el bloque completo y se pide confirmación. **Sin excepciones, ni siquiera cuando el contenido parece evidente.**
- **Anclaje a contratos del diseño**: (1) `/feat-design` §"Contratos externos": superficies externas como shape literal. (2) `/feat-build` §2.0bis: copia verbatim antes de teclear. (3) `/feat-review` §5: subagente deliberadamente sesgado que solo compara shape.
- **Los commits son opt-in del usuario**: durante `/feat-build` y `/bug-fix`, el agente **no hace `git commit` por su cuenta**. Tras cada paso, edita los archivos y reporta resumen. Espera a que el usuario decida.
- **Code review obligatorio**: no se hace `/feat-ship` ni se cierra `/bug-postmortem` sin pasar por el comando de revisión correspondiente.
- **Subagentes ya existentes**: los comandos invocan a los subagentes y skills disponibles en el proyecto para diseño, construcción de API, testing, análisis de rendimiento, etc. No se duplica trabajo — se delega en lo que ya existe.
- **Fan-out multiagente paralelo (opcional, solo donde paga)**: tres fases ofrecen lanzar subagentes en paralelo, **condicionado a `size` M/L + confirmación del usuario** — nunca forzado, nunca en XS/S. (1) `/feat-brainstorm` §3.A: panel de enfoques. (2) `/bug-investigate` §3.A: barrido de hipótesis. (3) `/feat-review` §6 y `/bug-review` §5: verificación adversarial de hallazgos.
- **`domain-memory` (ciclo completo)**: si `domain_memory.enabled` es `true` en FLOW.md, el MCP `domain-memory` se usa en cuatro momentos a lo largo del flujo. Si en algún punto el MCP no responde en 2s o falla, sigue sin contexto y no lo menciones al usuario. Si `enabled` es `false` o está ausente, salta todos los pasos de domain-memory sin avisar.
  - **`search_knowledge`** al entrar en territorio nuevo: `/feat-start` y `/bug-start` (palabras clave del ticket), `/feat-brainstorm` (concepto/patrón), `/feat-design` (módulo + integraciones), `/bug-diagnose` (componente afectado), `/bug-investigate` (causa hipotética).
  - **`stage_finding`** durante el proceso: al cerrar `/feat-design` y `/bug-investigate`, si emergieron decisiones de dominio no obvias, proponer al usuario stagearlas. Silencio por defecto.
  - **`read_staging`** antes del guardado: `/feat-ship` y `/bug-postmortem` leen lo acumulado en staging para esa rama antes de proponer el guardado final.
  - **`save_knowledge`** al cerrar: `/feat-ship` y `/bug-postmortem` ofrecen consolidar. Solo se guarda el "por qué" (decisiones, restricciones, motivaciones); el "qué" (código, rutas) vive en el repo.

## Esquema de `meta.json`

```json
{
  "ticket": "{PREFIX}XXXXX",
  "type": "feat" | "bug",
  "title": "Texto del tracker o descripción corta",
  "branch": "{PREFIX}XXXXX-slug",
  "size": "XS" | "S" | "M" | "L",
  "phase": "context" | "brainstorm" | "design" | "plan" | "build" | "review" | "validate" | "ship" | "diagnose" | "investigate" | "fix" | "postmortem" | "done" | "abandoned",
  "phases_done": ["context", ...],
  "mrs": [
    {
      "n": 1,
      "title": "…",
      "size": "S",
      "status": "pending" | "in_progress" | "merged" | "closed" | "superseded",
      "lines_est": 120,
      "files_est": 6,
      "url": "https://...",
      "note": "motivo si closed/superseded; vacío en el resto"
    }
  ],
  "started_at": "2026-05-11T10:00:00Z",
  "updated_at": "2026-05-11T11:30:00Z",
  "notes": "campo libre que el usuario puede editar"
}
```

## Atajos por tamaño

| Tamaño | Features                                                                  | Bugs                                                            |
|--------|---------------------------------------------------------------------------|-----------------------------------------------------------------|
| XS     | start → build → review → ship                                             | start → fix → review → ship                                     |
| S      | start → design (resumido) → build → review → validate → ship              | start → diagnose → fix → review → validate → ship               |
| M      | start → brainstorm → design → **plan** → build → review → validate → ship | flujo completo                                                  |
| L      | flujo completo (incluye **plan**)                                         | flujo completo                                                  |

`/feat-plan` se salta en XS/S (siempre es 1 MR/PR). En M/L es obligatorio y registra el array `mrs` en `meta.json`.

## Flujo `/feat-*` completo

`/feat-start {TICKET}` → `/feat-brainstorm` → `/feat-design` → `/feat-plan` → `/feat-build` → `/feat-review` → `/feat-validate` → `/feat-ship`

Para M/L con varios MR/PRs, el bloque `build → review → validate → ship` se repite por cada MR/PR del plan. El array `meta.json.mrs` lleva el estado.

## Flujo `/bug-*` completo

`/bug-start {TICKET}` → `/bug-diagnose` → `/bug-investigate` → `/bug-fix` → `/bug-validate` → `/bug-review` → `/bug-postmortem` → `/bug-ship`

## Comandos transversales

- `/work-status` — muestra todos los trabajos en `.claude/work/`, fase actual y divergencia con git.
- `/work-resume` — detecta la rama actual, abre `meta.json`, recapitula y sugiere siguiente paso.
- `/work-watch {TICKET} [30m]` — vigilancia post-despliegue: observa la plataforma de observabilidad (según FLOW.md `observability`) acotado al cambio. Hace un ciclo, guarda el estado en `monitor.md` y termina. Para vigilancia continua, configura un cron del SO con `opencode run -p "/work-watch {TICKET}"` cada 5 minutos.

## Reglas de oro

1. **Nunca saltes `review`.** Si la fase anterior no está en `phases_done`, el comando se niega.
2. **Si editas código fuera del flujo**, `/work-status` te avisa de la divergencia.
3. **Los artefactos son editables a mano**. Si reescribes `03-design.md`, el siguiente paso lo respetará.
4. **`domain-memory` es opcional pero recomendado** al cerrar features grandes o postmortems (requiere `domain_memory.enabled: true` en FLOW.md).
