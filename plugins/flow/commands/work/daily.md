---
description: Your work assistant — a Scrum-style daily standup across all your work (local + forge + tracker)
argument-hint: "[question]"
---

# `/flow:work:daily $ARGUMENTS`

Load the `flow:flow-core` skill first (shared rules: `FLOW.md` step 0, autonomy, how a stop reads, `panel.json`, `00-summary.md`) — skip if it is already in this session's context.

External sources (tracker, forge, `domain_memory`) are all **best-effort**: a CLI missing/unauthenticated, an MCP failing, or a call over ~3s → continue without that source and note it in a single line; **never block**.

Your **work assistant**: a Scrum-style daily standup — *"what was I working on?"*, *"what's left?"*, *"what should I pick up today?"* — from three sources: **local** work state, the **forge** (open MRs/PRs, reviews, CI), the **tracker** (assigned/re-prioritized tickets). Unlike `/flow:work:status` (technical table) and `/flow:work:resume` (one branch), a cross-cutting narrative briefing.

**Read-only.** Never touches `meta.json`, git, the forge, or the tracker; its only write is the "last seen" marker (§6), like `/flow:news`.

## Modes

- **No `$ARGUMENTS`** → full daily briefing (§5 three-block format).
- **`$ARGUMENTS` is a question** (e.g. `/flow:work:daily what's left on the payment work?`) → answer *that* from the same sources, without the full briefing. Do not move the marker (ad-hoc lookup, like `/flow:news vX.Y.Z`).

## 1. Local layer (always — the base of the briefing)

- `git branch --show-current` → the **active** work.
- `ls -1 .claude/work/` (ignore `_archive`); read each `meta.json`.
- **"Last session" boundary**: the marker from §6 if present; otherwise the most recent commit date and the newest `updated_at` across works.
- Order works by `updated_at` (most recent first); the first is the *"what were we on?"* answer.
- Repo pulse: `git log --oneline --since="<last-session boundary>"` (fallback `-10`) and `git status --short` for uncommitted changes.
- Per work: `phase`, `phases_done`, MRs and their `status` (from `meta.json.mrs`), and what was **left pending** — synthesized from the most recent artifact(s) (`NN-*.md`) and `meta.notes`, not re-derived from code.
- **Cross-repo parts**: `meta.json.related_repos` entries not `done` → a *sibling repo* still needs work. Surface only what is recorded — never scan or open the other repo.

## 2. Forge layer (best-effort, via `git.cli`)

What the team is asking of you **right now**. Resolve the CLI from `git.cli` (or infer from `git.host`); "you" is `git.assignee` if set, else the CLI's own identity (`@me`).

- **Your open MRs/PRs**: `glab mr list --author=@me` / `gh pr list --author @me`.
- **Awaiting your review**: `glab mr list --reviewer=@me` / `gh pr list --search "review-requested:@me"`.
- **CI red** on your MRs/PRs → flag it (→ `/flow:work:green`).
- **Cannot merge** — the forge's verdict, distinct from the pipeline: conflicts, behind base, draft, approvals missing (`detailed_merge_status`/`has_conflicts` on GitLab · `mergeable`/`mergeStateStatus`/`reviewDecision` on GitHub). Flag separately, naming the reason. Conflicts / behind-base → `/flow:work:green`; draft and approvals are yours or the reviewers' to clear.
- **Threads that need *your* reply** — **latest comment not yours**, fetched per open MR/PR (`glab api .../merge_requests/:iid/discussions` · `gh api` review threads), compared against `git.assignee` / `@me`. This — **not** the raw *unresolved* count — is the signal for `/flow:work:respond` (it **never resolves** threads, so an answered thread stays unresolved until the reviewer closes it).
- **Threads awaiting the reviewer** — unresolved, latest comment **is yours**: **informational only**, never an action for you.

Degrade: `git.cli` empty / not installed / unauthenticated / timeout → skip this layer and print one line, e.g. `(forge unavailable: gh not authenticated)`. The term MR/PR follows `git.request_term`.

## 3. Tracker layer (best-effort, via `tracker.tool`)

What you should **start or re-prioritize**. Resolve from `tracker.tool` (`acli` Jira / `gh` issues / `glab` issues / `linear` / `none`):

- **Assigned to you**: `gh issue list --assignee @me` / `glab issue list --assignee=@me` / the Jira (`acli`) or Linear equivalent (Linear via its MCP if available).
- Highlight: recently assigned, **priority changes**, and status changes that do not match your local work state.

Degrade like §2. `tracker.tool` `none`/empty → skip with one line (`(no tracker configured)`). Ticket format follows `tracker.prefix`.

## 4. Cross the three layers (the real value)

Turn the *joins* into concrete, **suggested** commands (never act):

- Ticket assigned to you with **no local work** → `/flow:feat:start <TICKET>` or `/flow:bug:start <TICKET>`.
- Local work `done`/`ship` but its ticket still open in the tracker → divergence to close out.
- Local work whose branch has an open MR/PR with **CI red or an unmergeable state** (conflicts, behind base) → `/flow:work:green`; with **threads awaiting your reply** (latest comment not yours) → `/flow:work:respond`.
- A ticket's **priority was raised** while you were on something else → call out the possible refocus.
- `related_repos` entries not `done` → the **other repo's part is still open**: surface it (`<repo>: <scope>`) and suggest `/flow:feat:start <TICKET>` in that repo. `contract_handoff` `pending` → add that the contract was never handed over; the fix is `/flow:feat:ship` §6.3 on this side first. flow only reminds; it never scans the sibling.
- Uncommitted local changes not reflected in any log/artifact → nudge toward the relevant phase.
- **Residue piling up** → `/flow:work:clean`. Cheap local check, no extra forge calls: `git worktree list` (minus the main checkout) against the works already read; a worktree whose work is `done`, or that no work folder claims, is a finished branch still holding a checkout. One line with the count, at the end, only above a handful — housekeeping, never the headline.

Suggest only. The user decides.

## 5. Output — the daily briefing (no `$ARGUMENTS`)

A short, narrative standup in three blocks, then next steps:

```
☀ Daily — <repo> · since <last-session boundary>

Yesterday / last session
  <what you were on, what was left mid-way — 2-4 lines, most recent first>

Today
  <what to resume + what the forge/tracker asks of you, ordered by urgency>

Blockers / attention
  <CI red · reviews awaiting you (latest comment not yours) · divergences · raised priorities — or "none">

Awaiting others (optional)
  <threads you already answered, waiting on the reviewer — informational, not yours to act on>

Next: <2-4 concrete flow commands>
```

- Scannable prose, not a raw dump. Mark degraded sources inline so the user knows what was **not** checked (e.g. a trailing `(tracker unavailable)` line).
- **Blockers is only what *you* must act on.** Threads you already answered go in *Awaiting others*, never in Blockers — omit that block when empty.
- No local works and no external items → say so plainly and suggest `/flow:feat:start` or `/flow:bug:start`.

## 6. "Last seen" marker (the only write)

Like `/flow:news`: a timestamp in `~/.claude/flow/daily-last-seen` (outside the repo) makes *"since last session"* precise.

- First run (no marker): derive the boundary from commits/`updated_at` (§1) and create the marker at the end.
- Update the marker **only** in the no-`$ARGUMENTS` briefing mode; untouched when answering an ad-hoc question.
- The documented exception to the read-only rule; everything else observes.
