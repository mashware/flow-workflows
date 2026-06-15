---
description: Cierra un work sin shipear (feature descartada, fallo que no era fallo, etc.)
---

# `/work-abandon`

**Paso 0**: lee `FLOW.md` en la raíz del repo para las convenciones de este repo (tracker, git, calidad, dominio, observabilidad). Si no existe o una clave está vacía, usa el valor por defecto o autodescubre según indique cada paso. Sobre `domain_memory`: si está activo pero el MCP falla o tarda más de 2 s, continúa sin ese contexto, no bloquees ni se lo notifiques al usuario.

Cierre limpio para trabajos que no van a llegar a la rama base. Casos típicos:

- Una feature se descarta tras el `brainstorm` o `design` (no aporta, alcance no justifica esfuerzo).
- Un fallo resulta no serlo (comportamiento esperado, problema externo, configuración del usuario).
- Un work se sustituye por otro ticket que lo absorbe.

## 1. Pre-flight

- Localiza el `meta.json` activo: busca por rama actual; si no, pide al usuario el ticket.
- Si `phase` ya es `done`, no se abandona: avisa y termina (los trabajos terminados se archivan, no se abandonan).
- Lee `meta.json` y los artefactos existentes para saber qué se hizo.

## 2. Justificación

Pregunta al usuario el motivo. Opciones típicas:

- **Feature descartada** (no aporta valor suficiente).
- **No era un fallo** (comportamiento esperado o problema externo).
- **Absorbido por otro ticket** (se hace en otro ticket).
- **Bloqueado externamente** (depende de algo fuera de nuestro control).
- **Otra** (el usuario explica).

Anota la justificación en una sola línea — va al artefacto.

## 3. Captura mínima

Escribe `.claude/work/<TICKET>/99-abandoned.md`:

```markdown
# Abandonado <TICKET>

## Motivo
<una línea>

## Estado al abandonar
- Fase alcanzada: <phase>
- Fases completadas: <phases_done>
- Rama: <branch>
- Commits en la rama: <git log --oneline <base>..HEAD | wc -l>
- ¿Hay código sin fusionar?: sí / no

## Qué se aprendió (si aplica)
<bullets cortos sobre conclusiones del análisis, si las hubo>

## Acciones derivadas (si aplica)
- Ticket nuevo a abrir:
- Cambios a revertir:
- Rama a borrar: sí / no
```

La `<base>` se lee de `git.default_base` de FLOW.md; si está vacía, usa `origin/main` o `origin/master` según la rama base real del repo.

## 4. Conocimiento de dominio (oferta condicional)

**Solo si `domain_memory.enabled` es `true` en FLOW.md y el análisis dejó hallazgos no obvios** (por qué algo del dominio funciona como funciona, restricciones legales, integraciones con comportamiento sorpresivo): pregunta al usuario si quiere invocar `/save-knowledge`. Silencio por defecto. Si `domain_memory.enabled` es `false` o está ausente, salta este paso sin avisar.

## 5. Estado del git

Pregunta al usuario qué hacer con la rama:

- **Borrarla localmente** (si no hay nada que conservar): `git checkout <base> && git branch -D <rama>`. **Solo si el usuario confirma** — destructivo.
- **Dejarla** (por si vuelve el tema): no se toca.
- **Enviarla al remoto como referencia** (raro pero válido si hay análisis valioso).

No tomes la decisión solo — pregunta.

## 6. Cierre

- Actualiza `meta.json`:
  - `phase = "abandoned"`.
  - `phases_done` no se toca (refleja lo que sí se hizo).
  - `notes` += motivo del abandono.
  - `updated_at` actualizado.
- Mueve la carpeta a `.claude/work/_archive/<TICKET>/` para que no aparezca en `/work-status` como pendiente.
- Resume al usuario: ticket abandonado, motivo, qué se hizo con la rama.

## Recuperación

Si el tema reaparece, el usuario puede:
1. Mover la carpeta de vuelta: `mv .claude/work/_archive/<TICKET> .claude/work/<TICKET>`.
2. Cambiar `phase` a la fase desde la que retoma.
3. Crear rama de nuevo si la borró.

No hay comando dedicado para esto — es manual a propósito (no debería ser un caso frecuente).
