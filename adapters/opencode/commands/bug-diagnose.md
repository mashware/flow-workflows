---
description: Reproduce el fallo y delimita exactamente qué está roto
---

# `/bug-diagnose`

Fase de diagnóstico: aislar **qué** está fallando antes de buscar **por qué**.

## 1. Pre-flight

Lee `FLOW.md` en la raíz del repo para las convenciones de este repo (tracker, git, calidad, dominio, observabilidad). Si no existe o una clave está vacía, usa el valor por defecto o autodescubre según indique cada paso. Sobre `domain_memory`: si está activo pero el MCP falla o tarda más de 2 s, continúa sin ese contexto, no bloquees ni se lo notifiques al usuario.

- Carga `meta.json`. Si `type` no es `bug`, niégate.
- Si `size` es `XS`, sugiere saltar a `/bug-fix` y termina.
- Lee `01-context.md`.

## 2. Consulta domain-memory enfocada

Si `domain_memory.enabled`, llama a `mcp__domain-memory__search_knowledge` con consultas sobre el **componente sospechoso** (handler, worker, endpoint, módulo). Suele haber postmortems previos del mismo área que ahorran horas: la misma causa puede haber aparecido bajo otro síntoma.

Ejemplos:
- Cola de fallos → `"DLX <handler-name>"`, `"retry policy worker"`.
- Endpoint → `"endpoint <ruta>"`, `"validation <DTO>"`.
- Frontend → `"<componente>"`, `"<flow-name>"`.

2-3 consultas en paralelo. Tiempo de espera máximo 2s; si falla, sigue. Hallazgos relevantes al artefacto bajo "Conocimiento de dominio previo".

## 3. Trabajo

Objetivo: producir un caso reproducible mínimo y delimitar componentes afectados.

Pasos:

1. **Si es cola de fallos / mensajería**: invoca el subagente que tu proyecto tenga para analizar mensajes muertos, si existe; si no, inspecciona el payload y las cabeceras del mensaje para localizar el handler, historial de reintentos y causa inicial.
2. **Si es API/HTTP**: identifica el endpoint, recoge curl o petición reproducible, verifica la respuesta esperada frente a la real.
3. **Si es frontend**: identifica componente, ruta, pasos para reproducir, herramientas del navegador (consola, red).
4. **Si es worker/consumer**: identifica el tipo de trabajo, mensaje de origen, registros del supervisor (usa el comando `quality.test_one` o equivalente de observabilidad de FLOW.md para filtrar por tipo de worker).
5. **Si es BD**: consulta problemática, plan de ejecución (`EXPLAIN`), datos de entrada que disparan el fallo.

Usa un subagente de propósito general para localizar el código relevante. Pasa un prompt autocontenido con el síntoma y las pistas iniciales.

## 4. Output

`.claude/work/<TICKET>/02-diagnose.md`:

```markdown
# Diagnóstico {TICKET}

## Conocimiento de dominio previo
<hallazgos del search_knowledge enfocado, o "sin hallazgos">

## Reproducción mínima
<pasos numerados que reproducen el fallo>

## Comportamiento esperado vs real
- Esperado:
- Real:

## Componentes implicados
- Archivos sospechosos: (sin afirmar todavía la causa)
- Servicios: backend / worker / frontend / BD

## Datos del fallo
- Stack trace / registro:
- Petición / payload:
- Datos de entrada que lo disparan:

## Hipótesis iniciales
1. …
2. …
```

## 5. ¿El tamaño sigue siendo correcto?

Si el diagnóstico revela que el fallo es trivial (un null check, una errata) y se clasificó como M/L por desconocimiento, propón reclasificar a XS/S. A la inversa: si lo que parecía XS ha resultado afectar a varios componentes, sube el tamaño. Confirma con el usuario antes de cambiar `meta.json.size`.

## 6. Cierre

- Actualiza `meta.json`: `phase = "diagnose"`, añade a `phases_done`.
- Sugiere siguiente: `/bug-investigate` (M/L) o `/bug-fix` (S si la causa es evidente).
