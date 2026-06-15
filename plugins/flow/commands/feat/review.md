---
description: Code review multiagente obligatorio antes de enviar
---

# `/feat:review`

Lee `FLOW.md` en la raíz del repo para las convenciones de este repo (tracker, git, calidad, dominio, observabilidad). Si no existe o una clave está vacía, usa el valor por defecto o autodescubre según indique cada paso. Sobre `domain_memory`: si está activo pero el MCP falla o tarda más de 2 s, continúa sin ese contexto, no bloquees ni se lo notifiques al usuario.

Fase de revisión obligatoria. **No se hace `/feat:ship` sin pasar por aquí y resolver bloqueantes.**

## 1. Pre-flight

- Carga `meta.json`. Exige que `build` esté en `phases_done`. Si no, manda al usuario a `/feat:build` y termina.
- Comprueba que `git diff` tenga cambios reales. Si no hay cambios, avisa y termina.

## 2. Invoca los code reviews

Lanza **ambos** sobre el mismo alcance y **consolida sus hallazgos en un único informe deduplicado**. Alcance: el trabajo completo de la feature frente a la rama base (commiteado + working tree, porque los commits son opt-in y puede haber cambios sin commitear).

1. **Built-in `code-review`** (el de Claude Code, sin prefijo). Pasada única sobre el diff local: fallos de correctitud + reutilización/simplificación/eficiencia, a esfuerzo alto.
2. **Panel de proyecto**: lee `quality.review_skill` de `FLOW.md`.
   - Si `review_skill` tiene valor: invoca ese skill pasándole como contexto adicional el `03-design.md`. Alcance: `git diff <git.default_base>...HEAD`; si hay cambios en working tree sin commitear, asegúrate de que entren.
   - Si `review_skill` está vacío pero `quality.reviewers` tiene entradas: lanza en paralelo cada agente de esa lista como panel, con el mismo contexto y alcance.
   - Si ambos están vacíos: el paso 1 (built-in `code-review`) ya cubre esta pasada; no se lanza nada adicional.

Los dos se solapan en correctitud y simplificación: deduplica esos hallazgos (cuéntalos una vez). Los revisores específicos que aporte `review_skill` (seguridad ofensiva/defensiva, fallos silenciosos, arquitectura) no los repitas en las fases siguientes.

## 3. Refuerzos según área

Solo lo que el skill de §2 **no** cubre ya. Si la feature toca puntos concretos, lanza adicionalmente **en paralelo**:

- DB / consultas pesadas → usa el agente de `agents.performance` de `FLOW.md` sobre los archivos cambiados; si está vacío, salta este refuerzo.
- Workers / colas de mensajes → usa el agente de `agents.queues` de `FLOW.md` para verificar que no haya `flush()` en bucle y que los workers estén registrados con la convención del proyecto (ver `FLOW.md` sección `conventions`); si está vacío, salta este refuerzo.
- Frontend → si hay cambios en código de interfaz, usa el agente de `agents.frontend` de `FLOW.md`; si además hay tests de frontend afectados, usa también `agents.frontend_test`; si alguno está vacío, salta ese refuerzo.

## 3.5. Barrido de completitud (anti-abandono, solo M/L)

Un revisor con un diff grande tiende a **abandonar pronto**: cubre lo evidente de los primeros ficheros, resume el resto como "sin problemas" y declara hecho. Esta pasada lo corrige estructuralmente. **Solo si `meta.json.size` es M o L** (en XS/S el diff cabe de sobra en una pasada y esto no aporta).

Bucle, máximo **2 rondas**:

1. **Worklist**: `git diff --stat <git.default_base>...HEAD` → lista de ficheros/áreas cambiados.
2. **Mapa de cobertura**: de los hallazgos consolidados de §2-§3, marca qué ficheros/áreas recibieron al menos un hallazgo o fueron examinados explícitamente.
3. **Crítico de completitud (1 agente, cegado)**: lánzalo con `Agent general-purpose` (modelo opus — es juicio, no rastreo) pasándole **solo** dos cosas: la lista completa de ficheros del diff (paso 1) y, por cada revisor de §2-§3, una línea de qué cubrió. **No** le pases los hallazgos en detalle ni el diseño — su único trabajo es detectar huecos, no opinar sobre lo ya visto. Prompt:

   > Eres auditor de cobertura de un code review. Te paso (1) la lista de ficheros cambiados en este diff y (2) un resumen de una línea por revisor de qué área cubrió cada uno. Tu única tarea: nombrar los ficheros o áreas del diff que **ningún** revisor llegó a examinar, y cualquier afirmación que un revisor dio por buena sin verificar. No opines sobre los hallazgos existentes. Output: lista de huecos concretos (`fichero/área` + por qué merece una segunda mirada) o exactamente "ninguno". Bajo 150 palabras.

4. **Si nombra huecos frescos**: relanza una ronda dirigida **solo a esos ficheros/áreas** con los revisores del `quality.review_skill` que apliquen (acota sus rutas a los huecos). Fusiona los hallazgos nuevos y deduplícalos contra los ya consolidados.
5. **Repite 2-4** hasta que una ronda devuelva "ninguno" hueco fresco **o** se alcancen las 2 rondas.
6. **Sin truncado silencioso**: si tras 2 rondas el crítico sigue señalando áreas sin cubrir, **anótalas literalmente** en el output bajo "Áreas no cubiertas tras 2 rondas" con su motivo. Mejor declarar el límite que aparentar cobertura total.

Los hallazgos frescos de este barrido entran al flujo normal: pasan por §4 (sobreingeniería), §5 (contratos) y §6 (verificación adversarial) como cualquier otro.

## 4. Auditoría de sobreingeniería (encaje + YAGNI)

**Segunda barrera contra la sobreingeniería** (la primera es el challenger de `/feat:design`). Independiente del code review multiagente: aquí se mira el diff buscando lo que **sobra**, no lo que falta.

1. **Localiza todo mecanismo defensivo en el diff**: validación, guard, reintento, cerrojo, fallback, caché, idempotencia, circuit breaker, cola, flag, reintento.
2. **Para cada uno, busca su fila** en la tabla "Mecanismos defensivos y su justificación" de `03-design.md`.
   - **Si no tiene fila**: bloqueante. Coló sin pasar el filtro del diseño. Pregunta: ¿qué escenario real y presente del proyecto lo justifica?
   - **Si tiene fila pero el escenario es hipotético** ("por si acaso", "podría pasar que…", "en el futuro"): bloqueante tipo "sobra".
3. **Verifica el escenario contra el código, no contra el papel**: ¿el flujo realmente puede llegar a ese estado? ¿hay un upstream que ya lo impide? ¿una cuota/restricción que ya lo acota? ¿el mecanismo es redundante con algo que ya existe? Si `domain_memory.enabled` es `true`, consulta `mcp__domain-memory__search_knowledge` si el escenario depende de reglas de dominio.
4. **Pregunta clave por cada pieza**: *"si quito esto, ¿qué se rompe en el proyecto — hoy, no en un futuro hipotético?"*. Si la respuesta honesta es "nada que pueda pasar de verdad", es un hallazgo de sobreingeniería.

Los hallazgos "sobra" van a Bloqueantes con propuesta concreta: "quitar X — protege contra Y, que no ocurre porque Z (evidencia)".

## 5. Verificación double-blind de contratos

Si `05-implementation.md` tiene sección "Contratos a respetar", lanza un `Agent general-purpose` con un prompt **deliberadamente cegado**: solo recibe dos cosas, nada más, nada menos.

> Eres revisor de contratos. Tienes que decir si el diff cumple unos contratos literales que te paso. **No tienes acceso al resto del diseño, ni al contexto del controller, ni al brief, ni a las explicaciones de implementación.** Solo:
>
> 1. **Contratos a respetar** (copiados verbatim del diseño):
>    <PEGA aquí la sección "Contratos a respetar" de `05-implementation.md` tal cual, sin re-formatear>
>
> 2. **Diff de archivos relevantes**: las construcciones de shape (arrays JSON, JsonSerializable, eventos, headers, rutas, columnas, métricas) de los archivos cambiados:
>    <PEGA aquí solo los hunks del diff que tocan construcción de shape, no el archivo completo>
>
> Tu única tarea: para **cada contrato** del bloque 1, dime si el código del bloque 2 produce **exactamente** esa shape — clave a clave, anidamiento a anidamiento, mismo case, mismo singular/plural. Output: tabla `| Contrato | Coincide (sí/no) | Si no: qué difiere |`. Bajo 200 palabras. No racionalices desajustes ("quizá querían X"): si difiere, dilo.

Por qué cegado: si pasas el código completo o el design completo, el agente racionaliza el desajuste leyendo justificaciones cercanas. Cegándolo a "contrato literal vs lo que el diff emite", la comparación queda en lo textual y no se autocontagia.

Cualquier "no" en la tabla → bloqueante. Pasa al output como hallazgo de contrato roto con la propuesta concreta de ajuste.

Si `05-implementation.md` no tiene "Contratos a respetar" (build registró "N/A"), salta este paso.

## 6. Verificación adversarial de hallazgos (Workflow, opcional M/L)

Los revisores tienden a **sobre-reportar**: un hallazgo "plausible" no siempre es real, y arreglar falsos positivos cuesta tiempo y a veces empeora el código. Si `meta.json.size` es **M o L** y la suma de bloqueantes + sugerencias de §2-§5 es **≥ 4**, ofrece con `AskUserQuestion` filtrarlos ("¿Verificar los hallazgos con un panel de escépticos en paralelo? Descarta falsos positivos antes de que te los lleves a arreglar."). Si acepta, llama a la herramienta `Workflow`:

```js
export const meta = {
  name: 'review-verify',
  description: 'Verifica adversarialmente cada hallazgo del review en paralelo',
  phases: [{ title: 'Verificar' }],
}
const HALLAZGOS = args.hallazgos    // [{id, archivo, descripcion, propuesta}]
const VEREDICTO = {
  type: 'object',
  properties: {
    refutado: { type: 'boolean' },
    motivo: { type: 'string' },
  },
  required: ['refutado', 'motivo'],
}
const verificados = await parallel(HALLAZGOS.map(h => () =>
  parallel([0, 1, 2].map(() => () =>
    agent(
      `Eres un escéptico. Hallazgo de code review en el proyecto:\n` +
      `Archivo: ${h.archivo}\nProblema: ${h.descripcion}\nPropuesta: ${h.propuesta}\n\n` +
      `Intenta REFUTARLO: lee el código real y di si el problema NO es real (refutado=true) o sí lo es (refutado=false). ` +
      `Ante la duda, refuta — la carga de la prueba es del hallazgo. Sé concreto sobre por qué.`,
      { label: `verif:${h.id}`, phase: 'Verificar', schema: VEREDICTO, model: 'sonnet' }
    )))
    .then(votos => {
      const refutan = votos.filter(Boolean).filter(v => v.refutado).length
      return { ...h, sobrevive: refutan < 2, refutan }
    })))
return { confirmados: verificados.filter(h => h.sobrevive), descartados: verificados.filter(h => !h.sobrevive) }
```

Pásale `args: { hallazgos: [...] }` con los hallazgos consolidados (id corto, archivo:línea, descripción, propuesta). Los `descartados` (≥2 escépticos los refutan) salen del listado de bloqueantes/sugerencias — anótalos en el output bajo "Descartados por verificación" con el motivo, para que quede traza de qué se filtró y por qué. Los `confirmados` siguen al output normal. No se ofrece en XS/S ni con menos de 4 hallazgos: el coste no compensa.

## 7. Quality gates locales

Lee `quality.*` de `FLOW.md`. Si están vacíos, autodescubre los comandos equivalentes (Makefile, scripts de npm/composer) y avisa de lo que uses.

Lanza en paralelo (background si tardan):
- `quality.style_fix`
- `quality.static_analysis`
- `quality.test_one` (si hay tests nuevos, con el filtro apropiado)

Recoge los resultados.

## 8. Output

Escribe `.claude/work/<TICKET>/06-review.md`:

```markdown
# Code review <TICKET>

## Resumen
- Agentes lanzados: …
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
<si hay bloqueantes: "resolver y volver a /feat:review">
<si no: "/feat:validate">
```

## 9. Cierre

- Si hay bloqueantes: **no avances `phase`**. Deja `phase = "build"` y el usuario resuelve.
- Si no hay bloqueantes: `phase = "review"`, añade a `phases_done`.
- Resume al usuario los hallazgos y siguiente paso.
