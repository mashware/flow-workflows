---
description: Commit, push, MR/PR del arreglo
---

# `/flow:bug:ship`

Cierre del flujo de incidencia: commit, push, MR/PR. Usa la misma mecánica que `/flow:feat:ship` con dos diferencias:

1. Si existe `99-postmortem.md`, **incluye el enlace o el resumen ejecutivo** en la descripción del MR/PR.
2. La oferta de `save-knowledge` ya se hizo en `/flow:bug:postmortem` — aquí no se vuelve a preguntar.

## 0. Pre-flight

Lee `FLOW.md` en la raíz del repo para las convenciones de este repo (tracker, git, calidad, dominio, observabilidad). Si no existe o una clave está vacía, usa el valor por defecto o autodescubre según indique cada paso. Sobre `domain_memory`: si está activo pero el MCP falla o tarda más de 2 s, continúa sin ese contexto, no bloquees ni se lo notifiques al usuario.

- Carga `meta.json`. Exige `review` en `phases_done` (y `validate` si `size` ≥ S, y `postmortem` si `size` es L).
- Si no, niégate y manda al paso faltante.

## 1. Redactar título y descripción (sin enviar nada todavía)

**Importante**: en este paso **no** se invoca aún `commit-push-pr` ni se crea nada. Solo se redacta el contenido para mostrárselo al usuario en §2.

### Título

Formato: `{PREFIX}{TICKET} Fix <síntoma observable, en lenguaje claro> [patch]`.

**Bien**: `{PREFIX}15310 Fix aperturas contadas dos veces al reintentar [patch]`
**Mal**: `{PREFIX}15310 Fix tracking pixel double-counting on retry in PixelOpenedHandler [patch]`

Los arreglos son `[patch]` salvo que rompan contrato — en ese caso reconsidera si realmente es un arreglo o una funcionalidad con versión.

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
<si hay `99-postmortem.md`: resumen ejecutivo de 3-5 bullets + enlace al artefacto en el repo o wiki. El resumen ejecutivo va aquí porque interesa a stakeholders no técnicos; el detalle se lee aparte.>

---

<details>
<summary>Detalles técnicos para revisores</summary>

- **Causa raíz** (de `03-investigation.md` §"Causa raíz identificada"): <una línea>.
- **Archivos del arreglo**: <de `04-fix.md` "Cambios por archivo">.
- **Test de regresión**: `tests/...` (falla antes del arreglo, pasa después).
- **Áreas con riesgo similar** (anotadas, no arregladas aquí): <de `04-fix.md`>.

</details>
```

Usa las secciones de `git.request_sections` de FLOW.md si están definidas; si no, la plantilla de arriba sirve como descripción libre.

Reglas:
- **El revisor de la incidencia es a menudo un PM o soporte** además del desarrollador de turno. La descripción debe servirle para validar que el síntoma reportado realmente queda resuelto, sin mirar código.
- **"Qué NO se ha tocado" es especialmente importante en arreglos** — evita ampliaciones de alcance y deja claro que el arreglo es mínimo.
- **La sección `## Pre-deploy` NO va en `<details>`**: es un freno de despliegue, tiene que verse. Solo aplica si `git.predeploy_gate` está activo y el arreglo toca BD; si no, omítela.
- **Postmortem en cabeza**: si existe, su resumen va en la descripción principal, no en el `<details>`. Los postmortems suelen contener información de valor para el negocio.

### Recolectar el SQL de pre-deploy (solo si `git.predeploy_gate` activo)
Determina si el arreglo modifica la base de datos (migraciones, mappings/esquema, o cambios registrados en los artefactos). Si `quality.db_diff` está definido en `FLOW.md`, ejecútalo para ver el SQL de esquema pendiente. Recolecta **todas** las sentencias a lanzar a mano antes de desplegar en **un único bloque** — el mismo que va en la sección `## Pre-deploy` y en el hilo de §3.2. Un solo bloque / un solo hilo aunque haya varias.

## 2. Mostrar al usuario y esperar confirmación (OBLIGATORIO)

**Nunca se salta este paso.** El usuario necesita ver y aprobar lo que va a quedar publicado antes de que se cree nada.

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

Si hay SQL de pre-deploy, pide al usuario que **confirme expresamente que el bloque está completo y correcto** — es lo que frenará el despliegue y lo que se ejecutará en producción.

Después pregunta con `AskUserQuestion` (header: "Crear {request_term}"):

- **Crear {request_term} con este contenido**: confirma → se invoca §3.
- **Editar antes de crear**: el usuario indica qué cambiar; ajustas y vuelves a §2.
- **Cancelar**: termina sin crear nada. No se toca `meta.json`.

No invoques `commit-push-pr` ni hagas push hasta confirmación explícita.

## 3. Commit, push y creación del MR/PR

### 3.0 Cerrojo anti-despliegue (antes de cualquier push)

Igual que `/flow:feat:ship` §4.0: `git rev-parse --abbrev-ref HEAD` no debe ser la base principal (master/main), y `@{u}` no debe apuntar a `git.default_base`. Si el upstream apunta a la base, `git branch --unset-upstream` y `git push -u origin HEAD`. En modo tren el MR/PR apunta a la rama padre.

### 3.1 Crear MR/PR

Solo aquí — con el contenido aprobado en §2 — invoca `Skill commit-commands:commit-push-pr` pasándole **título y descripción ya finales**. El skill no debe re-preguntar el contenido; si lo hace, contesta con lo confirmado. Si hace push, debe ser `git push -u origin HEAD`, nunca a la base principal.

Asignar a `git.assignee` de FLOW.md (si vacío, sin asignar). Activar squash según `git.squash`.

### 3.2 Hilo de pre-deploy (freno de despliegue)
**Solo si `git.predeploy_gate` está activo y el arreglo tiene SQL de pre-deploy** (§1). Tras crear el MR/PR, abre **un único hilo resoluble/bloqueante** con todo el SQL consolidado, usando el host de `git.host`/`git.cli` (GitLab: `glab api ".../merge_requests/<iid>/discussions"`; GitHub: conversación de revisión con resolución requerida). Cuerpo: el bloque SQL bajo "Pre-deploy: ejecutar este SQL en el servidor ANTES de desplegar" + "Resolver solo después de ejecutarlo en producción".

Con la política de "todos los hilos resueltos antes de merge", el MR/PR no se puede mergear ni desplegar hasta ejecutar el SQL y resolver el hilo. **Un solo hilo aunque haya varias sentencias.** Avisa al usuario de que queda abierto a propósito.

## 4. Cierre

- Actualiza `meta.json`: `phase = "done"`, añade `ship` a `phases_done`.
- Resume: ticket, URL del MR/PR, test de regresión añadido.
- Pregunta si quiere archivar `.claude/work/<TICKET>/` a `.claude/work/_archive/`.
