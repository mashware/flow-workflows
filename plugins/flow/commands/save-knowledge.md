---
description: Consolida los hallazgos del staging de la rama actual al almacén de domain-memory
---

Estás en el flujo `/save-knowledge`.

**Paso 0**: lee `FLOW.md` en la raíz del repo. Si `domain_memory.enabled` no es `true`, responde al usuario *"domain-memory no está habilitado en FLOW.md de este repo."* y termina sin hacer nada más.

El usuario pide consolidar al almacén el conocimiento aprendido en esta sesión (o en sesiones previas sobre la misma rama).

Ejecuta esta secuencia:

1. **Lee el staging** de la rama actual con `read_staging`. Si está vacío y tampoco tienes hallazgos nuevos en el contexto de la sesión actual, dile al usuario *"No hay nada que consolidar en esta rama."* y termina.

2. **Combina** los hallazgos del staging con los hallazgos relevantes que hayan aparecido en la sesión actual y aún no estén en el staging. Aplica la regla del "por qué vs qué": descarta lo que no sea conocimiento de dominio.

3. **Para cada hallazgo consolidado**:
   - Llama a `search_knowledge` con el topic y los `file_paths` del hallazgo.
   - Decide: crear entrada nueva, actualizar una existente, enriquecer con ángulo nuevo, o conflicto.
   - Si hay conflicto, pregunta al usuario en caliente. No guardes hasta resolver.
   - Si no hay conflicto, llama a `save_knowledge` con la decisión.

4. **Resume al usuario** lo que has hecho en formato breve: *"Creadas: N. Actualizadas: M. Archivadas: K. Conflictos resueltos: J."*.

5. **Limpia el staging** de la rama tras consolidar correctamente.

Si cualquier llamada al MCP falla, informa al usuario del fallo concreto (este flujo sí es explícito, los fallos son visibles).

El MCP domain-memory es un proyecto genérico (https://github.com/mashware/domain-memory). Consulta `.domain-memory/instructions.md` en el repo para el detalle completo del comportamiento si existe.
