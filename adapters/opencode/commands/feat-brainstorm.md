---
description: Genera opciones, ángulos y riesgos para la feature antes de diseñar
---

# `/feat-brainstorm`

Lee `FLOW.md` en la raíz del repo para las convenciones de este repo (tracker, git, calidad, dominio, observabilidad). Si no existe o una clave está vacía, usa el valor por defecto o autodescubre según indique cada paso. Sobre `domain_memory`: si está activo pero el MCP falla o tarda más de 2 s, continúa sin ese contexto, no bloquees ni se lo notifiques al usuario.

Fase de exploración. **No escribe código.** Solo abre el espacio de opciones para que el diseño no parta de la primera idea.

## 1. Pre-flight

- Localiza el `meta.json` activo: busca primero por la rama actual (`git branch --show-current`), si no, pregunta el ticket.
- Si `meta.json.phase` no es `context`, avisa y pregunta si seguir igualmente.
- Si `size` es `XS` o `S`, sugiere saltar a `/feat-design` o `/feat-build` directamente y termina (a menos que el usuario insista).
- Lee `01-context.md`.

## 2. Consulta domain-memory enfocada

Si `domain_memory.enabled` es `true` en `FLOW.md`: antes de generar opciones, llama a `mcp__domain-memory__search_knowledge` con consultas enfocadas en el **concepto/patrón** que cubre la feature, no en el título genérico (eso ya se consultó en `/feat-start`). Ejemplos según el área:

- Si la feature toca seguimiento → `"tracking deduplication"`, `"hash collision"`.
- Si toca pagos → `"trial expiration"`, `"plan downgrade flow"`.
- Si toca integraciones externas → `"attachment handler"`, `"tax rules integration"`.

Lanza 2-3 consultas en paralelo. Tiempo de espera máximo 2s; si falla, sigue sin contexto y no avises al usuario. Anota los resultados relevantes en `02-brainstorm.md` bajo "Conocimiento de dominio adicional" (no repitas lo ya en `01-context.md`). Si `domain_memory.enabled` es `false` o vacío, salta sin avisar.

## 3. Trabajo

### 3.0 ¿Panel multiagente o subagente único?

- Si `meta.json.size` es **M o L**: ofrece al usuario el **panel de enfoques en paralelo** ("¿Generar las opciones con un panel de subagentes en paralelo? Más coste en tokens, menos sesgo de una sola línea de pensamiento."). Si acepta → §3.A. Si declina → §3.B.
- Si es **S** (o el usuario declinó): §3.B directamente. No se ofrece panel en XS/S — el coste no compensa.

### 3.A Panel de enfoques (subagentes en paralelo)

Lanza varios subagentes `@nombre` (según `agents.architecture` y equivalentes de `FLOW.md`, o subagentes de propósito general si están vacíos) con el modo `mode:subagent`, **en paralelo sin verse entre ellos** — diversidad real. Cada subagente genera **un** enfoque desde una lente distinta:

- **Mínimo**: el enfoque MÁS pequeño que resuelve el caso de uso declarado, nada más (MVP estricto).
- **Reutilización**: el enfoque que MÁS reutiliza piezas ya existentes en el módulo afectado o vecinos.
- **Operación**: el enfoque más sólido en producción (observabilidad, fallo de integración externa, datos a escala).
- **Replanteo**: cuestiona la premisa: ¿y si el problema se resuelve sin construir lo que se pide, o en otro sitio?

Para cada lente, el subagente recibe: título del ticket, ruta a `01-context.md` y la lente concreta. No escribe código. Reporta en markdown: qué es el enfoque, módulos/capas afectados, riesgo principal, por qué podría ser mala idea.

Una vez recibidos todos los enfoques, **sintetízalos tú** (el agente principal): rankea de mejor a peor para ESTE caso (encaje en el proyecto + simplicidad, no genérico), y da una recomendación inicial con 2-3 líneas de justificación. Si un subagente no respondió, simplemente no lo incluyas.

### 3.B Subagente único (caso por defecto)

Lanza un subagente de propósito general con este encargo (breve, autocontenido):

> Genera 3-5 enfoques distintos para resolver `<título>` siguiendo las convenciones del proyecto (ver `FLOW.md` y `.claude/work/<TICKET>/01-context.md`). Para cada enfoque: una frase de qué es, módulos/capas afectados, principal riesgo, y por qué podría ser mala idea. No escribas código. Reporta en markdown bajo 400 palabras.

Si la feature toca dominio sensible (pagos, autenticación, seguimiento), lanza **en paralelo** un segundo subagente de propósito general con foco en "qué puede salir mal" para ese dominio.

## 4. Output

Crea `.claude/work/<TICKET>/02-brainstorm.md`:

```markdown
# Brainstorm <TICKET>

## Conocimiento de dominio adicional
<resultados del search_knowledge enfocado, o "sin hallazgos">

## Opciones consideradas
### Opción A: <nombre>
- Qué es:
- Módulos/capas afectados:
- Riesgo principal:
- Por qué podría ser mala idea:

### Opción B: …
### Opción C: …

## Riesgos transversales
<bullets>

## Recomendación inicial
<una opción, con justificación de 2-3 líneas>
```

## 5. Dudas emergentes

Mirar opciones suele revelar preguntas nuevas que `/feat-start` no detectó (p.ej. "¿esto solo aplica a planes pagados?", "¿qué pasa si el usuario ya tiene N de esto?"). Si han aparecido, **pregúntalas al usuario antes de cerrar**. Anota las respuestas al final de `02-brainstorm.md` bajo "Decisiones aclaradas en /feat-brainstorm".

## 6. ¿El tamaño sigue siendo correcto?

Tras ver las opciones, evalúa si `meta.json.size` sigue cuadrando con el alcance real:

- Si el brainstorm sugiere que la feature es mucho más simple/compleja de lo asumido, **propón al usuario reclasificar** con la nueva estimación y una línea justificando.
- Si confirma, actualiza `meta.json.size` y anota el cambio en `meta.json.notes` (`"size: M→S tras brainstorm — opción elegida no requiere migración"`).
- Si dice que mantiene el tamaño, sigue.

## 7. Cierre

- Actualiza `meta.json`: `phase = "brainstorm"`, añade a `phases_done`, actualiza `updated_at`.
- Muestra al usuario las opciones y pídele que elija (o que pida ajustes) **antes** de pasar a `/feat-design`. Si elige una, anótala en `meta.json.notes`.
