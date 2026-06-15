---
description: Diseña la solución técnica (arquitectura, DB, APIs, riesgos) antes de tocar código
---

# `/feat:design`

Lee `FLOW.md` en la raíz del repo para las convenciones de este repo (tracker, git, calidad, dominio, observabilidad). Si no existe o una clave está vacía, usa el valor por defecto o autodescubre según indique cada paso. Sobre `domain_memory`: si está activo pero el MCP falla o tarda más de 2 s, continúa sin ese contexto, no bloquees ni se lo notifiques al usuario.

Fase de diseño técnico. **Sigue sin escribir código de producción.** El output es un plan que el siguiente paso ejecuta.

## 1. Pre-flight

- Carga `meta.json` por rama actual. Si no existe, pide al usuario que arranque con `/feat:start`.
- Lee `01-context.md` y (si existe) `02-brainstorm.md`.
- Si `size` es `XS`, sugiere saltar a `/feat:build` y termina salvo que el usuario insista.

## 2. Consulta domain-memory enfocada

Si `domain_memory.enabled` es `true` en `FLOW.md`: antes de inventariar el código, llama a `mcp__domain-memory__search_knowledge` con queries orientadas al **módulo afectado** e **integraciones** que va a tocar el diseño. Esto suele descubrir decisiones de dominio invisibles desde el código (restricciones legales, supuestos de la integración, motivos de un acoplamiento histórico).

Lanza 2-4 queries en paralelo. Timeout 2s; si falla, sigue. Hits relevantes van al inicio del diseño bajo "Contexto de dominio adicional" (§4 template). Si `domain_memory.enabled` es `false` o vacío, salta sin avisar.

## 3. Inventario previo (reutilizar antes de crear)

**Antes** de lanzar los subagentes de diseño, identifica qué de lo que la feature necesita **ya existe** en el código o en la base de datos. Esto evita que los arquitectos propongan piezas duplicadas. Lanza un `Agent` con `subagent_type: Explore` con un encargo del tipo:

> Para la feature `<título>` (ver `.claude/work/<TICKET>/01-context.md`), busca en el repo qué piezas relacionadas ya existen y podrían reutilizarse: entidades de dominio, value objects, repositorios, servicios, eventos, columnas o tablas, comandos/queries CQRS, y endpoints similares. No propongas diseño — solo lista lo encontrado con una línea cada uno y su ubicación. Si la feature menciona conceptos como `<concepto1>`, `<concepto2>`, busca específicamente esos.

Guarda el resultado al inicio de `03-design.md` bajo "## Lo que ya existe" (ver §3). Los subagentes de diseño leen esa sección y solo proponen nuevo cuando no encuentran nada equivalente; si proponen duplicar a sabiendas, lo justifican.

## 4. Trabajo

Carga primero los skills relevantes según el proyecto (ver `FLOW.md` sección `conventions`).

Lanza en **paralelo** los subagentes que correspondan según la feature y el tipo de proyecto:

- **Siempre**: agente `agents.architecture` (o `Agent general-purpose` si está vacío) con el encargo de proponer: módulo donde vive, entidades/value objects nuevos o modificados, commands/queries CQRS (si aplica), eventos, repositorios.
- **Si toca DB**: agente `agents.persistence` (o `Agent general-purpose` si está vacío) con el encargo de proponer mappings, migraciones necesarias, índices, y gestor de entidades apropiado.
- **Si toca API/HTTP**: agente `agents.api` (o `Agent general-purpose` si está vacío) con el encargo de definir endpoint, DTO, ruta, seguridad y formato de respuesta (solo planeamiento, no implementación).
- **Si toca rendimiento crítico o hot paths**: agente `agents.performance` (o `Agent general-purpose` si está vacío) para que prevea riesgos N+1 o de carga.
- **Si toca seguridad (autenticación, pagos, datos sensibles)**: agente `agents.security` (o `Agent general-purpose` si está vacío) con el encargo de listar amenazas y mitigaciones del diseño propuesto.

Para cada área, usa el agente definido en `agents.<rol>` de `FLOW.md`; si ese campo está vacío, usa `Agent general-purpose` con el rol en el prompt.

Cada subagente recibe `01-context.md`, `02-brainstorm.md` (si existe) y la sección "Lo que ya existe" en su prompt. Instrucciones explícitas en el encargo:

- **Antes de proponer una entidad/columna/repositorio/servicio nuevo, comprobar si algo del inventario sirve.** Si se duplica a sabiendas, justificar en la tabla de decisiones.
- **No añadir mecanismos defensivos "por si acaso".** Cada validación, guard, reintento, cerrojo, fallback o caché propuesto debe ir acompañado del escenario **real y presente** que lo exige (con evidencia: un finding de `domain-memory`, un archivo, un patrón de tráfico conocido). Si el escenario es hipotético o el sistema actual ya lo impide, **no se propone**. Resolver lo que pide el ticket hoy, no problemas futuros (YAGNI).

## 5. Output

Consolida los outputs en `.claude/work/<TICKET>/03-design.md`:

```markdown
# Diseño <TICKET>

## Contexto de dominio adicional
<hits del search_knowledge enfocado de §2, o "sin hallazgos">

## Lo que ya existe (inventario)
<lista de piezas reutilizables localizadas en §3, o "no hay nada equivalente">

## Resumen ejecutivo
<3-5 bullets de la solución elegida>

## Módulos/capas afectados
- <módulo/capa> — <qué cambia>

## Modelo de datos
- Entidades nuevas / modificadas: <para cada nueva, indica "no se encontró equivalente" o "duplicado a sabiendas porque...">
- Migraciones:
- Índices:

## CQRS / Comandos y Consultas (si aplica)
- Commands:
- Queries:
- Handlers:
- Eventos publicados:

## API / HTTP (si aplica)
- Endpoint:
- DTO:
- Seguridad:

## Riesgos identificados
- Rendimiento:
- Seguridad:
- Compatibilidad:
- Migraciones online:

## Contratos externos
<Si este cambio toca una superficie consumida desde fuera (otro repo, otro módulo, cliente desplegado, worker, migración referenciada por nombre, métrica/dashboard, evento de dominio, ruta HTTP), declara aquí **cada contrato como literal**, no en prosa. Cualquier contrato que quede en prosa es ambiguo y será fuente de fallos en build. Si no hay superficie externa, escribe "ninguno" y pasa de largo.>

### Contrato N: <descripción corta — p.ej. "HTTP 402 quota_exceeded">
- **Tipo**: HTTP response body | header | route | evento de dominio | columna DB | métrica | otro.
- **Shape literal** (formato copiable, no descripción):
  ```json
  {"error":{"code":"quota_exceeded","message":"...","details":{"upgrade_url":"https://..."}}}
  ```
  o
  ```
  Header: X-Tracking-Id: <uuid>
  Route:  POST /api/internal/v1/resource:action
  Evento: ResourceWasCreated { resourceId, createdAt, userHash }
  Métrica: resource.created — tags: [plan, status]
  ```
- **Consumer conocido**: <nombre del consumer + ruta donde lee este contrato, si se sabe>
- **Desviación de patrón**: <si este contrato NO sigue cómo lo hacen otros controllers/eventos/etc. similares del repo, ANUNCIARLO aquí explícitamente: "los otros controllers devuelven X, este NO sigue ese patrón, devuelve Y porque Z">.

### Contrato N+1: …

## Mecanismos defensivos y su justificación
<Una fila por cada validación, guard, reintento, cerrojo, fallback, caché, idempotencia, cola o flag que el diseño introduce. Si no puedes nombrar un escenario REAL y PRESENTE que lo justifique, la pieza sobra — quítala del diseño.>

| Mecanismo | Escenario real que lo justifica (con evidencia) | ¿Necesario ahora? |
|-----------|--------------------------------------------------|-------------------|
| <p.ej. cerrojo en X> | <p.ej. "dos workers consumen la misma cola, ver supervisor config"> | sí |
| <p.ej. reintento en API Y> | <si es "por si acaso" sin escenario → FUERA> | — |

## Plan de implementación (orden)
1. …
2. …

## Tests previstos
- Unit:
- Integration:
- Functional:

## Decisiones (ADR-light)
| Decisión | Alternativa descartada | Por qué |
|----------|------------------------|---------|

## Cuestionamientos del diseño
<lo rellena §5 con la tabla del challenger>
```

## 6. Cuestionamiento del diseño (challenger)

Antes de cerrar, **desafía el diseño** lanzando un `Agent general-purpose` con este encargo (autocontenido):

> Eres el revisor crítico del diseño en `.claude/work/<TICKET>/03-design.md`. **No propongas implementación.** Cuestiona el plan desde 4 ángulos. El **primero es el más importante** y busca lo contrario que los demás — busca lo que SOBRA.
>
> 1. **Encaje y necesidad (ángulo dominante — busca lo que sobra)**: revisa cada mecanismo defensivo del diseño (validación, guard, reintento, cerrojo, fallback, caché, idempotencia, cola, flag). Para cada uno pregunta:
>    - **¿Puede ese escenario ocurrir realmente en este proyecto?** No lo asumas — verifícalo: consulta `mcp__domain-memory__search_knowledge` y mira el código relevante. Si el sistema ya impide ese escenario (un upstream valida antes, una restricción lo bloquea, el flujo no permite ese estado, la integración externa ya lo garantiza), la protección **sobra** → hallazgo "esto sobra".
>    - **¿Se necesita ahora, para lo que pide el ticket (YAGNI)?** Si resuelve un problema futuro hipotético en vez del de hoy → hallazgo "esto sobra, es YAGNI".
>    - Sé concreto en el porqué: "X sobra porque en este proyecto Y siempre ocurre antes, ver `<archivo>`/`<finding domain-memory>`".
> 2. **Supuestos frágiles** (busca lo que falta): ¿qué creencias del diseño podrían no cumplirse? ¿cuál es, cómo podría fallar, qué pasaría? **Pero antes de marcarlo, confirma que el fallo es posible en el proyecto** — no inventes fragilidades teóricas.
> 3. **Simplificación**: ¿hay forma más simple de lograr lo mismo? ¿alguna pieza es redundante con "Lo que ya existe"?
> 4. **Operación en producción**: rollback, observabilidad, migraciones online, efectos cruzados con workers/cachés/colas. Solo lo que aplique de verdad a este cambio.
>
> Lee `01-context.md` para el objetivo de negocio. Output: tabla markdown `| Ángulo | Hallazgo | Tipo (sobra/falta) | Severidad |` con severidades `alta`/`media`/`baja`. Bajo 500 palabras. No inventes problemas para llenar — si un ángulo no tiene hallazgos, di "sin hallazgos". Es perfectamente válido (y deseable) que el resultado diga "el diseño está ajustado, nada sobra ni falta".

Si la feature toca **dominio sensible** (pagos, autenticación, datos personales, contadores de uso/seguimiento), lanza **en paralelo** un segundo `Agent general-purpose` con foco específico en el dominio:

> Cuestiona el diseño desde el ángulo de <dominio>: ¿qué casos de abuso son posibles? ¿qué garantías de consistencia se necesitan que el diseño actual no da? ¿qué decisiones pueden tener consecuencias regulatorias o de soporte? Mismo formato de tabla.

Consolida los hallazgos al final de `03-design.md` bajo:

```markdown
## Cuestionamientos del diseño

| Ángulo | Hallazgo | Tipo | Severidad | Respuesta |
|--------|----------|------|-----------|-----------|
| Encaje/necesidad | … | sobra | alta | <vacío al principio — el usuario lo rellena> |
| Supuesto | … | falta | media | … |
| Operación | … | falta | baja | … |
```

**Si hay severidad `alta` sin respuesta**: muestra los hallazgos al usuario y pregunta con `AskUserQuestion`. Las opciones dependen del tipo:

- Si el hallazgo es **"sobra"** (encaje/YAGNI): **Recortar** (quita la pieza del diseño — opción por defecto), o **Mantener y justificar** (rellena "Respuesta" con el escenario real que lo exige — si no puedes nombrarlo, es que sobra).
- Si el hallazgo es **"falta"** (supuesto/operación): **Reabrir brainstorm/design** para incorporarlo, o **Asumir y documentar** (rellena "Respuesta" con la asunción consciente — `"Asumimos X porque Y"`).

No avances al cierre con severidades altas sin respuesta. Las medias y bajas son informativas — quedan registradas para que el code review las tenga a la vista. **Un challenger que devuelve "nada sobra ni falta, el diseño está ajustado" es un buen resultado, no un fallo** — no fuerces hallazgos.

## 7. ¿El tamaño sigue siendo correcto?

El diseño es el momento en que la complejidad real del trabajo se hace visible (migraciones, módulos cruzados, integraciones). Si lo que sale en `03-design.md` no encaja con `meta.json.size`:

- Propón al usuario reclasificar (`AskUserQuestion`).
- Si confirma, actualiza `meta.json.size` y anota en `meta.json.notes`.
- **Consecuencias**: pasar de M a L activa el flujo completo. Pasar de M a S elimina `/feat:plan` de la ruta. Avisa explícitamente del cambio de flujo al usuario.

## 8. Staging de hallazgos de dominio

Si `domain_memory.enabled` es `true` en `FLOW.md`: revisa la tabla de decisiones (ADR-light) y los cuestionamientos para detectar **decisiones de dominio no obvias** — cosas que un futuro lector del repo no podría deducir leyendo solo el código. Ejemplos típicos:

- "Decidimos no usar X porque la integración externa garantiza Y solo bajo Z."
- "Acoplamos A con B porque legal/fiscal exige que..."
- "El handler es no-idempotente a propósito porque el dominio lo permite y simplifica el flujo."

**Silencio por defecto**: si no hay nada no obvio, no preguntes. Si hay 1+ hallazgos con señal clara:

- Llama a `mcp__domain-memory__stage_finding` con el hallazgo y el contexto. Una llamada por hallazgo.
- Avisa al usuario brevemente: "Stageado X hallazgo(s) de dominio para consolidar en `/feat:ship`".

No invoques `save_knowledge` aquí — el save final está en `/feat:ship` con `read_staging` previo. Si `domain_memory.enabled` es `false` o vacío, salta sin avisar.

## 9. Cierre

- Actualiza `meta.json`: `phase = "design"`, añade a `phases_done`.
- Pide al usuario que revise el diseño. Si pide cambios, edítalos en el artefacto antes de avanzar.
- Siguiente paso según tamaño:
  - **XS / S**: sugiere `/feat:build` (1 sola MR/PR, no hay que planificar troceo).
  - **M / L**: sugiere `/feat:plan` para decidir cómo trocear el trabajo en MRs/PRs mergeables de forma independiente antes de implementar.
