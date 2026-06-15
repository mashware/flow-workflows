---
description: Valida tests, edge cases e integridad antes de enviar
---

# `/feat:validate`

Lee `FLOW.md` en la raíz del repo para las convenciones de este repo (tracker, git, calidad, dominio, observabilidad). Si no existe o una clave está vacía, usa el valor por defecto o autodescubre según indique cada paso. Sobre `domain_memory`: si está activo pero el MCP falla o tarda más de 2 s, continúa sin ese contexto, no bloquees ni se lo notifiques al usuario.

Verifica que la feature está terminada: cobertura de tests, edge cases, rendimiento, regresiones.

## 1. Pre-flight

- Carga `meta.json`. Exige `review` en `phases_done`. Si no, manda a `/feat:review`.
- Si `size` es `XS`, se puede saltar esta fase (avisa y sigue con `/feat:ship`).

## 2. Trabajo

Lanza en **paralelo**:

1. **Agente de tests**: usa el agente de `agents.testing` de `FLOW.md`; si está vacío, usa `Agent general-purpose` con este rol. Encargo: "Revisa los cambios de la rama y completa la suite de tests donde falte cobertura. Foco: edge cases del `03-design.md`, paths de error, validaciones de entrada, eventos de dominio emitidos. No reescribas tests que ya pasen. Lee `.claude/work/<TICKET>/03-design.md` y `05-implementation.md`. Respeta las convenciones de tests del proyecto (ver `FLOW.md` sección `conventions`)."

2. **Agente de rendimiento** si la feature toca persistencia, repositorios, plantillas en hot paths o controladores con tráfico real: usa el agente de `agents.performance` de `FLOW.md`; si está vacío, usa `Agent general-purpose` con este rol. Encargo: "Detecta N+1, índices faltantes, consultas no acotadas, flush en bucle, trabajo síncrono pesado que debería ir a cola. Reporta solo lo accionable."

3. **Suite completa**: lanza `quality.test` de `FLOW.md` en background; si está vacío, autodescubre el comando de tests del proyecto y avisa de lo que uses. Si hay cambios en frontend y `quality.frontend_test` está definido, lánzalo también.

## 3. Edge cases manuales

Si la feature tiene UI o flujos críticos:
- Si toca pagos: prueba con las tarjetas o credenciales de test que corresponda al proveedor (ver `Skill stripe:test-cards` si usas Stripe).
- Si toca workers/colas: asegúrate de que no se quedan trabajos en dead-letter. Si los hay y no son tuyos, no los toques aquí.
- Si toca migraciones: ejecuta `quality.db_update` de `FLOW.md` (si está definido). Verifica que no hay diferencia de esquema inesperada con el comando de comparación que use el proyecto.

## 4. Output

Escribe `.claude/work/<TICKET>/07-validation.md`:

```markdown
# Validación <TICKET>

## Cobertura de tests
- Unit añadidos: N (lista)
- Integration añadidos: M
- Functional añadidos: K

## Resultado de suites
- `<quality.test>`: ✅ / ❌ (N tests, X failures)
- `<quality.frontend_test>`: ✅ / ❌ / N-A
- `<quality.static_analysis>`: ✅ / ❌

## Rendimiento
- Hallazgos del análisis: …
- Riesgos abiertos: …

## Edge cases verificados
- [x] …
- [ ] …

## Regresiones
- Áreas comprobadas: …
- Sin regresiones detectadas / detectadas: …
```

## 5. Cierre

- Si quedan tests en rojo o regresiones, **no avances `phase`**. El usuario las resuelve y vuelve a `/feat:validate`.
- Si todo verde: `phase = "validate"`, añade a `phases_done`. Sugiere `/feat:ship`.
