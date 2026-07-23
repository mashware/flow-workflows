---
description: Start a new feature (read the tracker, classify size, create branch and initial artifact)
---

# `/flow-feat-start $ARGUMENTS`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it does not exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it is active but the MCP fails or takes longer than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

**Autonomy.** Read `autonomy.mode` from `FLOW.md` (`manual` | `guided` | `auto`; empty = `manual`) and apply it throughout this command. `manual` — stop at every decision point; at the end, propose the next command by asking the user to confirm it (write the question with the recommended next step as the default numbered option) and invoke it only when the user confirms — never advance without that confirmation, never make the user type it. `guided` — resolve low-risk, unambiguous decisions yourself using the recommended default and record the choice in the phase artifact instead of asking; still ask at genuine decision points; at the end, chain into the recommended next command automatically. `auto` — as `guided`, and also auto-resolve the remaining decision points with sensible (recorded) defaults, chaining phases without pausing. **Hard gates — ALWAYS stop and ask the user, in every mode, no exceptions:** (1) any push or MR/PR creation (all of `ship`); (2) creating or switching a branch when the base is ambiguous (not on a clean main, or a possible train/stacked branch); (3) DB schema changes or migrations; (4) a `review` that surfaced high-severity findings — never chain into `ship` on those. Rule of thumb for everything else: ask only when a decision is (a) irreversible or costly to undo, (b) ambiguous and not resolved by the ticket + domain-memory, or (c) a hard gate; otherwise take the sensible default and record it in the artifact.

You are starting a feature. `$ARGUMENTS` is **optional**:

- **Given** — an identifier in `tracker.prefix` format from `FLOW.md` → *ticket mode*: start from that ticket (the classic path; §2 reads it).
- **Empty** — *ticket-less mode*: do **not** stop and do **not** demand a ticket. Synthesize a draft ticket from the conversation you have just had with the user (§2.5) — the same way `/flow-feat-ship` builds the MR/PR body from the work log. This is the one-word entry: land the idea in chat, type `/flow-feat-start`, and it captures what you concluded instead of making you restate it. Only fall back to asking the user for a one-liner if there is no conversation to draft from.

## 1. Pre-flight

- Read `FLOW.md` at the repo root. If it does not exist, continue with default behavior (each step states what to do when a key is missing).
- Verify the repo has a recognizable project structure. If not, warn and exit.
- **Determine the mode** from `$ARGUMENTS`: non-empty → *ticket mode* (identifier = `$ARGUMENTS`); empty → *ticket-less mode* (the identifier is the slug resolved in §2.5).
- Once the identifier is known, check whether this work already exists: in ticket mode, glob both `.claude/work/<TICKET>/` and `.claude/work/<TICKET>-*/` for a `meta.json` whose `ticket` equals `<TICKET>`; in ticket-less mode, `.claude/work/<slug>/meta.json`. If one exists, do not overwrite it: warn the user and suggest `/flow-work-resume`. In ticket-less mode run this check right after the slug is decided in §2.5.

**Work directory naming.** The work lives in `.claude/work/<work-dir>/`. `meta.json.ticket` stays the **pure identifier** (the real ticket id, or the slug in ticket-less local-only) — it feeds the tracker view, the issue link, and `{TICKET}` in the branch. The **directory name** adds a human-readable slug so several concurrent works are told apart on disk:
- **ticket mode** → `<TICKET>-<slug>`, where `<slug>` is a short English kebab-case slug (≤5 words) derived from the ticket title — the **same** slug used for the branch in §5.
- **ticket-less local-only** → `<slug>` (there the identifier already *is* the slug; no suffix).

Derive the slug **once** — after the ticket title is known (§2), or in §2.5.2 for ticket-less — and reuse it for both the branch (§5) and the directory (§6). Existing works created before this convention are named just `<TICKET>`; they keep working because every other command locates the work by matching `meta.json.branch`, not by the directory name.

## 2. Gather context

Launch these tasks in **parallel**:

1. **Tracker** *(ticket mode only)*: if `tracker.tool` in `FLOW.md` is not `none`, read the ticket using `tracker.view_cmd` replacing `{TICKET}` — extract title, description, acceptance criteria. If `tool` is `none` or empty, or if the command fails, ask the user to paste the brief and continue with whatever they provide. **In ticket-less mode there is no ticket to read — skip this and use the synthesis in §2.5 as the source of title/description/criteria.**
2. **domain-memory**: if `domain_memory.enabled` is `true`, invoke the `domain-memory` MCP with `search_knowledge` using the ticket title and keywords. If it does not respond within 2 s or fails, continue without context.
3. **Git**: verify you are on a clean branch. If there are uncommitted changes, warn but do not block.

## 2.5 Ticket-less start (only when `$ARGUMENTS` is empty)

Skip this whole section in ticket mode. In ticket-less mode it replaces the tracker read as the source of the work definition.

### 2.5.1 Synthesize the draft from the conversation
From the conversation held with the user in this session, distil a draft ticket — do **not** invent scope that was not discussed:

- **Title** — one line, imperative, English.
- **Summary** — 3-5 bullets of what is being built and why.
- **Provisional acceptance criteria** — what "done" looks like, as far as the conversation settled it.
- **Decisions already closed while talking** — the conclusions you reached together; capture them verbatim so they are not lost.
- **Open questions / risks** — what is still undecided.
- **Repos affected** — if the work spans more than one repo, list each *other* repo and the one-line slice of work it needs. Only when the conversation actually points to another project; omit otherwise.
- **Estimated size** — `XS|S|M|L` with one line of justification (confirmed in §4).

If there is **not enough conversation** to draft from (e.g. `start` was invoked cold), do not fabricate: ask the user for a one-line description (or a ticket id) and build the draft from that.

### 2.5.2 Slug
Derive a short English kebab-case slug (≤5 words) from the title. This is the work identifier: the work lives in `.claude/work/<slug>/` and, in local-only mode, names the branch. It is also the `<slug>` reused by §5/§6. Run the §1 "already exists" check now against `<slug>`.

### 2.5.3 Confirm the draft
Show the draft to the user and let them confirm or adjust **before writing anything**. This is the step that replaces having to say "create a task with what we discussed".

### 2.5.4 Offer to create the tracker issue
Creating a tracker issue is an **outward-facing action → always ask, in every autonomy mode** (like the MR/PR gate; never automatic):

- If `tracker.tool` is not `none`, ask the user (numbered options, recommended default first) whether to create the real issue in the tracker from this draft.
  - **Yes** → create it with the tool's native command, best-effort. If §2.5.1 found **repos affected**, include them in the body under a short "Repos affected" heading — so the multi-repo scope is recorded in the tracker for the whole team, not only in the local `meta.json`:
    - `gh` → `gh issue create --title "<title>" --body "<summary + criteria + repos affected>"`
    - `glab` → `glab issue create --title "<title>" --description "<summary + criteria + repos affected>"`
    - `acli` (Jira) / `linear` → the tool's create command; if it is unclear, ask the user to create it and paste the id.

    Capture the returned identifier. **From here the run is in ticket mode**: the identifier becomes that id, the work dir is `.claude/work/<id>/`, and branch naming uses the real id. If creation fails, warn and fall back to local-only with the slug.
  - **No** → local-only: the identifier stays the slug, no tracker issue is created. You (or a later `start`) can create one by hand.
- If `tracker.tool` is `none` or empty, skip the offer and proceed local-only with the slug.

Record the outcome for `meta.json` (§6): `draft_from_conversation: true`, and `tracker_issue` = the created id/url or `null`.

## 3. Clarify gaps in the ticket

Before classifying size, identify whether there are open questions that affect the design and that neither the brief nor `domain-memory` resolves. Typical examples:

- Behavior with different plan types or access levels.
- Locales, countries, or languages with different rules.
- What happens to existing users of the current flow (compatibility).
- What counts as "success" (metric, event, log entry to leave).
- Obvious edge cases not specified (empty input, duplicate, network failure).

If there are open questions, **ask them all at once** (max 4 questions, the most blocking ones). Do not invent or assume. If everything is clear, continue.

Record the answers in `01-context.md` under "Decisions clarified in /flow-feat-start".

## 3.5 Cross-repo scope

Some tasks span more than one repo (a backend change plus its consumer, an API plus its client). flow is per-repo — the work dir lives only here — so if the task touches other repos and it is not recorded, the other side is silently forgotten after `ship`.

If there are signals of multi-repo scope (the ticket mentions another project, the conversation settled that work is needed elsewhere), **ask once**: does this task also touch other repos? For each one, capture `repo` (the sibling project name) and a one-line `scope`, and record them in `meta.json.related_repos` (§6). **Silent by default**: if there is no signal, do not ask.

flow only **notes and reminds** — it never touches or scans the other repo. When you get to that side you start a normal work there with the same ticket. `/flow-feat-design` and `/flow-feat-plan` refine this list if the design reveals a repo the conversation missed.

## 4. Classify size

Based on the brief and context, propose a size and ask the user to confirm (single question):

| Size | Criterion | Suggested phases |
|------|-----------|------------------|
| XS | < 50 lines, no DB, no new API, no domain logic | start → build → review → ship |
| S | Scoped change, 1-3 relevant files, no migrations | start → design (short) → build → review → validate → ship |
| M | New domain logic, possible migrations, multiple modules | start → brainstorm → design → build → review → validate → ship |
| L | Cross-module, external integrations, significant model changes | full flow, consider splitting |

Recommend the size you estimate with a "(Recommended)".

## 5. Create the branch

**Two non-negotiable rules**, because breaking them has already caused an accidental deployment:

1. **Never** create the branch implicitly from wherever you are. If you are on another task's branch, a `git checkout -b` would inherit its commits.
2. **Never** let the new branch have the base branch as its automatic upstream. With `branch.autoSetupMerge=true`, a `git checkout -b X <base>` pins the upstream to that base, and a push that resolves the upstream can land on the main branch and trigger a deployment.

Both rules apply identically whether the branch is created in place or as a worktree.

### 5.0 In-place or worktree?
Read `git.worktree` from `FLOW.md`:
- `off` or empty → in place (§5.2). This is the current behavior; skip to §5.1.
- `always` → create as a worktree (§5.4).
- `ask` → ask the user ("Create this branch as a git worktree (separate checkout) or in place?"). Worktree → §5.4; in place → §5.2.

### 5.1 Check where you are first
```bash
git rev-parse --abbrev-ref HEAD   # current branch
git status --porcelain            # clean working tree?
```
- If there are uncommitted changes: warn and ask before continuing (they carry over when you switch).
- If the current branch **is not the main branch** (master/main): do NOT assume the base. Ask the user:
  - **Base = `git.default_base` from FLOW.md** *(Recommended)* — independent task. This is the normal case.
  - **Stacked on `<current-branch>`** (train mode) — only if this task depends on another not yet merged. Record it in `meta.json` as `stacked_on` and note that the MR/PR will point to that branch, not the main base.

### 5.2 Create with explicit base and WITHOUT inheriting its upstream
Name: per `git.branch_pattern` from `FLOW.md` (replace `{PREFIX}` and `{TICKET}`; `{slug}` = the slug defined in §1, English kebab-case). **In ticket-less local-only mode there is no `{TICKET}`**: name the branch `<prefix><slug>` (prefix from `tracker.prefix` if set), i.e. apply the pattern with the §2.5 slug in the `{slug}` position and drop the `{TICKET}` segment (collapse any doubled separator). Create only if the user confirms:
```bash
git fetch origin
git switch --create <branch-name> --no-track <git.default_base>      # independent task
# — or, in confirmed train mode: —
git switch --create <branch-name> --no-track origin/<parent-branch>
```
`--no-track` is **mandatory**: it is what prevents the upstream from being set to the remote base. The explicit base (`git.default_base` or the parent branch, never "where I am") is what avoids inheriting commits from another task. Then go to §6 (record `"worktree": null` in `meta.json`).

### 5.4 Create as a git worktree (when §5.0 chose worktree)
Same name and same two non-negotiable rules. The worktree directory comes from `git.worktree_path` (replace `{branch}` = branch name, `{repo}` = repo dir name); empty → `.worktrees/<branch-name>` at the repo root. `git worktree add` creates the branch **and** its checkout in one step:
```bash
git fetch origin
git worktree add --no-track -b <branch-name> <worktree-path> <git.default_base>   # independent task
# — or, in confirmed train mode: —
git worktree add --no-track -b <branch-name> <worktree-path> origin/<parent-branch>
```
`--no-track` is **mandatory** here too (same upstream rule). Do NOT `git switch` — the current checkout stays where it is; the new branch lives in `<worktree-path>`.
- If the path is under the repo (e.g. `.worktrees/`) and it is not already ignored, add the worktree root to `.gitignore` (or `.git/info/exclude`) so the checkout does not show up as untracked. Do not commit the worktree contents.
- Tell the user the rest of the flow runs **from the worktree**: `cd <worktree-path>`. Record the resolved path in `meta.json` as `worktree`.

### 5.3 Push rule (executed in `ship`, declared here)
The first push is **always** explicit to the branch's own remote, never a push that resolves the upstream blindly:
```bash
git push -u origin HEAD    # upstream = origin/<branch-name>, never the main base
```

## 6. Write artifacts

Create the work directory following the §1 naming: `.claude/work/<TICKET>-<slug>/` in ticket mode, `.claude/work/<slug>/` in ticket-less local-only mode.

### `meta.json`
```json
{
  "ticket": "<identifier: $ARGUMENTS in ticket mode; the slug or created issue id in ticket-less mode>",
  "slug": "<the §1/§2.5.2 kebab-case slug; equals `ticket` in ticket-less local-only>",
  "type": "feat",
  "title": "<ticket title>",
  "branch": "<branch created in §5>",
  "stacked_on": null,
  "worktree": "<worktree path if created in §5.4, else null>",
  "size": "<XS|S|M|L>",
  "phase": "context",
  "phases_done": ["context"],
  "draft_from_conversation": false,
  "tracker_issue": null,
  "related_repos": [],
  "started_at": "<ISO8601 now>",
  "updated_at": "<ISO8601 now>",
  "notes": ""
}
```

In ticket-less mode (§2.5) set `draft_from_conversation: true` and `tracker_issue` to the created issue id/url (or `null` if local-only). In ticket mode leave both at their defaults above.

Populate `related_repos` from §3.5 — one `{ "repo": "<name>", "scope": "<one line>", "status": "pending" }` per *other* repo the task touches; leave `[]` for a single-repo task.

### `01-context.md`
Structure:
```markdown
# Context <TICKET>

## Ticket
<brief summary in 3-5 bullets>

## Acceptance criteria
<list from tracker or "not specified">

## Relevant domain knowledge
<domain-memory results, one bullet per finding, or "no findings">

## Repo state at start
- Branch: <name>
- Last commit: <short hash + message>

## Decisions clarified in /flow-feat-start
<list question → user answer, or "no open questions">

## Estimated size: <XS|S|M|L>
<2 lines of justification>
```

In ticket-less mode, fill `## Ticket` and `## Acceptance criteria` from the §2.5 synthesized draft, put the conversation's closed decisions under `## Decisions clarified in /flow-feat-start`, and add one line noting the work was synthesized from conversation and whether a tracker issue was created (id) or it is local-only.

## 6.5 Tracker: move to in progress

Move the ticket to "in progress" and assign it so it does not sit stale in the backlog while you work. **Only** if `tracker.tool` is not `none`/empty, `tracker.start_cmd` is set, and `meta.json.ticket` is a **real tracker id** (in ticket-less local-only mode there is no ticket — skip silently; but if §2.5.4 created a real issue, the run is now in ticket mode and this applies to that id).

Run `tracker.start_cmd` substituting `{TICKET}` = `meta.json.ticket` and `{ASSIGNEE}` = `tracker.assignee` (or `git.assignee` if the former is empty; if both are empty and the command needs `{ASSIGNEE}`, run only the transition part you can and warn). Moving a ticket is an **outward-facing action**: in `autonomy.mode: manual` ask once with `AskUserQuestion` before running; in `guided`/`auto` run it automatically and record it in `01-context.md`. It is **best-effort and idempotent** — if the command fails or the ticket is already in that state, warn in one line and continue; **never block** the flow. If `tracker.start_cmd` is empty, do nothing.

## 7. Wrap-up

Summarize for the user in 2-3 lines:
- Ticket, size, branch.
- Next recommended command based on size (see table).

Then apply the `autonomy.mode` from the preamble: in `manual`, stop here and let the user invoke the recommended command; in `guided`/`auto`, chain into it automatically — subject to the hard gates (branch-base ambiguity in §5 already stops on its own).
