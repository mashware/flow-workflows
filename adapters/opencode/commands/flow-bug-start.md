---
description: Start a bug flow (tracker, domain-memory, size, branch, initial artifact)
---

# `/flow-bug-start $ARGUMENTS`

Start a bug. `$ARGUMENTS` is **optional**:

- **Given** — a ticket (format `tracker.prefix` from FLOW.md) → *ticket mode*: start from it (§1 reads it).
- **Empty** — *ticket-less mode*: do **not** stop. Synthesize the bug from the conversation you have just had with the user (§1.5) — the frequent case where the user detected something and you investigated it together. Only fall back to asking for a one-line symptom if there is no conversation to draft from.

## 0. Pre-flight

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step indicates. On `domain_memory`: if enabled but the MCP fails or takes more than 2 s, continue without that context — don't block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

**Autonomy.** Read `autonomy.mode` from `FLOW.md` (`manual` | `guided` | `auto`; empty = `manual`) and apply it throughout this command. `manual` — stop at every decision point; at the end, propose the next command by asking the user to confirm it (write the question with the recommended next step as the default numbered option) and invoke it only when the user confirms — never advance without that confirmation, never make the user type it. `guided` — resolve low-risk, unambiguous decisions yourself using the recommended default and record the choice in the phase artifact instead of asking; still ask at genuine decision points; at the end, chain into the recommended next command automatically. `auto` — as `guided`, and also auto-resolve the remaining decision points with sensible (recorded) defaults, chaining phases without pausing. **Hard gates — ALWAYS stop and ask the user, in every mode, no exceptions:** (1) any push or MR/PR creation (all of `ship`); (2) creating or switching a branch when the base is ambiguous (not on a clean main, or a possible train/stacked branch); (3) DB schema changes or migrations; (4) a `review` that surfaced high-severity findings — never chain into `ship` on those. Rule of thumb for everything else: ask only when a decision is (a) irreversible or costly to undo, (b) ambiguous and not resolved by the ticket + domain-memory, or (c) a hard gate; otherwise take the sensible default and record it in the artifact.

- Verify you're in the correct repo.
- **Determine the mode** from `$ARGUMENTS`: non-empty → *ticket mode* (identifier = `$ARGUMENTS`); empty → *ticket-less mode* (identifier = the slug resolved in §1.5).
- Once the identifier is known, check whether this work already exists: in ticket mode, glob both `.claude/work/<TICKET>/` and `.claude/work/<TICKET>-*/` for a `meta.json` whose `ticket` equals `<TICKET>`; in ticket-less mode, `.claude/work/<slug>/meta.json`. If one exists, suggest `/flow-work-resume`. In ticket-less mode run this check right after the slug is decided in §1.5.

**Work directory naming.** The work lives in `.claude/work/<work-dir>/`. `meta.json.ticket` stays the **pure identifier** (the real ticket id, or the slug in ticket-less local-only) — it feeds the tracker view, the issue link, and `{TICKET}` in the branch. The **directory name** adds a human-readable slug so several concurrent works are told apart on disk:
- **ticket mode** → `<TICKET>-<slug>`, where `<slug>` is a short English kebab-case slug (≤5 words) derived from the symptom — the **same** slug used for the branch in §3.
- **ticket-less local-only** → `<slug>` (there the identifier already *is* the slug; no suffix).

Derive the slug **once** — after the symptom is known (§1), or in §1.5.2 for ticket-less — and reuse it for both the branch (§3) and the directory (§4). Existing works created before this convention are named just `<TICKET>`; they keep working because every other command locates the work by matching `meta.json.branch`, not by the directory name.

## 1. Gather context

In parallel:

1. **Tracker** *(ticket mode only)*: read it using `tracker.view_cmd` from FLOW.md (replace `{TICKET}` with `$ARGUMENTS`). If `tool:none` or the key is missing, ask the user for the symptom, severity, and environment. **In ticket-less mode skip this — §1.5 synthesis is the source of symptom/severity/environment.**
2. **domain-memory** (if `domain_memory.enabled`): call `search_knowledge` with keywords from the symptom. Useful for detecting prior postmortems in the same area.
3. **Observability** if the incident is recent: if you have clues (service, trace, log), consider using the `observability.platform` MCP tools from FLOW.md. If not, don't force it.
4. **Git**: check for a clean working tree and base commit.

## 1.5 Ticket-less start (only when `$ARGUMENTS` is empty)

Skip this whole section in ticket mode. In ticket-less mode it replaces the tracker read as the source of the bug definition.

### 1.5.1 Synthesize the bug from the conversation
From the conversation held with the user in this session — the user spotted something and you investigated it together — distil the bug. Do **not** invent facts not observed:

- **Symptom** — what is misbehaving, one line.
- **Severity / affected environment** — as far as the conversation established it.
- **Reproduction / trigger** — the steps or condition seen to cause it.
- **Initial clues** — stack traces, logs, traces, dead-letter workers mentioned while investigating.
- **What you already found together** — conclusions reached in the investigation so far (capture verbatim; this is real progress, don't lose it).
- **Repos affected** — if the fix spans more than one repo, list each *other* repo and the one-line slice it needs. Only when the conversation points to another project; omit otherwise.
- **Estimated size** — `XS|S|M|L` with one line (confirmed in §2).

If there is **not enough conversation** to draft from, don't fabricate: ask the user for a one-line symptom (or a ticket id) and build from that.

### 1.5.2 Slug
Derive a short English kebab-case slug (≤5 words) from the symptom. This is the work identifier: the work lives in `.claude/work/<slug>/` and, in local-only mode, names the branch. It is also the `<slug>` reused by §3/§4. Run the §0 "already exists" check now against `<slug>`.

### 1.5.3 Confirm the draft
Show the draft to the user and let them confirm or adjust **before writing anything**. This replaces having to say "create a task with what we found".

### 1.5.4 Offer to create the tracker issue
Creating a tracker issue is an **outward-facing action → always ask, in every autonomy mode** (like the MR/PR gate; never automatic):

- If `tracker.tool` is not `none`, ask the user (numbered options, recommended default first) whether to create the real issue from this draft.
  - **Yes** → create it with the tool's native command, best-effort (`gh issue create`, `glab issue create`, the `acli`/`linear` create command; if unclear, ask the user to create it and paste the id). If §1.5.1 found **repos affected**, include them in the body under a short "Repos affected" heading, so the multi-repo scope is recorded in the tracker for the whole team, not only in the local `meta.json`. Capture the id. **From here the run is in ticket mode**: identifier = that id, work dir `.claude/work/<id>/`, branch named from the real id. If creation fails, warn and fall back to local-only with the slug.
  - **No** → local-only: identifier stays the slug, no issue created.
- If `tracker.tool` is `none` or empty, skip the offer and proceed local-only with the slug.

Record the outcome for `meta.json` (§4): `draft_from_conversation: true`, and `tracker_issue` = the created id/url or `null`.

## 1.6 Cross-repo scope

Some fixes span more than one repo (a backend fix plus its consumer, a shared contract plus its clients). flow is per-repo — the work dir lives only here — so if the fix touches other repos and it is not recorded, the other side is silently forgotten after `ship`.

If there are signals of multi-repo scope (the ticket mentions another project, the conversation settled that a change is needed elsewhere), **ask once**: does this fix also touch other repos? For each one, capture `repo` (the sibling project name) and a one-line `scope`, and record them in `meta.json.related_repos` (§4). **Silent by default**: if there is no signal, do not ask. flow only **notes and reminds** — it never touches or scans the other repo.

## 2. Classify size

| Size | Criteria                                                       | Suggested phases                                    |
|------|----------------------------------------------------------------|-----------------------------------------------------|
| XS   | Obvious fix (typo, inverted condition, null check)             | start → fix → review → ship                         |
| S    | Clear symptom, reasonably scoped cause                         | start → diagnose → fix → review → validate → ship   |
| M    | Clear symptom but non-obvious cause, possible regression       | start → diagnose → investigate → fix → validate → review → postmortem |
| L    | Critical incident, multi-component, production affected        | full flow + mandatory postmortem                    |

## 3. Branch

Same two non-negotiable rules as `/flow-feat-start` §5 (breaking them already caused an accidental deployment):

1. **Explicit base**, never implicit from wherever you are. If you're on another task's branch, you'd inherit its commits.
2. **No upstream inheritance**: with `branch.autoSetupMerge=true` (team config), creating from `git.default_base` in FLOW.md without `--no-track` sets the upstream to that base, and a push could end up there.

```bash
git rev-parse --abbrev-ref HEAD && git status --porcelain   # where am I / clean tree
git fetch origin
git switch --create $ARGUMENTS-fix-slug --no-track <git.default_base>   # independent base; --no-track required
```

In ticket-less local-only mode there is no `$ARGUMENTS`: name the branch `<slug>-fix` from the §1.5 slug (prefix from `tracker.prefix` if set). If an issue was created in §1.5.4, use the real id as usual.

If the current branch is not the main base, ask the user for the base (`git.default_base` recommended, or stacked on top of the current one in train mode → record it as `stacked_on`). Create only after user confirmation. First push always `git push -u origin HEAD` (in `ship`), never to the main base.

**Worktree mode** (same as `/flow-feat-start` §5.0/§5.4): read `git.worktree` from FLOW.md. If `always` (or `ask` and the user chooses it), create the branch as a worktree instead of switching in place — `git worktree add --no-track -b <branch> <worktree-path> <git.default_base>`, path from `git.worktree_path` (empty → `.worktrees/<branch>`, git-ignore it). Don't `git switch`; the fix runs from the worktree (`cd <worktree-path>`). Record the resolved path in `meta.json.worktree`. If `off`/empty, in place as above and `worktree` is `null`.

## 4. Write artifacts

Create the work directory following the §0 naming: `.claude/work/<TICKET>-<slug>/` in ticket mode, `.claude/work/<slug>/` in ticket-less local-only mode.

`<work-dir>/meta.json`:
```json
{
  "ticket": "<identifier: $ARGUMENTS in ticket mode; the slug or created issue id in ticket-less mode>",
  "slug": "<the §0/§1.5.2 kebab-case slug; equals `ticket` in ticket-less local-only>",
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

`<work-dir>/01-context.md`:
```markdown
# Bug context {TICKET}

## Reported symptom
<what the reporter said>

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
- Failed-queue workers (if applicable):

## Estimated size: <XS|S|M|L>
```

In ticket-less mode set `draft_from_conversation: true` and `tracker_issue` (created id/url or `null`); fill `## Reported symptom`, `## Tracker data` and `## Initial clues` from the §1.5 synthesized draft, and add one line noting the bug was synthesized from the investigation and whether a tracker issue was created (id) or it is local-only.

## 4.5 Tracker: move to in progress

Move the ticket to "in progress" and assign it so it does not sit stale in the backlog while you work. **Only** if `tracker.tool` is not `none`/empty, `tracker.start_cmd` is set, and `meta.json.ticket` is a **real tracker id** (in ticket-less local-only mode there is no ticket — skip silently; but if §1.5.4 created a real issue, the run is now in ticket mode and this applies to that id).

Run `tracker.start_cmd` substituting `{TICKET}` = `meta.json.ticket` and `{ASSIGNEE}` = `tracker.assignee` (or `git.assignee` if the former is empty; if both are empty and the command needs `{ASSIGNEE}`, run only the transition part you can and warn). Moving a ticket is an **outward-facing action**: in `autonomy.mode: manual` ask once with `AskUserQuestion` before running; in `guided`/`auto` run it automatically and record it in `01-context.md`. It is **best-effort and idempotent** — if the command fails or the ticket is already in that state, warn in one line and continue; **never block** the flow. If `tracker.start_cmd` is empty, do nothing.

## 5. Wrap-up

Summarize and suggest the next command based on size (`/flow-bug-fix` for XS, `/flow-bug-diagnose` for the rest). Then apply the `autonomy.mode` from the preamble: `manual` stops and recommends; `guided`/`auto` chain into that command automatically, subject to the hard gates.
