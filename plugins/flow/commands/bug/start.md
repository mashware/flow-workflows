---
description: Start the bug flow (tracker, domain-memory, size, branch, initial artifact)
---

# `/flow:bug:start $ARGUMENTS`

Start a bug. `$ARGUMENTS` is **optional**:

- **Given** — a ticket (format `tracker.prefix` from FLOW.md) → *ticket mode*: start from it (§1 reads it).
- **Empty** — *ticket-less mode*: do **not** stop. Synthesize the bug from the conversation you have just had with the user (§1.5) — the frequent case where the user detected something and you investigated it together. Only fall back to asking for a one-line symptom if there is no conversation to draft from.

## 0. Pre-flight

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it does not exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it is active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

**Autonomy.** Read `autonomy.mode` from `FLOW.md` (`manual` | `guided` | `auto`; empty = `manual`) and apply it throughout this command. `manual` — stop at every decision point; at the end, propose the next command with a single `AskUserQuestion` (the recommended next step as the default option) and invoke it only when the user confirms — never advance without that confirmation, never make the user type it. `guided` — resolve low-risk, unambiguous decisions yourself using the recommended default and record the choice in the phase artifact instead of asking; still ask at genuine decision points; at the end, chain into the recommended next command automatically. `auto` — as `guided`, and also auto-resolve the remaining decision points with sensible (recorded) defaults, chaining phases without pausing. **Hard gates — ALWAYS stop and ask the user, in every mode, no exceptions:** (1) any push or MR/PR creation (all of `ship`); (2) creating or switching a branch when the base is ambiguous (not on a clean main, or a possible train/stacked branch); (3) DB schema changes or migrations; (4) a `review` that surfaced high-severity findings — never chain into `ship` on those. Rule of thumb for everything else: ask only when a decision is (a) irreversible or costly to undo, (b) ambiguous and not resolved by the ticket + domain-memory, or (c) a hard gate; otherwise take the sensible default and record it in the artifact.

- Verify you are in the correct repo.
- **Determine the mode** from `$ARGUMENTS`: non-empty → *ticket mode* (identifier = `$ARGUMENTS`); empty → *ticket-less mode* (identifier = the slug resolved in §1.5).
- Once the identifier is known, if `.claude/work/<identifier>/meta.json` exists, suggest `/flow:work:resume`. In ticket-less mode run this check right after the slug is decided in §1.5.

## 1. Gather context

In parallel:

1. **Tracker** *(ticket mode only)*: read it with `tracker.view_cmd` from FLOW.md (replace `{TICKET}` with `$ARGUMENTS`). If `tool:none` or the key is missing, ask the user for the symptom, severity, and environment. **In ticket-less mode skip this — §1.5 synthesis is the source of symptom/severity/environment.**
2. **domain-memory** (if `domain_memory.enabled`): `search_knowledge` with keywords from the symptom. Important to detect whether there have been previous postmortems in the same area.
3. **Observability** if the incident is recent: if you have clues (service, trace, log), consider using the MCP tools of `observability.platform` from FLOW.md. If not, do not force it.
4. **Git**: check clean branch and commit base.

## 1.5 Ticket-less start (only when `$ARGUMENTS` is empty)

Skip this whole section in ticket mode. In ticket-less mode it replaces the tracker read as the source of the bug definition.

### 1.5.1 Synthesize the bug from the conversation
From the conversation held with the user in this session — the user spotted something and you investigated it together — distil the bug. Do **not** invent facts not observed:

- **Symptom** — what is misbehaving, one line.
- **Severity / affected environment** — as far as the conversation established it.
- **Reproduction / trigger** — the steps or condition seen to cause it.
- **Initial clues** — stack traces, logs, traces, dead-letter workers mentioned while investigating.
- **What you already found together** — conclusions reached in the investigation so far (capture verbatim; this is real progress, do not lose it).
- **Repos affected** — if the fix spans more than one repo, list each *other* repo and the one-line slice it needs. Only when the conversation points to another project; omit otherwise.
- **Estimated size** — `XS|S|M|L` with one line (confirmed in §2).

If there is **not enough conversation** to draft from, do not fabricate: ask the user for a one-line symptom (or a ticket id) and build from that.

### 1.5.2 Slug
Derive a short English kebab-case slug (≤5 words) from the symptom. This is the work identifier: the work lives in `.claude/work/<slug>/` and, in local-only mode, names the branch. Run the §0 "already exists" check now against `<slug>`.

### 1.5.3 Confirm the draft
Show the draft to the user and let them confirm or adjust **before writing anything**. This replaces having to say "create a task with what we found".

### 1.5.4 Offer to create the tracker issue
Creating a tracker issue is an **outward-facing action → always ask, in every autonomy mode** (like the MR/PR gate; never automatic):

- If `tracker.tool` is not `none`, ask with `AskUserQuestion` whether to create the real issue from this draft.
  - **Yes** → create it with the tool's native command, best-effort (`gh issue create`, `glab issue create`, the `acli`/`linear` create command; if unclear, ask the user to create it and paste the id). If §1.5.1 found **repos affected**, include them in the body under a short "Repos affected" heading, so the multi-repo scope is recorded in the tracker for the whole team, not only in the local `meta.json`. Capture the id. **From here the run is in ticket mode**: identifier = that id, work dir `.claude/work/<id>/`, branch named from the real id. If creation fails, warn and fall back to local-only with the slug.
  - **No** → local-only: identifier stays the slug, no issue created.
- If `tracker.tool` is `none` or empty, skip the offer and proceed local-only with the slug.

Record the outcome for `meta.json` (§4): `draft_from_conversation: true`, and `tracker_issue` = the created id/url or `null`.

## 1.6 Cross-repo scope

Some fixes span more than one repo (a backend fix plus its consumer, a shared contract plus its clients). flow is per-repo — the work dir lives only here — so if the fix touches other repos and it is not recorded, the other side is silently forgotten after `ship`.

If there are signals of multi-repo scope (the ticket mentions another project, the conversation settled that a change is needed elsewhere), **ask once with `AskUserQuestion`**: does this fix also touch other repos? For each one, capture `repo` (the sibling project name) and a one-line `scope`, and record them in `meta.json.related_repos` (§4). **Silent by default**: if there is no signal, do not ask. flow only **notes and reminds** — it never touches or scans the other repo.

## 2. Classify size

| Size | Criteria                                                       | Suggested phases                              |
|------|----------------------------------------------------------------|-----------------------------------------------|
| XS   | Obvious fix (typo, inverted condition, null check)             | start → fix → review → ship                   |
| S    | Clear symptom, reasonably bounded cause                        | start → diagnose → fix → review → validate → ship |
| M    | Clear symptom but non-obvious cause, possible regression       | start → diagnose → investigate → fix → validate → review → postmortem |
| L    | Critical incident, multi-component, production affected        | full flow + mandatory postmortem              |

## 3. Branch

Same two non-negotiable rules as in `/flow:feat:start` §5 (breaking them already caused an accidental deployment):

1. **Explicit base**, never implicit from wherever you are. If you are on another task's branch, you would inherit its commits.
2. **No inherited upstream**: with `branch.autoSetupMerge=true` (team configuration), creating from `git.default_base` from FLOW.md without `--no-track` leaves the upstream pointing to that base and a push can end up there.

```bash
git rev-parse --abbrev-ref HEAD && git status --porcelain   # where am I / clean tree
git fetch origin
git switch --create $ARGUMENTS-fix-slug --no-track <git.default_base>   # independent base; --no-track required
```

In ticket-less local-only mode there is no `$ARGUMENTS`: name the branch `<slug>-fix` from the §1.5 slug (prefix from `tracker.prefix` if set). If an issue was created in §1.5.4, use the real id as usual.

If the current branch is not the main base, ask for the base with `AskUserQuestion` (`git.default_base` recommended, or stacked on the current one in train mode → note it as `stacked_on`). Create only if the user confirms. First push is always `git push -u origin HEAD` (in `ship`), never to the main base.

**Worktree mode** (same as `/flow:feat:start` §5.0/§5.4): read `git.worktree` from FLOW.md. If `always` (or `ask` and the user chooses it), create the branch as a worktree instead of switching in place — `git worktree add --no-track -b <branch> <worktree-path> <git.default_base>`, path from `git.worktree_path` (empty → `.worktrees/<branch>`, git-ignore it). Do not `git switch`; the fix runs from the worktree (`cd <worktree-path>`). Record the resolved path in `meta.json.worktree`. If `off`/empty, in-place as above and `worktree` is `null`.

## 4. Write artifacts

`.claude/work/$ARGUMENTS/meta.json`:
```json
{
  "ticket": "<identifier: $ARGUMENTS in ticket mode; the slug or created issue id in ticket-less mode>",
  "type": "bug",
  "title": "<symptom from tracker, or synthesized in §1.5>",
  "branch": "<branch created in §3>",
  "stacked_on": null,
  "worktree": "<worktree path if created in §3, else null>",
  "size": "<XS|S|M|L>",
  "phase": "context",
  "phases_done": ["context"],
  "draft_from_conversation": false,
  "tracker_issue": null,
  "related_repos": [],
  "started_at": "...",
  "updated_at": "...",
  "notes": ""
}
```

Populate `related_repos` from §1.6 — one `{ "repo": "<name>", "scope": "<one line>", "status": "pending" }` per *other* repo the fix touches; leave `[]` for a single-repo fix.

`.claude/work/$ARGUMENTS/01-context.md`:
```markdown
# Bug context {TICKET}

## Reported symptom
<what the reporter says>

## Tracker data
- Severity / priority:
- Affected environment:
- Reporter:
- Date first reported:

## Prior knowledge (domain-memory)
<findings or "no findings">

## Initial clues
- Known stack trace / log:
- Observability trace (if any):
- Workers in dead-letter queue (if applicable):

## Estimated size: <XS|S|M|L>
```

In ticket-less mode set `draft_from_conversation: true` and `tracker_issue` (created id/url or `null`); fill `## Reported symptom`, `## Tracker data` and `## Initial clues` from the §1.5 synthesized draft, and add one line noting the bug was synthesized from the investigation and whether a tracker issue was created (id) or it is local-only.

## 5. Close

Summarize and suggest the next command based on size (`/flow:bug:fix` for XS, `/flow:bug:diagnose` for the rest). Then apply the `autonomy.mode` from the preamble: `manual` stops and recommends; `guided`/`auto` chain into that command automatically, subject to the hard gates.
