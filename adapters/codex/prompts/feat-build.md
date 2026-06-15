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

**Antes de cargar skills, de crear tareas, de cualquier edición**, redacta un brief en lenguaje **de negocio** (no técnico) específico de **esta MR/PR concreta**:

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

Guarda el brief al inicio de `05-implementation.md` bajo "## Brief MR/PR #N". Sirve como contrato para el resto del build: si surge la tentación de hacer algo que no está en el brief, vuelve a §2.4 antes de hacerlo.

## 2.0bis Copia los contratos del diseño (verbatim, no parafrasees)

**Antes de teclear código**, abre `03-design.md` y localiza la sección **"Contratos externos"**. Por **cada contrato** allí declarado (HTTP body, header, ruta, evento, columna, métrica), **cópialo literalmente** a `05-implementation.md` bajo:

```markdown
## Contratos a respetar (copiados verbatim de 03-design.md §"Contratos externos")

### Contrato N: <descripción>
- **Shape literal**:
  <BLOQUE COPIADO TAL CUAL, sin re-escribir, sin parafrasear>
- **Desviación de patrón** (si aplica): <copiado del diseño>
```

Reglas duras:
- **Copia, no reescribas.** El objetivo es anclar tu atención.
- **Si el diseño escribió el contrato en prosa**, reconviértelo a formato literal aquí mismo y avísalo al usuario.
- **Si hay sección "Desviación de patrón"**: cópiala también.
- **Si el diseño dice "ninguno"**, salta este paso y registra: "## Contratos a respetar — ninguno declarado en diseño".

Sin esta copia, no se pasa a §2.1.

## 2.1 Trabajo

Carga los skills del proyecto (ver `FLOW.md` sección `conventions`).

**Si estás en un build multi-MR/PR**: limítate a lo que toca la MR/PR actual según `04-mr-plan.md`. Cualquier código que pertenezca a una MR/PR posterior es expansión de alcance; recórtalo o aíslalo tras indicador de funcionalidad / código muerto temporal según el plan.

Decide modo de ejecución:

- **Hilo único (XS/S/M)**: implementas tú mismo, paso a paso, usando subagentes solo como consultores puntuales si te bloqueas: el agente de `agents.architecture` de `FLOW.md` para dudas de capa, y el de `agents.persistence` para dudas de consultas/mappings.
- **Delegación parcial (M/L con piezas claras)**: usa subagentes para endpoints aislados, y el agente de `agents.testing` de `FLOW.md` en paralelo para preparar la suite. Pasa el `03-design.md` íntegro en el prompt para que no inventen.

### 2.2 Confirmación de commits (opt-in del usuario)

**Regla dura**: el agente **no hace `git commit` por su cuenta** durante `/feat-build`. Los commits son **opt-in del usuario** — sin confirmación explícita, los cambios se quedan en el árbol de trabajo.

**Tras completar cada paso**, el agente:

1. Reporta al usuario un resumen del paso (≤ 5 líneas):
   ```
   Paso N listo: <descripción>
     Archivos: <lista corta>
     Diff: +<añ> / -<borr> líneas
     Validación sugerida: <p.ej. "lanza el comando de test unitario para Foo">
   ```
2. **No commitea**. Espera a que tú decidas:
   - **"Commitea ahora"** o **"Vale, sigue"** → hace `git add <archivos del paso> && git commit -m "WIP <TICKET>: <paso>" --no-verify` y continúa.
   - **"Espera, valido"** → se queda quieto. Tú validas a tu ritmo.
   - **"Hay que cambiar X"** → ajusta. El commit del paso queda pendiente hasta que vuelvas a dar OK.
   - **"Sigue sin commitear, agrupamos luego"** → arranca el paso siguiente sin commit.

Reglas para cuando sí se commitea:
- Un commit por paso. No agrupes varios pasos salvo que tú lo pidas explícitamente.
- `--no-verify` está permitido **solo en commits WIP** (los ganchos lentos correrán en `/feat-review` y en el commit definitivo de `/feat-ship`).
- Estos commits se aplastan al fusionar (si `git.squash` es `true`), así que no tienen que ser bonitos.

### 2.3 Termómetro de tamaño y corte en caliente

**Tras cada paso completado** (haya commit o no), compara el tamaño real con la estimación de la MR/PR actual en `meta.json.mrs`:

```bash
# Cambios commiteados sobre la rama base:
git diff --shortstat <git.default_base>..HEAD
git diff --name-only <git.default_base>..HEAD | wc -l

# Cambios en árbol de trabajo (pendientes de commit):
git diff --shortstat HEAD
git status --short | wc -l
```

Suma ambos lados para obtener el tamaño real total.

Umbrales de aviso:
- **Líneas reales > `lines_est * 1.5`**, o
- **Archivos reales > `files_est + 2`**.

Si se supera cualquiera, **pausa** y pregunta al usuario (las opciones, en este orden):

1. **Cortar aquí (recomendado si la pieza actual es coherente)**.
2. **Seguir y registrar la sobreestimación**.
3. **Reabrir plan**. Volver a `/feat-plan` para replantear todo el troceo.

### 2.4 ¿Sale algo fuera del brief?

Si durante el build aparece la tentación de añadir algo que **no está en el brief de §2**, **pausa** y pregunta al usuario:
- **Sí, añádelo al brief** — actualiza el brief en `05-implementation.md` y sigue.
- **No, déjalo fuera** — anótalo en la sección "Ideas para tickets aparte" de `05-implementation.md`.

## 3. Bitácora

Mantén `.claude/work/<TICKET>/05-implementation.md` actualizado mientras trabajas (no al final):

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

## Pendientes
- [ ] …

## Ideas para tickets aparte
<cosas que surgieron durante el build y se decidió NO incluir>
```

## 4. Calidad durante implementación

Al ir terminando piezas grandes:

- Lanza `quality.style_fix` de `FLOW.md` para arreglar estilo; si está vacío, autodescubre.
- Lanza `quality.static_analysis` de `FLOW.md` cuando haya pieza estable; si está vacío, autodescubre.
- Si añadiste tests, lánzalos puntuales con `quality.test_one` de `FLOW.md` (sustituyendo `{FILTER}`); si está vacío, autodescubre.

## 4.1 ¿El diseño sigue siendo válido?

Revisa la sección "Desviaciones del diseño" de `05-implementation.md`. Si se cumple **cualquiera** de:

- **2+ desviaciones significativas** (cambio de módulo, contrato de evento distinto, entidad diferente, repositorio nuevo no previsto).
- **1 desviación que invalida una decisión** del ADR-light de `03-design.md`.

**Pausa el build y vuelve a `/feat-design`** para actualizar el documento.

## 4.2 Verificación textual de contratos (antes de cerrar)

Si en §2.0bis copiaste contratos, **antes de marcar el build como hecho** confronta el código contra cada contrato citado — **no es un test que correr**, es una comparación textual deliberada:

Para cada contrato en "Contratos a respetar":
1. Localiza en el código la construcción de la shape.
2. Vuelca las **claves y anidamiento** que produce ese código.
3. Compara **clave a clave, carácter a carácter** contra la cita literal copiada en §2.0bis.
4. Si difiere algo, **vuelve a editar el código** para que coincida.

Anota el resultado en `05-implementation.md` bajo "## Verificación de contratos":
```
## Verificación de contratos (§4.2)
- Contrato N "<descripción>": código produce <shape real>, cita declara <shape declarada>. ✅ coincide / ❌ ajustado.
```

## 5. Cierre

- Actualiza `meta.json`: `phase = "build"`, añade a `phases_done`.
- Resume al usuario en bullets: archivos tocados (alto nivel), pendientes, **resultado de §4.2 (contratos verificados)**, y siguiente comando: `/feat-review`.
