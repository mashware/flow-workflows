---
description: Implementa la feature siguiendo el diseño aprobado y va dejando bitácora
---

# `/feat-build`

Lee `FLOW.md` en la raíz del repo para las convenciones de este repo (tracker, git, calidad, dominio, observabilidad). Si no existe o una clave está vacía, usa el valor por defecto o autodescubre según indique cada paso. Sobre `domain_memory`: si está activo pero el MCP falla o tarda más de 2 s, continúa sin ese contexto, no bloquees ni se lo notifiques al usuario.

Fase de implementación. Aquí sí se escribe código.

## 1. Pre-flight

- Carga `meta.json` por rama actual.
- Para `size` M/L: exige que `03-design.md` **y** `04-mr-plan.md` existan. Si falta el plan, manda a `/feat-plan`. Si falta el diseño, manda a `/feat-design`.
- Para `size` XS/S: permite arrancar sin diseño pero pide al usuario una nota de 2-3 líneas sobre qué va a hacer y guárdala como `03-design.md` mínimo. No hay plan de MRs/PRs (siempre 1 MR/PR).
- Lee todos los artefactos previos.
- **Si hay `meta.json.mrs` con más de una entrada**: identifica la primera MR/PR con `status: "pending"`. Esa es la MR/PR de esta iteración. Si todas están `merged`, avisa: feature terminada, no hay nada que construir. Marca la elegida como `in_progress` en `meta.json.mrs`.

## 2. Brief de negocio (antes de teclear)

**Antes de cargar convenciones, de crear tareas, de cualquier edición**, redacta un brief en lenguaje **de negocio** (no técnico) específico de **esta MR/PR concreta** (la `in_progress` de `meta.json.mrs`, no de toda la feature):

```
Brief MR/PR #N: <título>

Tras esta MR/PR:
- El usuario podrá <X>.
- El sistema <hará Y / dejará de hacer Z>.
- <métrica de éxito si aplica>.

Esta MR/PR NO incluye:
- <pieza Y que pertenece a MR/PR #N+1>.
- <funcionalidad relacionada que se decidió no hacer>.
- <alcance tentador que queda fuera>.
```

Reglas para redactarlo:
- **Lenguaje de negocio**: di "el usuario podrá filtrar campañas por fecha", no "se crea el endpoint `GET /campaigns?from=...`".
- **Específico de la MR/PR**: si la feature tiene 4 MRs/PRs, el brief habla solo de lo que esta aporta — no de la feature completa.
- **El "NO incluye" es obligatorio**: aunque parezca redundante con el `04-mr-plan.md`, repetirlo aquí fija el alcance. Si no sabes qué poner, el plan está mal.
- 3-5 bullets en cada lista. Más es ruido.

**Pregunta al usuario** si el brief refleja lo que espera:
- **Sí, adelante** → empieza a construir.
- **No, hay algo de más o de menos** → el usuario aclara, ajustas el brief y vuelves a preguntar. **No tocas código** hasta que el brief esté confirmado.

Guarda el brief al inicio de `05-implementation.md` bajo "## Brief MR/PR #N". Sirve como contrato para el resto de la construcción: si surge la tentación de hacer algo que no está en el brief, vuelve a §2.4 antes de hacerlo.

## 2.0bis Copia los contratos del diseño (verbatim, no parafrasees)

**Antes de teclear código**, abre `03-design.md` y localiza la sección **"Contratos externos"**. Por **cada contrato** allí declarado (HTTP body, header, ruta, evento, columna, métrica), **cópialo literalmente** a `05-implementation.md` bajo una sección nueva:

```markdown
## Contratos a respetar (copiados verbatim de 03-design.md §"Contratos externos")

### Contrato N: <descripción>
- **Shape literal**:
  <BLOQUE COPIADO TAL CUAL, sin re-escribir, sin parafrasear, sin "creo que era así">
- **Desviación de patrón** (si aplica): <copiado del diseño>
```

Reglas duras:
- **Copia, no reescribas.** El objetivo es anclar tu atención: cuando luego decidas entre seguir un patrón del repo o el contrato declarado, el contrato vive en el archivo donde estás escribiendo, no en otro que ya no miras.
- **Si el diseño escribió el contrato en prosa** (sin shape literal), reconvierte ese contrato a formato literal aquí mismo y avísalo en el reporte al usuario: "el contrato N estaba en prosa en el diseño, lo he convertido a literal — confirma que es correcto". No avances hasta confirmación.
- **Si hay sección "Desviación de patrón"**: cópiala también. Te recuerda en el momento de codear que no debes imitar al patrón del repo aunque la mano se vaya hacia allí.
- **Si el diseño dice "ninguno"** (no hay superficies externas), salta este paso y déjalo registrado: "## Contratos a respetar — ninguno declarado en diseño".

Sin esta copia, no se pasa a §2.1.

## 2.1 Trabajo

Carga las convenciones del proyecto (ver `FLOW.md` sección `conventions`).

**Si estás en una construcción multi-MR/PR**: limítate a lo que toca la MR/PR actual según `04-mr-plan.md`. Cualquier código que pertenezca a una MR/PR posterior es alcance ampliado; recórtalo o aíslalo tras indicador de funcionalidad / código muerto temporal según el plan. Si no se puede aislar, pausa y vuelve a `/feat-plan` para recortar.

Decide modo de ejecución:

- **Hilo único (XS/S/M)**: implementas tú mismo, paso a paso, usando subagentes solo como consultores puntuales si te bloqueas: el subagente de arquitectura de `FLOW.md` para dudas de capa (o un subagente de propósito general si está vacío), y el de persistencia para dudas de consultas/mappings (o un subagente de propósito general si está vacío).
- **Delegación parcial (M/L con piezas claras)**: usa subagentes `@nombre` para endpoints aislados, y el subagente de testing de `FLOW.md` en paralelo para preparar la suite (o un subagente de propósito general si está vacío). Pasa el `03-design.md` íntegro en el prompt para que no inventen.

### 2.2 Puntos de control (commits locales bajo confirmación del usuario)

**Regla dura**: el agente **no hace `git commit` por su cuenta** durante `/feat-build`. Los commits son **opt-in del usuario** — sin tu confirmación explícita, los cambios se quedan en el árbol de trabajo para que puedas validarlos antes (probar la UI, ejecutar el flujo, leer el diff).

**Tras completar cada paso del plan**, el agente:

1. Reporta al usuario un resumen del paso (≤ 5 líneas):
   ```
   Paso N listo: <descripción>
     Archivos: <lista corta>
     Diff: +<añ> / -<borr> líneas
     Validación sugerida: <p.ej. "lanza el comando de test unitario para Foo" o "abre la UI en /sección">
   ```
2. **No commitea**. Espera a que el usuario diga qué hacer. Posibilidades:
   - **"Commitea ahora"** o **"Vale, sigue"** → el agente hace `git add <archivos del paso> && git commit -m "WIP <TICKET>: <paso>" --no-verify` y continúa con el siguiente paso.
   - **"Espera, valido"** → el agente se queda quieto. El usuario valida a su ritmo. Cuando vuelva, decide commit o ajuste.
   - **"Hay que cambiar X"** → el agente ajusta. El commit del paso queda pendiente hasta que vuelvas a dar OK.
   - **"Sigue sin commitear, agrupamos luego"** → el agente arranca el paso siguiente sin commit. Los cambios se acumulan en el árbol de trabajo.

Reglas para cuando sí se commitea:
- Un commit por paso (cuando se hace). No agrupes varios pasos en un commit salvo que el usuario lo pida explícitamente.
- `--no-verify` está permitido **solo en commits de trabajo en curso** (los hooks lentos correrán al final en `/feat-review` y en el commit definitivo de `/feat-ship`).
- Si un paso queda a medias y el usuario pide commit, el mensaje lleva sufijo: `WIP <TICKET>: <paso> (parcial)`.

### 2.3 Termómetro de tamaño y corte en caliente

**Tras cada paso completado** (haya commit o no), compara el tamaño real con la estimación de la MR/PR actual en `meta.json.mrs`. Mira commits + preparados + no preparados, no solo commits:

```bash
# Cambios commiteados sobre la rama base:
git diff --shortstat <git.default_base>..HEAD     # líneas
git diff --name-only <git.default_base>..HEAD | wc -l   # archivos

# Cambios en árbol de trabajo (pendientes de commit):
git diff --shortstat HEAD             # líneas no commiteadas
git status --short | wc -l            # archivos modificados/sin rastrear
```

Suma ambos lados para obtener el tamaño real total de la MR/PR en curso.

Umbrales de aviso:
- **Líneas reales > `lines_est * 1.5`**, o
- **Archivos reales > `files_est + 2`**.

Si se supera cualquiera, **pausa** y pregunta al usuario (las opciones, en este orden):

1. **Cortar aquí (recomendado si la pieza actual es coherente)**. Lo construido hasta ahora se queda como esta MR/PR. Lo que falta del plan se reparte en una nueva insertada en `meta.json.mrs` justo después. Cero código tirado.
2. **Seguir y registrar la sobreestimación**. Útil si el corte sería artificial. Se anota la desviación en `05-implementation.md` para calibrar `/feat-plan` en futuros tickets.
3. **Reabrir plan**. Volver a `/feat-plan` para replantear todo el troceo. Solo si la sobreestimación indica que el plan está mal a un nivel más profundo, no solo en esta MR/PR.

**Mecánica del corte en caliente (opción 1)**:

0. **Si hay cambios sin commitear** en el árbol de trabajo: avisa al usuario y pídele decidir antes de cortar.
1. Identifica un punto de corte: el último commit de trabajo en curso donde la pieza es coherente y fusionable.
2. Edita `meta.json.mrs`: la MR/PR actual mantiene `n` y `title`, ajusta `lines_est` y `files_est` a lo real, queda `in_progress`. Inserta una nueva con `n` siguiente, `title` describiendo lo restante, `status: "pending"`.
3. Edita `04-mr-plan.md`: corta la entrada original en dos.
4. Anota en `05-implementation.md` bajo "Corte en caliente": fecha, motivo, qué se queda y qué pasa a la siguiente.
5. **No reescribas historia con `git rebase`**: los commits de trabajo en curso que pertenecen a la siguiente MR/PR se quedan en la rama actual y se trasladan con `git cherry-pick` cuando llegue el momento.

**Si ya hubo un corte y vuelves a desbordar**: pregunta al usuario antes de cortar de nuevo — un segundo corte sobre la misma MR/PR es señal de que el plan está mal. La opción correcta probablemente es **3 (reabrir plan)**.

### 2.4 ¿Sale algo fuera del brief?

Si durante la construcción aparece la tentación de añadir algo que **no está en el brief de §2** ("ya que estoy aquí…", "este test me cubriría también X…", "este renombrado mejoraría Y…"):

**Pausa antes de hacerlo** y pregunta al usuario:
- **Sí, añádelo al brief** — actualiza el brief en `05-implementation.md` y sigue. (Si el añadido es grande, considera §2.3: puede disparar corte de la MR/PR).
- **No, déjalo fuera** — anótalo en la sección "Ideas para tickets aparte" de `05-implementation.md` y sigue con el brief original.

## 3. Bitácora

Mantén `.claude/work/<TICKET>/05-implementation.md` actualizado mientras trabajas (no al final). Esquema:

```markdown
# Implementación <TICKET>

## Brief MR/PR #N
<3-5 bullets de qué podrá hacer el usuario tras esta MR/PR, en lenguaje de negocio>

**Esta MR/PR NO incluye**:
- <piezas que quedan fuera>

## Cambios por archivo
- <archivo> — qué cambió y por qué (1 línea cada uno)

## Decisiones tomadas durante la implementación
- Decisión: …
  - Por qué: …
  - Alternativa descartada: …

## Desviaciones del diseño
- Diseño decía X → se hizo Y porque Z

## Comandos ejecutados relevantes
- <quality.style_fix de FLOW.md>
- <quality.db_update de FLOW.md>
- …

## Pendientes
- [ ] …

## Ideas para tickets aparte
<cosas que surgieron durante la construcción y se decidió NO incluir; cada una con una línea: "qué" + "por qué tiene sentido como ticket propio">
```

## 4. Calidad durante implementación

Al ir terminando piezas grandes:

- Lanza `quality.style_fix` de `FLOW.md` para arreglar estilo; si está vacío, autodescubre (p.ej. desde Makefile o scripts de npm).
- Lanza `quality.static_analysis` de `FLOW.md` cuando haya pieza estable; si está vacío, autodescubre.
- Si añadiste tests, lánzalos con `quality.test_one` de `FLOW.md` (sustituyendo `{FILTER}`); si está vacío, autodescubre.

No hagas el code review aquí — eso es `/feat-review`.

## 4.1 ¿El diseño sigue siendo válido?

Revisa la sección "Desviaciones del diseño" de `05-implementation.md`. Si se cumple **cualquiera** de:

- **2+ desviaciones significativas** (cambio de módulo, contrato de evento distinto, entidad diferente, repositorio nuevo no previsto).
- **1 desviación que invalida una decisión** del ADR-light de `03-design.md`.
- **Aparece una pieza de diseño que el inventario previo no detectó** y que cambia el plan.

**Pausa la construcción y vuelve a `/feat-design`** para actualizar el documento. No sigas implementando contra un diseño que ya no es cierto — `/feat-review` y `/feat-validate` leen el `03-design.md` como verdad y harán juicios equivocados si miente.

Si las desviaciones son pequeñas (renombrados, ajustes locales), no pasa nada: anótalas y sigue.

## 4.2 Comprobación textual de contratos (antes de cerrar)

Si en §2.0bis copiaste contratos a `05-implementation.md`, **antes de marcar la construcción como hecha** hay que confrontar el código contra cada contrato citado. **No es un test que correr** — es una comparación textual deliberada que tú haces como agente, no delegada al ejecutor de tests.

Para cada contrato en "Contratos a respetar":

1. Localiza en el código la construcción de la shape (el array del controller, el constructor del evento, la migración de la columna, la llamada al cliente de métricas, etc.).
2. Vuelca las **claves y anidamiento** que produce ese código (o el literal que emite, en el caso de un header/ruta).
3. Compara **clave a clave, carácter a carácter** contra la cita literal copiada en §2.0bis.
4. Si difiere algo — una clave en camelCase vs snake_case, un nivel de anidamiento distinto, una clave de más o de menos, un sufijo en singular vs plural — **vuelve a editar el código** para que coincida. No avances al cierre con desajuste.

Anota el resultado en `05-implementation.md` bajo "## Verificación de contratos":

```markdown
## Verificación de contratos (§4.2)
- Contrato N "<descripción>": código produce <shape real>, cita declara <shape declarada>. ✅ coincide / ❌ ajustado en commit X.
```

Si no había contratos copiados (diseño dijo "ninguno"), salta este paso y registra: "## Verificación de contratos — N/A (sin contratos externos)".

## 5. Cierre

- Actualiza `meta.json`: `phase = "build"`, añade a `phases_done`.
- Si hay construcción multi-MR/PR, deja la MR/PR actual como `in_progress` en `meta.json.mrs`; pasará a `merged` cuando `/feat-ship` confirme la fusión.
- Resume al usuario en bullets: archivos tocados (alto nivel), pendientes, **resultado de §4.2 (contratos verificados)**, y siguiente comando: `/feat-review`.
