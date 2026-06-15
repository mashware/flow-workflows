# `/feat-review`

Lee `FLOW.md` en la raíz del repo para las convenciones de este repo (tracker, git, calidad, dominio, observabilidad). Si no existe o una clave está vacía, usa el valor por defecto o autodescubre según indique cada paso. Sobre `domain_memory`: si está activo pero el MCP falla o tarda más de 2 s, continúa sin ese contexto, no bloquees ni se lo notifiques al usuario.

Fase de revisión obligatoria. **No se hace `/feat-ship` sin pasar por aquí y resolver bloqueantes.**

## 1. Pre-flight

- Carga `meta.json`. Exige que `build` esté en `phases_done`. Si no, manda al usuario a `/feat-build` y termina.
- Comprueba que `git diff` tenga cambios reales. Si no hay cambios, avisa y termina.

## 2. Invoca los code reviews

Lanza **ambos** sobre el mismo alcance y **consolida sus hallazgos en un único informe deduplicado**. Alcance: el trabajo completo de la feature frente a la rama base (commiteado + árbol de trabajo, porque los commits son opt-in y puede haber cambios sin commitear).

1. **Revisión de correctitud**: una pasada sobre el diff local: fallos de correctitud + reutilización/simplificación/eficiencia, a esfuerzo alto. Si Codex tiene una herramienta de revisión de código configurada, úsala; si no, realiza la revisión directamente.
2. **Panel de proyecto**: lee `quality.review_skill` de `FLOW.md`.
   - Si `review_skill` tiene valor: invócalo pasándole como contexto adicional el `03-design.md`. Alcance: `git diff <git.default_base>...HEAD`; si hay cambios sin commitear, asegúrate de que entren.
   - Si `review_skill` está vacío pero `quality.reviewers` tiene entradas: lanza en paralelo cada subagente de esa lista como panel, con el mismo contexto y alcance.
   - Si ambos están vacíos: el paso 1 ya cubre esta pasada; no se lanza nada adicional.

Los dos se solapan en correctitud y simplificación: deduplica esos hallazgos (cuéntalos una vez).

## 3. Refuerzos según área

Solo lo que el skill de §2 **no** cubre ya. Si la feature toca puntos concretos, lanza adicionalmente **en paralelo**:

- DB / consultas pesadas → usa el agente de `agents.performance` de `FLOW.md` sobre los archivos cambiados; si está vacío, salta este refuerzo.
- Workers / colas de mensajes → usa el agente de `agents.queues` de `FLOW.md` para verificar que no haya `flush()` en bucle y que los workers estén registrados con la convención del proyecto; si está vacío, salta este refuerzo.
- Frontend → si hay cambios en código de interfaz, usa el agente de `agents.frontend` de `FLOW.md`; si además hay tests de frontend afectados, usa también `agents.frontend_test`; si alguno está vacío, salta ese refuerzo.

## 3.5. Barrido de completitud (solo M/L)

Un revisor con un diff grande tiende a abandonar pronto. **Solo si `meta.json.size` es M o L**:

Bucle, máximo **2 rondas**:
1. **Lista de archivos**: `git diff --stat <git.default_base>...HEAD` → lista de archivos/áreas cambiados.
2. **Mapa de cobertura**: de los hallazgos consolidados de §2-§3, marca qué archivos/áreas recibieron al menos un hallazgo o fueron examinados explícitamente.
3. **Auditor de completitud** (subagente general, con solo dos cosas: la lista completa de archivos del diff y, por cada revisor de §2-§3, una línea de qué cubrió):

   > Eres auditor de cobertura de un code review. Te paso (1) la lista de archivos cambiados en este diff y (2) un resumen de una línea por revisor de qué área cubrió cada uno. Tu única tarea: nombrar los archivos o áreas del diff que **ningún** revisor llegó a examinar, y cualquier afirmación que un revisor dio por buena sin verificar. No opines sobre los hallazgos existentes. Output: lista de huecos concretos (`archivo/área` + por qué merece una segunda mirada) o exactamente "ninguno". Bajo 150 palabras.

4. **Si nombra huecos frescos**: relanza una ronda dirigida **solo a esos archivos/áreas**.
5. **Repite 2-4** hasta que una ronda devuelva "ninguno" o se alcancen las 2 rondas.
6. **Sin truncado silencioso**: si tras 2 rondas el auditor sigue señalando áreas sin cubrir, anótalas en el output bajo "Áreas no cubiertas tras 2 rondas".

## 4. Auditoría de sobreingeniería (encaje + YAGNI)

**Segunda barrera contra la sobreingeniería**. Busca lo que **sobra** en el diff:

1. **Localiza todo mecanismo defensivo en el diff**: validación, guard, reintento, cerrojo, mecanismo de respaldo, caché, idempotencia, circuito, cola, indicador, reintento.
2. **Para cada uno, busca su fila** en la tabla "Mecanismos defensivos y su justificación" de `03-design.md`.
   - **Si no tiene fila**: bloqueante. Coló sin pasar el filtro del diseño.
   - **Si tiene fila pero el escenario es hipotético**: bloqueante tipo "sobra".
3. **Verifica el escenario contra el código**: ¿el flujo realmente puede llegar a ese estado? Si `domain_memory.enabled` es `true`, consulta `mcp__domain-memory__search_knowledge` si el escenario depende de reglas de dominio.
4. **Pregunta clave**: *"si quito esto, ¿qué se rompe en el proyecto — hoy, no en un futuro hipotético?"*. Si la respuesta honesta es "nada que pueda pasar de verdad", es un hallazgo de sobreingeniería.

Los hallazgos "sobra" van a Bloqueantes con propuesta concreta.

## 5. Verificación double-blind de contratos

Si `05-implementation.md` tiene sección "Contratos a respetar", lanza un subagente general con un prompt **deliberadamente cegado** — solo recibe dos cosas:

> Eres revisor de contratos. Tienes que decir si el diff cumple unos contratos literales que te paso. **No tienes acceso al resto del diseño, ni al contexto del controller, ni al brief, ni a las explicaciones de implementación.** Solo:
>
> 1. **Contratos a respetar** (copiados verbatim del diseño):
>    <PEGA aquí la sección "Contratos a respetar" de `05-implementation.md` tal cual, sin re-formatear>
>
> 2. **Diff de archivos relevantes**: las construcciones de shape (arrays JSON, serialización, eventos, headers, rutas, columnas, métricas) de los archivos cambiados:
>    <PEGA aquí solo los hunks del diff que tocan construcción de shape>
>
> Tu única tarea: para **cada contrato** del bloque 1, dime si el código del bloque 2 produce **exactamente** esa shape — clave a clave, anidamiento a anidamiento, mismo case, mismo singular/plural. Output: tabla `| Contrato | Coincide (sí/no) | Si no: qué difiere |`. Bajo 200 palabras. No racionalices desajustes: si difiere, dilo.

Cualquier "no" en la tabla → bloqueante.

Si `05-implementation.md` no tiene "Contratos a respetar" (build registró "N/A"), salta este paso.

## 6. Verificación adversarial de hallazgos (opcional M/L)

Si `meta.json.size` es **M o L** y la suma de bloqueantes + sugerencias de §2-§5 es **≥ 4**, ofrece al usuario filtrarlos con un panel de escépticos en paralelo. Si acepta, lanza subagentes en paralelo sobre cada hallazgo (3 escépticos por hallazgo, con instrucción de refutar-por-defecto): un hallazgo sobrevive si menos de 2 escépticos lo refutan. Los descartados (≥2 los refutan) se anotan en el output bajo "Descartados por verificación" con el motivo.

No se ofrece en XS/S ni con menos de 4 hallazgos: el coste no compensa.

## 7. Quality gates locales

Lee `quality.*` de `FLOW.md`. Si están vacíos, autodescubre los comandos equivalentes y avisa de lo que uses.

Lanza en paralelo (en segundo plano si tardan):
- `quality.style_fix`
- `quality.static_analysis`
- `quality.test_one` (si hay tests nuevos, con el filtro apropiado)

## 8. Output

Escribe `.claude/work/<TICKET>/06-review.md`:

```markdown
# Code review <TICKET>

## Resumen
- Revisores lanzados: …
- Rondas de completitud (M/L): N
- Hallazgos críticos (bloquean ship): N
- Hallazgos sugerencia: M

## Áreas no cubiertas tras 2 rondas
<solo si §3.5 quedó con huecos al agotar el tope; lista literal con su motivo, o "ninguna">

## Verificación double-blind de contratos
- Contratos comparados: N
- Desajustes: <lista o "ninguno">

## Sobreingeniería (encaje + YAGNI)
- Mecanismos defensivos en el diff: <lista>
- Sin justificación en `03-design.md` o con escenario hipotético: <lista, o "ninguno">
- Propuesta de recorte: <qué quitar y por qué, o "nada que recortar">

## Descartados por verificación adversarial
<solo si se corrió §6; lista de hallazgos refutados con su motivo, o "no aplica">

## Bloqueantes (must-fix)
1. [archivo:línea] descripción + propuesta concreta

## Sugerencias (nice-to-have)
1. [archivo:línea] descripción

## Quality gates
- style_fix: ✅ / ❌
- static_analysis: ✅ / ❌
- tests modificados: ✅ / ❌

## Próximo paso
<si hay bloqueantes: "resolver y volver a /feat-review">
<si no: "/feat-validate">
```

## 9. Cierre

- Si hay bloqueantes: **no avances `phase`**. Deja `phase = "build"` y el usuario resuelve.
- Si no hay bloqueantes: `phase = "review"`, añade a `phases_done`.
- Resume al usuario los hallazgos y siguiente paso.
