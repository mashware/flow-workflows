---
description: Test de regresión y verificación de que el fallo no vuelve
---

# `/bug-validate`

Valida que el arreglo funciona y que el fallo no vuelve.

## 1. Pre-flight

Lee `FLOW.md` en la raíz del repo para las convenciones de este repo (tracker, git, calidad, dominio, observabilidad). Si no existe o una clave está vacía, usa el valor por defecto o autodescubre según indique cada paso. Sobre `domain_memory`: si está activo pero el MCP falla o tarda más de 2 s, continúa sin ese contexto, no bloquees ni se lo notifiques al usuario.

- Carga `meta.json`. Exige `fix` en `phases_done`.
- Si `size` es `XS`, sugiere saltar a `/bug-review` salvo que el usuario insista.

## 2. Trabajo

**Test de regresión obligatorio**: lanza el subagente de `agents.testing` de FLOW.md (si está vacío, un subagente de propósito general con el rol de escribir tests) con el encargo:

> Escribe un test que falle **antes** del arreglo y pase **después**. Lee `.claude/work/<TICKET>/02-diagnose.md` (reproducción mínima), `04-fix.md` (qué se cambió). Sigue las convenciones de `FLOW.md` (sección `conventions`). Reporta el path del test añadido.

Después:
1. Lanza solo ese test con `quality.test_one` de FLOW.md; debe pasar.
2. Lanza la suite completa con `quality.test` para descartar regresiones colaterales (en segundo plano si tarda).
3. Si tocaste BD: comprueba que el esquema no tiene diferencias inesperadas (usa `quality.db_update` o equivalente de FLOW.md si está definido).
4. Si tocaste seguridad o autenticación: lanza en paralelo el subagente de `agents.security` de FLOW.md sobre los archivos del arreglo; si está vacío, usa un subagente de propósito general con rol de seguridad en el prompt.

## 3. Áreas adyacentes

De `03-investigation.md` puede haber "áreas con riesgo similar". No las arregles aquí, pero comprueba que **al menos no tienen el mismo síntoma activo** (búsqueda rápida del patrón roto).

## 4. Output

`.claude/work/<TICKET>/05-validation.md`:

```markdown
# Validación {TICKET}

## Test de regresión
- Path: `tests/...`
- Falla antes del arreglo: ✅
- Pasa después del arreglo: ✅

## Suite completa
- `<quality.test>`: ✅ / ❌ (X failures)
- `<quality.static_analysis>`: ✅ / ❌

## Áreas adyacentes
- Búsquedas hechas:
- Otras incidencias detectadas: <listar para abrir tickets aparte, NO arreglar aquí>
```

## 5. Cierre

- Si test en rojo o regresiones: `phase` se queda en `fix`. El usuario itera.
- Si verde: `phase = "validate"`, añade a `phases_done`. Sugiere `/bug-review`.
