---
description: Consolidate the current branch's staged findings into the domain-memory store
---

You are in the `/save-knowledge` flow.

**Step 0**: read `FLOW.md` at the repo root. If `domain_memory.enabled` is not `true`, respond to the user *"domain-memory is not enabled in this repo's FLOW.md."* and stop without doing anything else.

The user wants to consolidate into the store the knowledge learned in this session (or in previous sessions on the same branch).

Run this sequence:

1. **Read the staging** for the current branch with `read_staging`. If it is empty and you also have no new findings in the current session context, tell the user *"Nothing to consolidate on this branch."* and stop.

2. **Combine** the staged findings with any relevant findings that appeared in the current session and are not yet in staging. Apply the "why vs what" rule: discard anything that is not domain knowledge.

3. **For each consolidated finding**:
   - Call `search_knowledge` with the topic and the `file_paths` of the finding.
   - Decide: create a new entry, update an existing one, enrich with a new angle, or flag a conflict.
   - If there is a conflict, ask the user immediately. Do not save until resolved.
   - If there is no conflict, call `save_knowledge` with the decision.

4. **Report to the user** what was done in brief format: *"Created: N. Updated: M. Archived: K. Conflicts resolved: J."*

5. **Clear the staging** for the branch after successful consolidation.

If any MCP call fails, report the specific failure to the user (this flow is explicit — failures are visible).

The domain-memory MCP is a generic project (https://github.com/mashware/domain-memory). Consult `.domain-memory/instructions.md` in the repo for the full behavior details if it exists.
