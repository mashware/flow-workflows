---
description: Commit, push, MR/PR y oferta de guardar conocimiento de dominio
---

# `/feat:ship`

Lee `FLOW.md` en la raíz del repo para las convenciones de este repo (tracker, git, calidad, dominio, observabilidad). Si no existe o una clave está vacía, usa el valor por defecto o autodescubre según indique cada paso. Sobre `domain_memory`: si está activo pero el MCP falla o tarda más de 2 s, continúa sin ese contexto, no bloquees ni se lo notifiques al usuario.

Cierra la feature: commit, push, MR/PR (asignado según `git.assignee`, squash según `git.squash`, secciones según `git.request_sections`) y oferta opcional de consolidar conocimiento.

## 1. Pre-flight

- Carga `meta.json`. Exige `review` en `phases_done`. Para `size` distinto de `XS`, exige también `validate`.
- Si no se cumple, niégate y manda al usuario al paso que falte.
- Comprueba que no quedan TODO o FIXME añadidos en esta rama que sean bloqueantes (`git diff --unified=0 <git.default_base>...HEAD | grep -E '^\+.*(TODO|FIXME)'`). Si los hay, lista y pregunta si seguir.

## 2. Redactar título y descripción (sin enviar nada todavía)

**Importante**: en este paso **no** se invoca aún ningún comando de push ni se crea nada. Solo se redacta el contenido del MR/PR para mostrárselo al usuario en §3.

### Título

Formato: `<TICKET> <qué hace para el usuario, en lenguaje de comportamiento> [patch|minor|major]`.

**Bien**: `<TICKET> Listar aperturas de un seguimiento por API [minor]`
**Mal**: `<TICKET> Add GET /orders/{id}/items endpoint with cursor pagination [minor]`

Si `git.squash` es `true`, el squash deja el título del MR/PR como mensaje de commit final, así que mensaje de commit y título coinciden.

### Descripción

**Construye la descripción a partir del `Brief MR/PR #N` del `05-implementation.md`**, no del diseño técnico. El brief ya está redactado en lenguaje de negocio — ese es el material correcto. Si `05-implementation.md` no tiene Brief (trabajo antiguo), redáctalo ahora basándote en lo que se construyó realmente.

Si `git.request_sections` de `FLOW.md` está definido, estructura la descripción con esas secciones en el orden indicado. Si está vacío, usa la plantilla por defecto:

```markdown
## Para qué sirve
<2-3 bullets: qué problema resuelve / qué necesidad cubre. Por qué importa esta MR/PR. Lenguaje de negocio, NO técnico.>

## Qué cambia para el usuario / sistema
<3-5 bullets sacados del "Tras esta MR/PR..." del Brief. Lo que un revisor sin contexto técnico puede entender.>

## Qué NO incluye
<bullets sacados del "Esta MR/PR NO incluye..." del Brief. Importante para que el revisor sepa qué dejar fuera del scope de la revisión.>

## Pasos para probarlo
<sacados de `07-validation.md` (reproducción del flujo) y `01-context.md` (criterios de aceptación). Numerados, accionables: "1. Entra como X, 2. Ve a Y, 3. Verifica Z".>

## Pre-deploy (SOLO si `git.predeploy_gate` está activo y la rama toca la base de datos)
SQL que hay que ejecutar **a mano en el servidor ANTES de desplegar**, todas las sentencias en un único bloque:
```sql
<DDL/índices/columnas/migraciones de datos no automáticas — todas juntas>
```
⚠️ **No desplegar hasta haber ejecutado este SQL en producción.**

## MR/PR en plan multi-entrega (solo si aplica)
<si `meta.json.mrs` tiene >1 entrada: "MR/PR 2/4 del plan de entrega — ver #1 (link) y siguientes pendientes #3, #4". Incluir links a las anteriores ya mergeadas.>

---

<details>
<summary>Detalles técnicos para revisores</summary>

- **Módulos/capas tocados**: <de `05-implementation.md`>
- **Migraciones**: <sí/no, online/offline>
- **Eventos de dominio nuevos**: <listado o "ninguno">
- **Endpoints nuevos / modificados**: <listado breve>
- **Decisiones de diseño relevantes** (ver `03-design.md` para detalle completo): <2-3 puntos clave del ADR-light>

</details>
```

Reglas:
- **El bloque técnico va en `<details>` colapsado** — el revisor lo abre si quiere, no estorba la lectura principal.
- **La sección `## Pre-deploy` NO va en `<details>`**: es un freno de despliegue, tiene que verse. Solo aplica si `git.predeploy_gate` está activo y la rama toca BD; si no, omítela.
- **No copies bullets de `03-design.md` literalmente** al cuerpo principal. El diseño habla de capas, repositorios, value objects — el MR/PR habla del comportamiento que un usuario nota.
- **Si la descripción del brief contradice lo que ves en el diff**, gana lo que está en el diff (y avisa al usuario: o el brief estaba mal, o el build se desvió).

### Recolectar el SQL de pre-deploy (solo si `git.predeploy_gate` activo)
Determina si la rama modifica la base de datos (cambios en migraciones, mappings/esquema, o cambios registrados en `03-design.md`/`05-implementation.md`). Si `quality.db_diff` está definido en `FLOW.md`, ejecútalo para ver el SQL de esquema pendiente. Recolecta **todas** las sentencias que hay que lanzar a mano en el servidor antes de desplegar y consolídalas en **un único bloque** — el mismo que va en la sección `## Pre-deploy` y en el hilo de §4.2. Aunque haya varias modificaciones, es **un solo bloque / un solo hilo**.

## 3. Mostrar al usuario y esperar confirmación (OBLIGATORIO)

**Nunca se salta este paso, ni siquiera cuando el contenido parece evidente.** El usuario necesita ver y aprobar lo que va a quedar publicado antes de que se cree nada.

Imprime al usuario en este formato exacto:

```
─── Previsualización del <git.request_term> ─────────────────────────────────────
Título: <título completo, incluyendo [patch|minor|major]>
Asignado a: <git.assignee de FLOW.md; si vacío: "sin asignar">
Squash al mergear: <git.squash de FLOW.md>
Rama destino (target): <git.default_base de FLOW.md>
Pre-deploy (SQL manual): <"sí — N sentencias, se abrirá hilo bloqueante" / "no aplica">

Descripción:
<descripción completa renderizada tal cual irá al MR/PR>
─────────────────────────────────────────────────────────────────
```

Si hay SQL de pre-deploy, pide al usuario que **confirme expresamente que el bloque está completo y correcto** — es lo que frenará el despliegue y lo que se ejecutará en producción.

Después pregunta con `AskUserQuestion` (header: "Crear <git.request_term>"):

- **Crear con este contenido**: el usuario confirma → se invoca §4.
- **Editar antes de crear**: el usuario indica qué cambiar (título, alguna sección, ambas); ajustas y vuelves a §3 con la nueva previsualización.
- **Cancelar**: termina sin crear nada. No se toca `meta.json`. El usuario podrá volver a `/feat:ship` más adelante.

No hagas push ni invoques ningún comando de creación hasta que el usuario haya respondido "Crear con este contenido".

## 4. Commit, push y creación del MR/PR

### 4.0 Cerrojo anti-despliegue (antes de cualquier push)
Verifica, y **bloquea** si algo falla:
```bash
git rev-parse --abbrev-ref HEAD                          # NO debe ser master/main
git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null   # NO debe ser la rama base
```
- Si HEAD es la rama principal (master/main): para y avisa. No se empuja desde la rama principal.
- Si el upstream es `<git.default_base>` (rama mal creada sin `--no-track`): **no empujes resolviendo upstream**. Corrige con `git branch --unset-upstream` y usa `git push -u origin HEAD`, que fija el upstream a la rama propia.
- En modo tren (`stacked_on` ≠ null): el MR/PR debe apuntar a esa rama padre, no a la base principal.

### 4.1 Crear MR/PR
Solo aquí — con el contenido aprobado por el usuario en §3 — invoca `Skill commit-commands:commit-push-pr` pasándole **título y descripción ya finales**. El skill no debe re-preguntar el contenido; si lo hace, contesta con lo confirmado. Si hace push, debe ser `git push -u origin HEAD` (rama propia), nunca a la rama base.

Si `git.assignee` no está vacío en `FLOW.md`, asigna a ese usuario. Si `git.squash` es `true`, marca squash-before-merge.

Si el skill `commit-push-pr` no está disponible en el momento, haz commit y push manuales y crea el MR/PR con el CLI de `git.cli` de `FLOW.md` — siempre con el contenido ya confirmado en §3.

### 4.2 Hilo de pre-deploy (freno de despliegue)
**Solo si `git.predeploy_gate` está activo y la rama tiene SQL de pre-deploy** (§2). Tras crear el MR/PR, abre **un único hilo resoluble/bloqueante** con **todo** el SQL consolidado, usando el host de `git.host`/`git.cli`:
- **GitLab**: `glab api "projects/<repo-url-encoded>/merge_requests/<iid>/discussions" -f body="..."` (crea un hilo resoluble).
- **GitHub**: una conversación de revisión que requiera resolución antes de mergear (política "require conversation resolution").

Cuerpo del hilo: el bloque SQL bajo "Pre-deploy: ejecutar este SQL en el servidor ANTES de desplegar" + "Resolver este hilo solo después de haberlo ejecutado en producción."

Es el freno: con la política del repo de "todos los hilos resueltos antes de merge", el MR/PR no se puede mergear ni desplegar hasta ejecutar el SQL y **resolver** el hilo. **Un solo hilo aunque haya varias sentencias.** Avisa al usuario de que queda abierto a propósito.

## 5. Conocimiento de dominio (oferta)

Si `domain_memory.enabled` es `true` en `FLOW.md`:

**Solo si hay algo no obvio que valga la pena guardar** (regla de silencio por defecto):

1. **Lee el staging acumulado durante la rama**: llama a `mcp__domain-memory__read_staging`. Esto te muestra lo que `/feat:design` (y posiblemente otras fases) ya stageó. Es el material principal a consolidar.
2. **Revisa los artefactos** `03-design.md`, `05-implementation.md` y `06-review.md` por si hay hallazgos del tipo "por qué" (decisiones de dominio, restricciones legales, integraciones, motivaciones de negocio) que **no se stagearon en su momento**. El "qué" (código, paths) NO se guarda — eso está en el repo.
3. **Combina staging + hallazgos nuevos** en una lista corta. Si la lista queda vacía o solo tiene cosas obvias derivables del código, no insistas.
4. Si hay 1+ hallazgos relevantes, pregunta al usuario si quiere consolidarlos. Si dice sí, invoca `Skill save-knowledge` (este skill ya hace `read_staging` internamente y orquesta el save; tú aportas el contexto de qué consolidar). Si dice no, no insistas.

Si `domain_memory.enabled` es `false` o vacío, salta sin avisar.

## 6. Cierre

Actualiza `meta.json` según el escenario:

**A) El MR/PR se mergeó correctamente** (caso normal):
- Si **no** hay `mrs` o solo había 1: `phase = "done"`, añade `ship` a `phases_done`, actualiza `updated_at`.
- Si es build multi-entrega: marca la MR/PR actual como `merged` (con `url` final) en `meta.json.mrs`. Si quedan entradas `pending`, deja `phase = "build"` (el ciclo se repite para la siguiente). Si todas están `merged`/`closed`/`superseded`, `phase = "done"`.

**B) El MR/PR se cerró sin merge** (rechazada, descartada por revisores):
- Marca la entrada actual como `closed` con `note` explicando el motivo.
- Pregunta al usuario: ¿se reintenta con otra MR/PR (vuelve a `/feat:build` con un enfoque distinto), o se considera la feature inviable (`/work:abandon`)? No tomes la decisión solo.

**C) El plan cambió y esta MR/PR queda fuera**:
- Si vienes aquí porque el plan se replanteó: marca la entrada como `superseded` con `note` apuntando a la nueva MR/PR.

Resume al usuario: ticket, URL del MR/PR, archivos cambiados, tests añadidos. En multi-entrega, indica también entradas restantes según `meta.json.mrs`.

Pregunta si quiere mantener la carpeta `.claude/work/<TICKET>/` o archivarla (mueve a `.claude/work/_archive/`) — solo si `phase = "done"`.
