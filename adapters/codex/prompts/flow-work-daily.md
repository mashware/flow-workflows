# `/flow-work-daily $ARGUMENTS`

**Step 0**: read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step specifies. Regarding external sources (tracker, forge, `domain_memory`): each one is **best-effort** — if a CLI is missing/unauthenticated, an MCP fails, or a call takes more than ~3 s, continue without that source and note it in a single line; **never block**. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

Your **work assistant**: the Scrum-style daily standup. Answers *"what was I working on?"*, *"what's left?"*, *"what should I pick up today?"* by combining three sources — your **local** work state, the **forge** (open MRs/PRs, reviews, CI), and the **tracker** (assigned/re-prioritized tickets). Unlike `/flow-work-status` (a technical control table) and `/flow-work-resume` (one branch), this is a cross-cutting, narrative briefing.

**Read-only.** It never touches `meta.json`, git, the forge, or the tracker. Its only write is the "last seen" marker in §6, exactly like `/flow-news`.

## Modes

- **No `$ARGUMENTS`** → full daily briefing (§5 three-block format).
- **`$ARGUMENTS` is a question** (e.g. `/flow-work-daily what's left on the payment work?`) → answer *that* using the same sources, without printing the full briefing. Do not move the marker in this mode (it's an ad-hoc lookup, like `/flow-news vX.Y.Z`).

## 1. Local layer (always — the base of the briefing)

- `git branch --show-current` → the **active** work.
- `ls -1 .claude/work/` (ignore `_archive`); read each `meta.json`.
- Determine the **"last session" boundary**: the marker from §6 if present; otherwise derive it from the most recent commit date and the newest `updated_at` across works.
- Order works by `updated_at` (most recent first). The most recently touched is the *"what were we on?"* answer.
- Repo pulse: `git log --oneline --since="<last-session boundary>"` (fallback `-10`) and `git status --short` for uncommitted changes.
- Per work, gather: `phase`, `phases_done`, MRs and their `status` (from `meta.json.mrs`), and what was **left pending** — synthesized from the most recent artifact(s) (`NN-*.md`) and `meta.notes`, not re-derived from code.

## 2. Forge layer (best-effort, via `git.cli`)

What the team is asking of you **right now**. Resolve the CLI from `git.cli` (or infer from `git.host`); "you" is `git.assignee` if set, else the CLI's own identity (`@me`).

- **Your open MRs/PRs**: `glab mr list --author=@me` / `gh pr list --author @me`.
- **Awaiting your review**: `glab mr list --reviewer=@me` / `gh pr list --search "review-requested:@me"`.
- **CI red** on your MRs/PRs → flag it (links to `/flow-work-green`).
- **Threads that need *your* reply** — those whose **latest comment is not yours** (someone left you something unanswered), fetched per open MR/PR (`glab api .../merge_requests/:iid/discussions` · `gh api` review threads) and compared against your identity (`git.assignee` / `@me`). This — **not** the raw *unresolved* count — is the signal for `/flow-work-respond`: because `/flow-work-respond` **never resolves** threads, a thread you already answered stays unresolved until the reviewer closes it, so counting *unresolved* would flag your own answered threads forever.
- **Threads awaiting the reviewer** — unresolved but whose latest comment **is yours** (you replied; the ball is in the reviewer's court): **informational only**, never an action for you.

Degrade: if `git.cli` is empty / not installed / unauthenticated / times out, skip this layer and print one line, e.g. `(forge unavailable: gh not authenticated)`. The term MR/PR follows `git.request_term`.

## 3. Tracker layer (best-effort, via `tracker.tool`)

What you should **start or re-prioritize**. Resolve from `tracker.tool` (`acli` Jira / `gh` issues / `glab` issues / `linear` / `none`):

- **Assigned to you**: `gh issue list --assignee @me` / `glab issue list --assignee=@me` / the Jira (`acli`) or Linear equivalent (Linear via its MCP if available).
- Highlight: recently assigned, **priority changes**, and status changes that don't match your local work state.

Degrade like §2. If `tracker.tool` is `none`/empty, skip with one line (`(no tracker configured)`). Ticket format follows `tracker.prefix`.

## 4. Cross the three layers (the real value)

The briefing's value is in the *joins* — turn them into concrete, **suggested** commands (never act):

- Ticket assigned to you with **no local work** → suggest `/flow-feat-start <TICKET>` or `/flow-bug-start <TICKET>`.
- Local work `done`/`ship` but its ticket is still open in the tracker → divergence to close out.
- Local work whose branch has an open MR/PR with **CI red** → `/flow-work-green`; with **threads awaiting your reply** (latest comment not yours) → `/flow-work-respond`.
- A ticket's **priority was raised** while you were on something else → call out the possible refocus.
- Uncommitted local changes not reflected in any log/artifact → nudge toward the relevant phase.

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

- Keep it scannable prose, not a raw dump. Mark degraded sources inline so the user knows what was **not** checked (e.g. a trailing `(tracker unavailable)` line).
- **Blockers is only what *you* must act on.** Threads you already answered (waiting on the reviewer) go in *Awaiting others*, never in Blockers — omit that block when empty.
- If there are no local works and no external items, say so plainly and suggest `/flow-feat-start` or `/flow-bug-start`.

## 6. "Last seen" marker (the only write)

Like `/flow-news`: persist a timestamp to `~/.claude/flow/daily-last-seen` (outside the repo) so *"since last session"* is precise across sessions.

- On first run (no marker), derive the boundary from commits/`updated_at` (§1) and create the marker at the end.
- Update the marker **only** in the no-`$ARGUMENTS` briefing mode; leave it untouched when answering an ad-hoc question.
- This single write is the documented exception to the read-only rule; everything else observes.
