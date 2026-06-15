---
description: Implementa el arreglo mínimo y deja bitácora
---

# `/flow:bug:fix`

Aplica el arreglo. **Mínimo viable**: no aproveches para refactorizar áreas adyacentes. Si descubres más problemas, anótalos pero no los toques aquí.

## 1. Pre-flight

Lee `FLOW.md` en la raíz del repo para las convenciones de este repo (tracker, git, calidad, dominio, observabilidad). Si no existe o una clave está vacía, usa el valor por defecto o autodescubre según indique cada paso. Sobre `domain_memory`: si está activo pero el MCP falla o tarda más de 2 s, continúa sin ese contexto, no bloquees ni se lo notifiques al usuario.

- Carga `meta.json`.
- Si `size` es `XS`: permite arrancar sin `diagnose`/`investigate`, pero exige una descripción de 2-3 líneas del arreglo.
- Si `size` ≥ S: exige `diagnose` (y `investigate` para M/L) en `phases_done`.
- Lee artefactos previos.

## 2. Brief del arreglo (antes de teclear)

Antes de tocar código, redacta un brief en lenguaje **claro** (no técnico) específico de este arreglo:

```
Brief arreglo {TICKET}

Qué deja de pasar tras el arreglo:
- <síntoma observable que el usuario reportó, descrito en términos de qué veía>

Qué se cambia:
- <una línea, en lenguaje de negocio o de comportamiento, no de archivos>

Qué NO se toca:
- <áreas adyacentes que podrían tentar a refactorizar>
- <regresiones potenciales que NO se atacan aquí>
```

**Pregunta al usuario con `AskUserQuestion`** si refleja el arreglo esperado:
- **Sí, adelante** → aplica el arreglo.
- **No, falta algo o sobra** → ajusta el brief, vuelve a preguntar. No tocas código hasta confirmación.

Guarda el brief al inicio de `04-fix.md`. Si durante la implementación surge la tentación de "ya que estamos, también arreglar X" (típico en fallos), vuelve a §2.3 — los arreglos que se aprovechan para refactorizar áreas adyacentes son la principal vía de introducir regresiones nuevas mientras arreglas la antigua.

## 2.1 Trabajo

- Aplica el arreglo mínimo apuntando al hallazgo del `03-investigation.md` (o al diagnóstico si saltaste investigate).
- Si toca área sensible (autenticación, pagos, datos sensibles), apóyate puntualmente en el agente de `agents.architecture` de FLOW.md para confirmar capa correcta; si está vacío, contrasta directamente con `conventions` de FLOW.md.
- Usa `TaskCreate` para los pasos del arreglo si son >2.
- Mientras editas, mantén la bitácora.

**Commits opt-in**: el agente **no hace `git commit` por su cuenta** durante `/flow:bug:fix`. Al terminar cada paso (o el arreglo completo si es de un solo paso), reporta resumen (archivos, líneas, sugerencia de validación) y espera tu decisión: commitea trabajo en progreso ahora, espera a que valides, o sigue sin commit. Sin tu confirmación explícita, los cambios se quedan en el árbol de trabajo para que puedas probar el arreglo manualmente antes de que quede registrado en el historial.

## 2.3 ¿Surge algo fuera del brief?

Si durante el arreglo asoma una tentación que **no está en el brief de §2** ("ya que estamos, arreglo también X", "este renombrado encaja aquí", "este test extra cubre otro caso"):

**Pausa antes de tocarlo** y pregunta al usuario con `AskUserQuestion`:
- **Sí, añádelo al brief** — actualiza el brief en `04-fix.md` y sigue.
- **No, déjalo fuera** — anótalo en "Áreas con riesgo similar" (si es un riesgo del mismo patrón) o crea una sección "Ideas para tickets aparte" en `04-fix.md`.

Los arreglos ampliados son la causa principal de regresiones colaterales — el flujo te empuja a mantener el arreglo realmente mínimo.

## 3. Bitácora

`.claude/work/<TICKET>/04-fix.md`:

```markdown
# Arreglo {TICKET}

## Brief
**Qué deja de pasar tras el arreglo**:
- <síntoma observable>

**Qué se cambia**:
- <una línea de comportamiento>

**Qué NO se toca**:
- <áreas adyacentes fuera del alcance>

## Descripción del arreglo
<una frase: "El arreglo consiste en …">

## Cambios por archivo
- <archivo> — qué cambió y por qué (1 línea)

## Áreas con riesgo similar (anotadas, NO tocadas aquí)
- abrir ticket aparte si procede

## Ideas para tickets aparte
<cosas que surgieron durante el arreglo y se decidió NO incluir>

## Comandos relevantes
- <comandos usados para instalar dependencias, etc.>
- …
```

## 4. Calidad inmediata

Usa los comandos de `quality` de FLOW.md; si están vacíos, autodescubre (Makefile, scripts npm/composer) y avisa de lo que uses:

- `quality.style_fix`
- `quality.static_analysis`
- Lanza el test que cubre el arreglo: `quality.test_one` (si no existe, lo añadirás en `/flow:bug:validate`).

## 4.1 ¿La investigación sigue siendo válida?

Si al aplicar el arreglo descubres que la **causa raíz** no era la que apuntaba `03-investigation.md` (p.ej. el commit sospechoso no era el culpable, o el patrón roto está en otro sitio), **pausa y vuelve a `/flow:bug:investigate`** para actualizar la causa antes de seguir. Un arreglo que no apunta al porqué real suele dejar la incidencia abierta de otra forma. No avances con una investigación que sabes que está incompleta.

## 5. Cierre

- Actualiza `meta.json`: `phase = "fix"`, añade a `phases_done`.
- Sugiere siguiente: `/flow:bug:validate` (S/M/L) o `/flow:bug:review` (XS).
