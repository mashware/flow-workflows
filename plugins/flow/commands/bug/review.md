---
description: Code review multiagente del arreglo antes de enviar
---

# `/flow:bug:review`

Code review obligatorio del arreglo.

## 1. Pre-flight

Lee `FLOW.md` en la raíz del repo para las convenciones de este repo (tracker, git, calidad, dominio, observabilidad). Si no existe o una clave está vacía, usa el valor por defecto o autodescubre según indique cada paso. Sobre `domain_memory`: si está activo pero el MCP falla o tarda más de 2 s, continúa sin ese contexto, no bloquees ni se lo notifiques al usuario.

- Carga `meta.json`. Exige `fix` en `phases_done`. Para `size` ≥ S exige también `validate`.
- Si `git diff` no muestra cambios, avisa y termina.

## 2. Invoca los dos code reviews

Lanza **ambos** sobre el alcance del arreglo frente a la base (commiteado + árbol de trabajo sin commitear) y **consolida sus hallazgos en un único informe deduplicado**:

1. **Built-in `code-review`** (el de Claude Code, sin prefijo). Pasada única sobre el diff local: fallos de correctitud + simplificación/eficiencia, a esfuerzo alto.
2. **Skill `quality.review_skill` de FLOW.md**: invócalo como `<review_skill> branch`. Si `quality.review_skill` está vacío y `quality.reviewers` tiene entradas, lanza esos agentes en paralelo como panel de revisión. Si ambos están vacíos, usa el built-in `code-review` (ya lanzado en el punto anterior).

Deduplica los solapamientos (correctitud/simplificación los señalan ambos; cuéntalos una vez). Foco específico del arreglo además del análisis genérico:
- El cambio debe resolver realmente el problema de `02-diagnose.md` / `03-investigation.md`.
- No debe haber alcance ampliado (refactor encubierto). Si lo hay, listar.
- El test de regresión de `05-validation.md` debe cubrir el caso.

Pasa como contexto: `03-investigation.md` y `04-fix.md`.

## 3. Refuerzos según área

Solo lo que el skill de §2 no cubre ya. Lanza adicionalmente en paralelo si aplica:

- BD / consultas → agente de `agents.performance` de FLOW.md; si está vacío, usa `Agent general-purpose` con rol de rendimiento en el prompt.
- Workers / cola de fallos → agente de `agents.queues` de FLOW.md para confirmar que el arreglo evita reincidencia; si está vacío, usa `Agent general-purpose` con rol de mensajería en el prompt.

## 4. Auditoría de sobreingeniería (encaje + YAGNI)

Un arreglo también puede colar defensas de más ("ya que arreglo esto, meto un retry/guard/fallback por si acaso"). Revisa el diff buscando mecanismos defensivos nuevos (validación, guard, reintento, cerrojo, fallback, caché, idempotencia, circuit breaker):

- Para cada uno: *"¿qué escenario real y presente del proyecto lo justifica?"*. Verifícalo contra el código — ¿el flujo puede llegar a ese estado, o hay algo que ya lo impide? Si `domain_memory.enabled`, consulta `mcp__domain-memory__search_knowledge` si depende de reglas de dominio.
- Un arreglo debe ser **mínimo**: lo que no ataca directamente la causa raíz de `03-investigation.md` y no responde a un escenario presente, sobra. Va a Bloqueantes con propuesta de recorte.

## 4.5. Comprobación de completitud (M/L, sin bucle)

Un arreglo es mínimo por diseño (§4), así que aquí basta **una** comprobación, no un bucle. **Solo M/L**: tras consolidar los hallazgos de §2-§3, contrasta `git diff --stat <git.default_base>...HEAD` contra lo revisado. Si algún fichero cambiado del arreglo no recibió mirada de ningún revisor, dale una pasada dirigida con el revisor que aplique y fusiona. Si el diff es pequeño (lo normal en un arreglo), esto se resuelve en segundos o no aplica.

## 5. Verificación adversarial de hallazgos (Workflow, opcional M/L)

Igual que `/flow:feat:review` §6: si `meta.json.size` es **M o L** y hay **≥ 4** hallazgos entre bloqueantes y sugerencias, ofrece con `AskUserQuestion` filtrarlos con un panel de escépticos en paralelo (mismo script `Workflow` `review-verify`: 3 escépticos por hallazgo, refute-by-default, sobrevive si <2 lo refutan). Los descartados salen del listado y se anotan en el output bajo "Descartados por verificación" con el motivo. No se ofrece en XS/S ni con menos de 4 hallazgos.

## 6. Quality gates

Usa los comandos de `quality` de FLOW.md; si están vacíos, autodescubre:

```
<quality.style_fix>
<quality.static_analysis>
<quality.test_one> (test de regresión)
```

## 7. Output

`.claude/work/<TICKET>/06-review.md`:

```markdown
# Review arreglo {TICKET}

## Resumen
- Agentes lanzados: …
- Bloqueantes: N
- Sugerencias: M

## ¿El arreglo resuelve realmente el fallo?
- Sí / No / Parcial — explica

## ¿Hay alcance ampliado fuera del fallo?
- Sí (listar y proponer mover a otro ticket) / No

## Sobreingeniería (encaje + YAGNI)
- Mecanismos defensivos nuevos en el arreglo: <lista, o "ninguno">
- Sin escenario real que los justifique: <lista, o "ninguno">

## ¿El test de regresión es adecuado?
- Sí / No (qué falta)

## Descartados por verificación adversarial
<solo si se corrió §5; hallazgos refutados con su motivo, o "no aplica">

## Bloqueantes
1. [archivo:línea] …

## Sugerencias
1. …
```

## 8. Cierre

- Con bloqueantes: `phase` queda en `validate`. Iterar.
- Sin bloqueantes: `phase = "review"`, añade a `phases_done`. Sugiere `/flow:bug:postmortem` (M/L) o `/flow:bug:ship` (XS/S).
