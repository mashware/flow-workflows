# The cross-cutting workflows

The `feat` and `bug` flows take a ticket to an open MR/PR. These seven workflows cover what
happens **around** that line: getting the MR/PR merged, settling an argument about a query,
watching the deploy, remembering where you were, and tasks that don't fit in one repo. All of them work for both `feat` and `bug` work,
and none of them advance `meta.json.phase` — they are loops you run as many times as the round
requires.

- [Mergeable loop — `/flow:work:green`](#mergeable-loop--flowworkgreen)
- [Review loop — `/flow:work:respond`](#review-loop--flowworkrespond)
- [Query duel — `/flow:work:query`](#query-duel--flowworkquery)
- [Post-deploy watcher — `/flow:work:watch`](#post-deploy-watcher--flowworkwatch)
- [Work assistant — `/flow:work:daily`](#work-assistant--flowworkdaily)
- [Housekeeping — `/flow:work:clean`](#housekeeping--flowworkclean)
- [Cross-repo tasks](#cross-repo-tasks)

## After `ship`, before `merge`

`ship` opens the MR/PR, but it is rarely merged untouched. Two different signals arrive in that
window, and each has its own loop:

| | Signal | Loop |
|---|---|---|
| **Machine** | The MR/PR cannot be merged: red pipeline, conflicts, behind base | `/flow:work:green` |
| **Human** | Reviewers commented and a discussion started on the code | `/flow:work:respond` |

Because reviewers wait for a green, mergeable MR/PR, `green` usually runs first.

---

## Mergeable loop — `/flow:work:green`

```
/flow:work:green [mr-iid-or-url]
```

**Green is not the same as mergeable.** A pipeline can be perfectly green on an MR/PR that is
impossible to merge — and reporting *that* as done is its own kind of lie. So `green` reads both
halves of the state via `gh`/`glab`:

- the **failing pipeline jobs** and their logs
- the **forge's own merge verdict** — conflicts, branch behind base, draft, missing approvals,
  unresolved threads

### What it does

1. **Triages every blocker** into one of: lint/style · test failure · type/build · flaky/infra ·
   quality-gate · conflict or behind-base · human.
2. **Fixes the machine ones at the root**, delegating to the flow's sub-agents and reproducing
   locally with your `quality.*` commands so it isn't guessing on CI's dime.
3. **Treats conflicts as a code decision, not a git chore**: it merges the base into the branch
   (no history rewrite, no force-push by default) and resolves each conflict on its merits,
   reading what the base changed against what your design intended.
4. **Routes human blockers instead of working around them** — it names them and points you at the
   right place (threads → `respond`).

### What it never does

It **never green-washes**: no blind reruns, no disabling or skipping a check, no "resolving" a
conflict by discarding the other side. This is the counterpart to `respond` never resolving a
thread.

Pushes, reruns and any base integration are **hard gates** you confirm. Repeatable — one run per
round of blockers, logged to `09-ci.md`.

---

## Review loop — `/flow:work:respond`

```
/flow:work:respond [mr-iid-or-url]
```

Reviewers comment, a discussion starts on the code, and only after you agree do you know whether
to change something, defer it, or hold your ground. That phase is what `respond` runs.

### What it does

1. **Fetches the open threads** via `gh`/`glab`.
2. **Triages each one**: question · nitpick · change request · design debate · out-of-scope ·
   obsolete.
3. **Drafts a response per thread.** For design debates it argues from **the rationale the flow
   already recorded** — the ADR-light in `03-design.md`, the recorded challenges, the knowledge sources
   — instead of re-deriving it. That recorded "why" is exactly the ammunition a good review reply
   needs, and it is the reason the earlier phases bother to write it down. With one exception, and
   it is deliberate: a **performance objection about a query** is not answered from the record at
   all. It goes to `/flow:work:query` and comes back with a plan (see below).
4. **Implements the agreed changes** reusing the `build`/`fix` mechanics, with the same review
   gate for non-trivial diffs.

### What it never does

It **never resolves a thread**. It tells you which ones are ready and leaves that call to you.
Replies and pushes are **hard gates** you confirm.

Repeatable — one run per review round, logged to `08-feedback.md`.

---

## Query duel — `/flow:work:query`

```
/flow:work:query                       # every query the current work added or changed
/flow:work:query src/Foo/BarRepo.php   # or a file, a pasted query, a reviewer's objection
```

**A query is not approved by prose, it is approved by its plan.** Correctness is visible in the
code; cost is not. Cost lives in the execution plan, and the plan depends on facts that are nowhere
in the diff — which index exists, in what column order and **direction**, the type and collation of
both sides of a join, how many rows a key really has. So a panel of reading reviewers approves a
query that reads a hundred thousand rows to return fifteen, and approves it faster when the design
wrote down a plausible reason for it.

### What it does

1. **States the facts before anyone argues** — call site and how often it runs, filter, order *with
   its direction*, the bound and whether it is per key or global, both sides of every join with
   their real types and collations, heavy columns, expected rows per key **and where that number
   came from**, and the indexes that actually exist, read from the schema rather than the ORM
   mapping.
2. **Sends in a challenger, blinded to the design's rationale** — the same blinding as the idiom
   audit in `review`, for the same reason: a plausible written justification is what makes a
   reviewer stop looking. It walks a twelve-item checklist of the classic failures (an order the
   index cannot serve, join keys that silently lose their index, a per-key bound faked with a global
   limit, heavy columns read in a pass that only decides, N+1 and the batch that grew too big, work
   the engine could have done, a trick no test can pin) and must name the **data scenario** that
   triggers each attack.
3. **Judges with numbers.** The main agent decides — never a subagent. No number, no win: an attack
   with no plan and a defence with no plan are the same thing, and it goes to measurement or is
   recorded unresolved. No dogma either way: "N small queries is an N+1" and "one batched query
   always wins" are both preferences until measured. And **the objector's variant gets measured next
   to yours**, especially when your theory says it will lose.
4. **Measures when the schema cannot settle it** — a data set shaped like production (`data.volumes`),
   three runs per variant, plan next to time, plus a `keys served` column, because a variant can be
   the fastest and still answer for 40 of the 50 keys asked, which makes it wrong rather than fast.
5. **Returns one recommendation**, the number behind it, then only the costs that would change the
   decision. A verdict that hedges in three directions reads as "I don't know" and makes you decide
   twice.

### Where it runs by itself

- `/flow:feat:review` §3.6 and `/flow:bug:review` §3.5 — **any size, XS included**, whenever the diff
  adds or changes a query. It is not a depth tier: it is a category no other reviewer owns, and a
  one-line change to an `ORDER BY` is exactly the change whose cost is invisible.
- `/flow:work:respond` §4.G — a reviewer objects to a query. The reply is a plan, not an argument.
- `/flow:feat:design` — the **Access paths** table: filter, order, bound and supporting index decided
  before the query is written, when adding an index is still cheap.
- `/flow:feat:build` and `/flow:feat:validate` — the plan recorded as the query is written, and
  measured against real volumes before shipping, because a green suite proves rows and never plans.
- `/flow:bug:investigate` — when the symptom is slowness, the root cause is a plan until proven
  otherwise, and several of its causes leave the code untouched, where `git blame` cannot find them.

### What it never does

It **judges, it does not patch**: the verdict goes back to the phase that asked, which implements it
with its own gates. Creating, seeding or dropping a database is a **hard gate in every autonomy
mode**, and it never points at production. And it **never reports an unmeasured plan as measured**:
"schema only" and "not measured, here is the question left open" are legitimate verdicts — the
functional test database, with its handful of fixture rows, proves nothing about a plan at all.

Configured by the optional [`data`](CONFIGURATION.md#data) section. With it empty the duel still
runs, on the schema alone, and says so.

---

## Post-deploy watcher — `/flow:work:watch`

```
/flow:work:watch PROJ-123 30m
```

Shipping is not the end: the interesting part is the first half hour in production. `watch`
babysits the deploy — it waits for the release to go live, sets a baseline, then monitors the
signals **scoped to your change** for the window you gave it, comparing against baseline and
alerting the moment something regresses.

- **What it watches**: error logs, APM latency and error rate, slow SQL, queues and dead-letters,
  monitors — taken from the `observability` profile in `FLOW.md`, or auto-discovered if that's
  empty.
- **Baseline**: the preceding window plus the same weekday of the previous week, using ratios
  rather than raw counts, so low traffic doesn't read as an improvement.
- **It shows you a monitoring plan first** — which signals, which queries, which thresholds — for
  you to confirm or adjust before it starts.
- **It runs autopiloted**: it schedules its own cycles and you can walk away. If something goes
  red it interrupts, points you at the evidence, and offers `/flow:bug:start`.
- **It never touches code or production.** State lives in `monitor.md`, so on harnesses without
  in-session scheduling it also works driven by cron.

---

## Work assistant — `/flow:work:daily`

```
/flow:work:daily                                    # full briefing
/flow:work:daily what's left on the payment work?   # just that question
```

Come back the next morning and ask *"what was I working on?"*. `daily` is the Scrum-style standup:
it combines **three sources** and, crucially, reasons about where they *cross*.

| Source | What it reads |
|---|---|
| **Local** | `.claude/work/` + git — your work folders, phases, branch divergence |
| **Forge** | Your open MRs/PRs, the ones awaiting your review, red CI, MRs/PRs that cannot merge, unresolved threads (via `git.cli`) |
| **Tracker** | Tickets assigned to you, priority changes (via `tracker.tool`) |

Crossings become concrete suggested commands: a ticket assigned to you with no local work →
`/flow:feat:start`; a red pipeline or a conflicted branch → `/flow:work:green`; open threads →
`/flow:work:respond`.

With no argument you get a **three-block briefing** — yesterday · today · blockers. With a
question, it answers just that.

**Read-only.** Its only write is a "last seen" marker, like `/flow:news`. Every external source is
**best-effort**: if a CLI is missing or unauthenticated it degrades with a one-line note about
what it couldn't check, and never blocks.

Unlike `/flow:work:status` (a technical control table) and `/flow:work:resume` (one branch),
`daily` is cross-cutting and narrative. It complements them; it doesn't replace them.

---

## Housekeeping — `/flow:work:clean`

```
/flow:work:clean --dry-run     # show what a sweep would do, touch nothing
/flow:work:clean               # sweep, after showing you the list
```

Every finished work leaves three things behind: the **worktree** it was built in, the **local
branch**, and its **`.claude/work/` folder**. Today they're only cleaned up if you say yes at the
end of `ship` or `abandon` — and in a train that prompt never fires, because an intermediate
MR/PR doesn't set `phase: done`. Weeks later the repo is carrying full checkouts of branches that
merged long ago.

`clean` is the periodic sweep. It takes all three inventories at once, decides each branch's fate
from **the forge's verdict** rather than from age or a guess, and shows you the whole list before
removing anything.

| Verdict | How it's established | What happens |
|---|---|---|
| `merged` | The forge's merged MR/PR list — two calls total, joined locally | Candidate |
| `merged`, squashed | Same, or a local patch-equivalence check (squash-merged branches are ancestors of nothing, so `git branch --merged` misses every one) | Candidate |
| `open` | The forge's open list | Left alone |
| `empty` | Never diverged from the base | Candidate |
| `unknown` | Anything else | **Left alone** |

What it never does: no `--force`, no `git branch -D` on a locally-inferred verdict, nothing to the
remote, and it **archives** work folders rather than deleting them. A merged branch whose worktree
still has uncommitted edits is reported, not removed. And because deletion is the one action that
can destroy work that exists nowhere else, **`autonomy.mode` does not authorize it** — `auto`
confirms the list like everyone else.

`.claude/work/_archive/` is outside the sweep; `--purge-archive <N>d` is a separate, opt-in pass
that only touches folders already committed to git — the untracked ones are the only copy there
is, so it lists them instead.

---

## Cross-repo tasks

flow is per-repo, but tasks often aren't — a backend change plus its consumer, an API plus its
client. The part living in the sibling project is the part that gets forgotten.

- `/flow:feat:start` and `/flow:bug:start` ask whether the task touches other repos — **only when
  there's a signal**, never as a routine question — and record them in
  `meta.json.related_repos`.
- `design` and `plan` refine that list as the shape of the work becomes clear.
- `ship` reminds you of the part still pending in the sibling repo.
- `ship` also **hands over the contract**, which is the part a reminder alone never fixes. Your
  literal contracts live in `03-design.md`, inside git-ignored `.claude/work/` — so they die with
  the session and never reach the other repo, which starts from `scope`: one line of prose. It
  then invents the routes, payload keys and error codes you already decided, and the disagreement
  surfaces at integration. So when a sibling consumes a surface declared here, `ship` offers to
  publish those **literal** shapes to the shared anchor both sides already have — the tracker
  ticket — after showing you the exact text. Acceptance criteria and ADRs don't cross: they're
  this repo's *how*.
- The consuming side actually looks where it was published: the contract is a **ticket comment**,
  and `gh issue view N` / `glab issue view N` / `acli jira workitem view KEY` print only the
  description — so `/flow:feat:start` §2.1 and `/flow:bug:start` §1.1 read the **comment thread**
  as part of reading the ticket (via `tracker.comments_cmd`, or `--comments` derived from
  `tracker.tool`). That is not only about contracts: the thread is where scope gets cut, criteria
  get sharpened and the real reproduction gets pasted. When the thread can't be read, `start` says
  so in one line — "could not read the comments" and "there were no comments" are opposite facts.
- The consuming side picks it up: `/flow:feat:start` §3.6 copies a published contract block into
  `01-context.md` as **received, not negotiable**, and `design` carries it in verbatim instead of
  re-deriving it. If it looks wrong, that's a conversation with the other side — designing a
  better version locally just ships two contracts for one ticket. And when a ticket points at
  another repo with *no* published contract, `start` says so out loud, because an absent contract
  is otherwise invisible and gets filled in with invention that reads like knowledge.
- `daily`, `resume` and `status` keep it visible so it doesn't fall off the map — including
  `contract not handed over`, so a pending handoff is something you see rather than remember.
- And when you started *before* the other side shipped, `/flow:work:resume` §2.5 re-reads the
  thread and shows only what's new since `01-context.md` was written. It appends, never rewrites:
  if a new comment contradicts something already in `03-design.md` or already built, it names the
  collision and hands you the decision in every autonomy mode instead of "fixing" it locally.
- In ticket-less mode the affected repos also go into the issue drafts, so the scope is recorded
  in the tracker rather than only on your disk.

flow only **notes and reminds**. It never scans, reads or touches the other repo — that would
mean guessing at another project's conventions, which is exactly what a per-repo `FLOW.md` exists
to avoid.

---

## Going deeper

The plugin ships its own internal guide with the principles behind these phases — the size
shortcuts, the `meta.json` schema, the design-contract anchoring, the model tiering, the golden
rules. Read it with `/flow:work:README`, or in
[`plugins/flow/commands/work/README.md`](../plugins/flow/commands/work/README.md).
