---
description: Consolidate the staging findings from the current branch into the domain-memory store
---

You are in the `/save-knowledge` flow.

**Step 0**: Read `FLOW.md` at the repo root. If `domain_memory.enabled` is not `true`, respond to the user with *"domain-memory is not enabled in this repo's FLOW.md."* and stop without doing anything else.

The user wants to consolidate into the store the knowledge gained in this session (or in previous sessions on the same branch).

Run this sequence:

1. **Read the staging** for the current branch with `mcp__domain-memory__read_staging`. If it is empty and you also have no new findings in the current session context, tell the user *"There is nothing to consolidate on this branch."* and stop.

2. **Combine** the staging findings with any relevant findings that appeared in the current session and are not yet in the staging. Apply the "why vs what" rule: discard anything that is not domain knowledge.

3. **For each consolidated finding**:
   - Call `mcp__domain-memory__search_knowledge` with the topic and the `file_paths` of the finding.
   - Decide: create a new entry, update an existing one, enrich with a new angle, or flag a conflict.
   - If there is a conflict, ask the user in real time. Do not save until it is resolved.
   - If there is no conflict, call `mcp__domain-memory__save_knowledge` with the decision.

4. **Report to the user** what was done in brief format: *"Created: N. Updated: M. Archived: K. Conflicts resolved: J."*

5. **Clear the staging** for the branch after consolidating successfully.

If any MCP call fails, inform the user of the specific failure (this flow is explicit — failures are visible).

The domain-memory MCP is a generic project (https://github.com/mashware/domain-memory). Consult `.domain-memory/instructions.md` in the repo for full behavioural details if it exists.
