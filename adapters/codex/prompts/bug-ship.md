# `/bug-ship`

Cierre del flujo de incidencia: commit, push, MR/PR. Usa la misma mecánica que `/feat-ship` con dos diferencias:

1. Si existe `99-postmortem.md`, **incluye el enlace o el resumen ejecutivo** en la descripción del MR/PR.
2. La oferta de guardar conocimiento ya se hizo en `/bug-postmortem` — aquí no se vuelve a preguntar.

## 0. Pre-flight

Lee `FLOW.md` en la raíz del repo para las convenciones de este repo (tracker, git, calidad, dominio, observabilidad). Si no existe o una clave está vacía, usa el valor por defecto o autodescubre según indique cada paso. Sobre `domain_memory`: si está activo pero el MCP falla o tarda más de 2 s, continúa sin ese contexto, no bloquees ni se lo notifiques al usuario.

- Carga `meta.json`. Exige `review` en `phases_done` (y `validate` si `size` ≥ S, y `postmortem` si `size` es L).
- Si no, niégate y manda al paso faltante.

## 1. Redactar título y descripción (sin enviar nada todavía)

**Importante**: en este paso **no** se invoca aún commit ni push. Solo se redacta el contenido para mostrárselo al usuario en §2.

### Título

Formato: `{PREFIX}{TICKET} Fix <síntoma observable, en lenguaje claro> [patch]`.

**Bien**: `{PREFIX}15310 Fix aperturas contadas dos veces al reintentar [patch]`
**Mal**: `{PREFIX}15310 Fix tracking pixel double-counting on retry in PixelOpenedHandler [patch]`

Los arreglos son `[patch]` salvo que rompan contrato.

### Descripción

**Construye la descripción a partir del Brief del `04-fix.md`**, no de los artefactos técnicos previos. Si el `04-fix.md` no tiene Brief (arreglo antiguo), redáctalo ahora partiendo del síntoma reportado.

Plantilla (en este orden):

```markdown
## Qué deja de pasar tras este arreglo
<lo que el usuario observaba que ya no observará. Lenguaje del síntoma, no del código.>

## Qué se cambia (comportamiento)
<1-2 líneas en lenguaje claro. NO archivos.>

## Qué NO se ha tocado
<bullets sacados del "Qué NO se toca" del Brief. Importante para que el revisor sepa que el arreglo es mínimo.>

## Pasos para reproducir y probar
<sacados de `05-validation.md`:
1. Reproducción del fallo antes del arreglo (que ya no aplica, pero documenta el caso).
2. Cómo verificar que el comportamiento es correcto tras el arreglo.
3. Test de regresión añadido y dónde está.>

## Pre-deploy (SOLO si `git.predeploy_gate` está activo y el arreglo toca la base de datos)
SQL que hay que ejecutar **a mano en el servidor ANTES de desplegar**, todas las sentencias en un único bloque:
```sql
<DDL/índices/columnas/correcciones de datos — todas juntas>
```
⚠️ **No desplegar hasta haber ejecutado este SQL en producción.**

## Postmortem (si existe)
<si hay `99-postmortem.md`: resumen ejecutivo de 3-5 bullets + enlace al artefacto en el repo o wiki.>

---

<details>
<summary>Detalles técnicos para revisores</summary>

- **Causa raíz** (de `03-investigation.md` §"Causa raíz identificada"): <una línea>.
- **Archivos del arreglo**: <de `04-fix.md` "Cambios por archivo">.
- **Test de regresión**: `tests/...` (falla antes del arreglo, pasa después).
- **Áreas con riesgo similar** (anotadas, no arregladas aquí): <de `04-fix.md`>.

</details>
```

Usa las secciones de `git.request_sections` de FLOW.md si están definidas; si no, la plantilla de arriba sirve.

Reglas:
- **El revisor de la incidencia es a menudo un PM o soporte** además del desarrollador. La descripción debe servirle para validar que el síntoma reportado realmente queda resuelto.
- **"Qué NO se ha tocado" es especialmente importante en arreglos** — deja claro que el arreglo es mínimo.
- **La sección `## Pre-deploy` NO va en `<details>`**.
- **Postmortem en cabeza**: si existe, su resumen va en la descripción principal, no en el `<details>`.

### Recolectar el SQL de pre-deploy (solo si `git.predeploy_gate` activo)
Si `quality.db_diff` está definido en `FLOW.md`, ejecútalo. Recolecta **todas** las sentencias en **un único bloque**.

## 2. Mostrar al usuario y esperar confirmación (OBLIGATORIO)

**Nunca se salta este paso.**

Imprime al usuario en este formato exacto:

```
─── Previsualización del {request_term} (arreglo) ───────────────────────────────
Título: <título completo, incluyendo [patch]>
Asignado a: <git.assignee de FLOW.md; vacío = sin asignar>
Squash: <git.squash de FLOW.md>
Rama destino (target): <git.default_base>
Pre-deploy (SQL manual): <"sí — N sentencias, se abrirá hilo bloqueante" / "no aplica">

Descripción:
<descripción completa renderizada tal cual irá al MR/PR>
─────────────────────────────────────────────────────────────────
```

Si hay SQL de pre-deploy, pide al usuario que **confirme expresamente que el bloque está completo y correcto**.

Después pregunta al usuario (header: "Crear {request_term}"):

- **Crear {request_term} con este contenido**: confirma → se invoca §3.
- **Editar antes de crear**: el usuario indica qué cambiar; ajustas y vuelves a §2.
- **Cancelar**: termina sin crear nada.

No invoques push hasta confirmación explícita.

## 3. Commit, push y creación del MR/PR

### 3.0 Cerrojo anti-despliegue (antes de cualquier push)

Igual que `/feat-ship` §4.0: HEAD no debe ser la base principal (master/main), y el upstream no debe apuntar a `git.default_base`. Si el upstream apunta a la base, `git branch --unset-upstream` y `git push -u origin HEAD`. En modo tren el MR/PR apunta a la rama padre.

### 3.1 Crear MR/PR

Solo aquí — con el contenido aprobado en §2 — haz commit con `git commit`, push con `git push -u origin HEAD` (rama propia, nunca a la base principal) y crea el MR/PR con el CLI de `git.cli` de `FLOW.md` usando el título y descripción ya finales.

Asignar a `git.assignee` de FLOW.md (si vacío, sin asignar). Activar squash según `git.squash`.

### 3.2 Hilo de pre-deploy (freno de despliegue)
**Solo si `git.predeploy_gate` está activo y el arreglo tiene SQL de pre-deploy** (§1). Tras crear el MR/PR, abre **un único hilo resoluble/bloqueante** con todo el SQL consolidado. Cuerpo: el bloque SQL bajo "Pre-deploy: ejecutar este SQL en el servidor ANTES de desplegar" + "Resolver solo después de ejecutarlo en producción". **Un solo hilo aunque haya varias sentencias.**

## 4. Cierre

- Actualiza `meta.json`: `phase = "done"`, añade `ship` a `phases_done`.
- Resume: ticket, URL del MR/PR, test de regresión añadido.
- Pregunta si quiere archivar `.claude/work/<TICKET>/` a `.claude/work/_archive/`.
