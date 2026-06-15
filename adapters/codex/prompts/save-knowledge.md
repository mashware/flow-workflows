# `/save-knowledge`

Consolidates the staged findings from the current branch into the domain-memory store.

**Step 0**: read `FLOW.md` at the repo root. If `domain_memory.enabled` is not `true`, respond to the user with *"domain-memory is not enabled in this repo's FLOW.md."* and stop without doing anything else.

The user is asking to consolidate into the store the knowledge learned in this session (or in previous sessions on the same branch).

Execute this sequence:

1. **Read the staging** for the current branch with `read_staging`. If it's empty and you also have no new findings in the current session's context, tell the user *"There is nothing to consolidate on this branch."* and stop.

2. **Combine** the staged findings with relevant findings that appeared in the current session and are not yet in the staging. Apply the "why vs what" rule: discard anything that is not domain knowledge.

3. **For each consolidated finding**:
   - Call `search_knowledge` with the topic and the `file_paths` of the finding.
   - Decide: create a new entry, update an existing one, enrich with a new angle, or conflict.
   - If there's a conflict, ask the user in real time. Don't save until it's resolved.
   - If no conflict, call `save_knowledge` with the decision.

4. **Summarize for the user** what you did in brief format: *"Created: N. Updated: M. Archived: K. Conflicts resolved: J."*

5. **Clear the staging** for the branch after consolidating successfully.

If any MCP call fails, inform the user of the specific failure (this workflow is explicit, failures are visible).

The domain-memory MCP is a generic project (https://github.com/mashware/domain-memory). Consult `.domain-memory/instructions.md` in the repo for the full behavior details if it exists.
