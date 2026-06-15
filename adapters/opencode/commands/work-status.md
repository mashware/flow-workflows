---
description: Resumen del estado de todos los trabajos abiertos en .claude/work/
---

# `/work-status`

**Paso 0**: lee `FLOW.md` en la raíz del repo para las convenciones de este repo (tracker, git, calidad, dominio, observabilidad). Si no existe o una clave está vacía, usa el valor por defecto o autodescubre según indique cada paso. Sobre `domain_memory`: si está activo pero el MCP falla o tarda más de 2 s, continúa sin ese contexto, no bloquees ni se lo notifiques al usuario.

Muestra panorámica de los trabajos en curso y detecta divergencias entre los artefactos y el git real.

## 1. Lista trabajos

- `ls -1 .claude/work/` (ignora `_archive`).
- Para cada carpeta que coincida con el patrón de ticket lee su `meta.json`.

## 2. Por cada trabajo, muestra

```
<TICKET> [feat|bug] [XS|S|M|L]  ⏵ <phase actual>
  Rama:        <branch>           [✓ activa | ⚠ no es la actual]
  Started:     <fecha>
  Updated:     <fecha>
  Phases done: context, design, build…
  MR/PRs:      2/4 merged · MR/PR #3 in_progress · MR/PR #4 pending
  Pendiente:   <siguiente comando sugerido>
```

El término "MR" o "PR" se lee de `git.request_term` de FLOW.md; si está vacío, se usa "MR/PR".

La línea `MR/PRs:` solo se imprime si `meta.json.mrs` existe y tiene >0 entradas. Formato:
- Resumen: `<merged>/<total> merged`.
- Si hay MR/PRs `closed` o `superseded`, añadir al recuento: `2/4 merged · 1 closed · 1 pending`.
- Si hay uno `in_progress`, mostrarlo explícitamente con su número.
- Si hay alguno `closed` o `superseded`, listar también el motivo (truncado a 40 chars): `MR/PR #2 closed (revisor pidió otro enfoque)`.

### Progreso real vs estimación

**Solo para el MR/PR `in_progress` y solo si la rama coincide con la actual** (puedes medir el diff). La base para el diff se lee de `git.default_base` de FLOW.md; si está vacía, autodescubre la rama base del repo. Calcula:

```bash
git diff --shortstat <base>..HEAD          # líneas
git diff --name-only <base>..HEAD | wc -l  # archivos
```

Compara con `mrs[in_progress].lines_est` y `files_est` y muestra una línea debajo de `MR/PRs:`:

```
  Tamaño MR/PR actual: 180/120 líneas (150%) · 7/6 archivos     ⚠ supera estimación
```

Reglas:
- Si líneas ≤ `lines_est * 1.5` **y** archivos ≤ `files_est + 2`: muestra sin warning, en gris.
- Si supera **cualquiera** de los dos umbrales: añade `⚠ supera estimación` y sugiere que `/feat-build` aplique §2.2 (cortar / seguir / reabrir).
- Si `lines_est` no existe en el meta.json (work creado antes de esta mejora): no muestres la línea, no inventes estimación.

## 3. Divergencias con git

Si la rama del meta.json **es la actual**:

- `git diff --name-only <base>...HEAD | wc -l` → archivos cambiados en la rama.
- Lee `04-implementation.md` o `04-fix.md` y extrae los archivos listados.
- Si hay archivos cambiados en git que no aparecen en la bitácora, mostrar:
  ```
  ⚠ Divergencia: <N> archivos cambiados sin registrar en bitácora.
     Ejemplos: <ruta>, <ruta>…
  ```
- Si hay archivos en bitácora que no tienen cambios reales en git, igual.

## 4. Trabajos huérfanos

- Si hay ramas locales con el patrón de ticket sin carpeta `.claude/work/<TICKET>`: avísalo.
- Si hay carpetas `.claude/work/<TICKET>` cuya rama ya no existe localmente: pregunta si archivar.

El patrón de rama se infiere de `git.branch_pattern` de FLOW.md; si está vacío, busca ramas cuyo nombre coincida con el patrón `<prefijo>XXXXX-*` o carpetas huérfanas de `.claude/work/`.

## 5. Acciones rápidas

Al final, si hay un trabajo cuya rama coincide con la actual, sugiere:
- Si `phase = "done"`: nada que hacer, oferta archivar.
- Si `phase = "abandoned"`: la carpeta debería estar ya en `_archive/`; si está en raíz, sugiere mover.
- Si hay MR/PR `in_progress` esperando confirmación de fusión: indica que `/feat-ship` actualice el estado.
- Si hay MR/PR `closed` sin decisión posterior: avisa para que el usuario decida (reintentar construcción o abandonar).
- En otro caso: el siguiente comando concreto.
