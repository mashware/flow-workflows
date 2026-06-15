# `/work-resume`

**Paso 0**: lee `FLOW.md` en la raíz del repo para las convenciones de este repo (tracker, git, calidad, dominio, observabilidad). Si no existe o una clave está vacía, usa el valor por defecto o autodescubre según indique cada paso. Sobre `domain_memory`: si está activo pero el MCP falla o tarda más de 2 s, continúa sin ese contexto, no bloquees ni se lo notifiques al usuario.

Para usar al volver a un trabajo después de un parón (mañana siguiente, otra sesión, etc.).

## 1. Detección

- Lee `git branch --show-current`.
- Busca en `.claude/work/` el `meta.json` con `branch` coincidente.
- Si no hay: pregunta al usuario el ticket o si quiere arrancar uno nuevo.

## 2. Recapitulación

Imprime al usuario en formato breve:

```
Retomas <TICKET> [feat|bug] [tamaño]
Fase actual:   <phase>
Fases hechas:  <lista>
Última edición: <updated_at>
Notas:         <meta.notes>
```

El formato del ticket sigue `tracker.prefix` de FLOW.md; si está vacío, se muestra tal cual está en `meta.json`.

Luego un **resumen de 5 líneas** sintetizando todos los artefactos disponibles (`01-context.md` + lo más reciente):
- Qué se está haciendo y por qué.
- Decisiones tomadas hasta ahora.
- Qué quedaba pendiente.

## 3. Estado del repo

- `git status --short` → cambios pendientes.
- `git log --oneline -5` → últimos commits.
- Avisa si hay cambios sin commitear que no aparecen en la bitácora más reciente.

## 4. Siguiente paso

Sugiere el comando concreto según `phase` y `size`. Si la fase actual quedó interrumpida (p.ej. `build` con artefacto vacío), sugiere repetirla con `/feat-build` o `/bug-fix`.

No avances solo. El usuario decide.
