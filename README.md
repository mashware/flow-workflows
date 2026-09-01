# flow-workflows

Guided development workflows for terminal coding agents. Instead of one big "do this task" prompt,
work moves through explicit, reviewable phases — `feat` (idea → design → build → review → ship)
and `bug` (diagnose → root cause → fix → validate → review → postmortem → ship) — plus post-deploy
monitoring and multi-agent code review. Every phase leaves an artifact on disk, so the work is
resumable, auditable, and hand-editable.

**As hands-off as you want it.** `autonomy.mode` is a dial. On `manual` every phase stops at each
decision and waits for you. On `auto` the flow runs itself — ticket, design, implementation,
review, validation, one phase chaining into the next without you typing a command — resolving the
small decisions with sensible defaults and **writing down every one it took**, so you can audit
afterwards what it chose and why. `guided` sits in between: it decides the low-risk calls, still
asks at the real ones.

What makes that safe is that the autonomy dial never moves the **hard gates**. In *every* mode,
including `auto`, flow stops and asks before: any push or MR/PR, creating a branch on an ambiguous
base, a DB schema change or migration, shipping a review that came back with high-severity
findings, and the business brief it writes just before touching code — 3-5 bullets of what you will
be able to do afterwards and what is *not* included, confirmed by you. In `manual`, commits during `build` are yours to authorize too — it leaves the work in your
tree so you can read the diff first. It goes alone; it doesn't go behind your back.

The dial cuts both ways, and that half matters just as much: `guided`/`auto` **never** ask about the
flow's own machinery — whether to launch a review panel, how many reviewers, WIP commits, continuing
to the next MR/PR of a train, or anything already decided and written down. Otherwise `auto` decays
into `manual` one reasonable-looking question at a time. And because those modes stop rarely, **every
stop opens with where you are** — ticket, phase, `MR #3 of 7`, what each MR/PR is waiting on, what
just finished, and the one thing it needs from you — before any prose. You are coming back to a pane
you left; the flow has read everything and you have read none of it.

**Stack-agnostic**: nothing is hardcoded. Each repo is configured with a `FLOW.md` at its root
(tracker, git host, test commands, review agents, observability…). Anything you leave empty is
auto-detected or asked for.

Ships a plugin for **Claude Code** and adapters for **opencode**, **Gemini CLI** and **Codex CLI**.

## Install

```
/plugin marketplace add mashware/flow-workflows
/plugin install flow@flow-plugins
```
Then configure the repo once:
```
/flow:init        # auto-detects git host, test commands, etc. and writes FLOW.md for you
```
Try without installing: `claude --plugin-dir <path>/flow-workflows/plugins/flow`.

**Other harnesses.** Run `adapters/install.sh <tool>` for opencode / Gemini CLI / Codex CLI — see
[`adapters/README.md`](adapters/README.md). Same commands and logic; only the invocation syntax
differs (`/flow:feat:start` in Claude Code and Gemini, `/flow-feat-start` in opencode/Codex).
The mirrors are **checked mechanically** on every preflight: each one parses in its harness's format,
uses that harness's invocation prefix, cites only commands and paths that exist, and `install.sh` is
run against a throwaway `HOME` to confirm the files land where that harness looks for them
([`script/adapter-smoke.py`](script/adapter-smoke.py)). ⚠️ What that cannot tell you is whether a
harness *executes* a workflow the way Claude Code does — **no harness has run them end to end**. Treat
them as a solid, verified-on-paper first cut: validate as you use them, and adjust paths if your
version differs (especially Codex, where the prompts location moves between versions).

## The two flows

A feature, end to end. Each phase gates the next and writes its artifact:

```
/flow:feat:start  PROJ-123     # read the ticket, size it, create the branch
/flow:feat:brainstorm          # options, angles, risks (optional, larger features)
/flow:feat:design              # architecture, DB, APIs, risks  → 03-design.md
/flow:feat:plan                # split into small mergeable MRs/PRs (optional)
/flow:feat:build               # implement following the design, keep a log
/flow:feat:review              # mandatory multi-agent code review
/flow:feat:validate            # tests, edge cases, integrity
/flow:feat:ship                # commit, push, MR/PR (+ pre-deploy SQL gate if DB changed)
```

A bug:

```
/flow:bug:start  PROJ-456
/flow:bug:diagnose             # reproduce, pin down what's broken
/flow:bug:investigate          # find the root cause, not the symptom
/flow:bug:fix                  # minimal fix
/flow:bug:validate             # regression test that fails before, passes after
/flow:bug:review
/flow:bug:postmortem           # lessons + areas to watch (M/L incidents)
/flow:bug:ship                 # commit, push, MR/PR (carries the postmortem summary)
```

**No ticket?** Run `/flow:feat:start` with no arguments and it drafts the work from the
conversation you just had — title, summary, criteria, the decisions you already closed while
talking — for you to confirm. No tracker required.

**You don't have to memorize the order.** `/flow:work:status` shows every open work item and its
next step, `/flow:work:resume` picks up the work tied to your current branch, and
`/flow:work:daily` gives you a standup across everything. The size classified at `start` (XS/S/M/L)
also prunes phases: an XS change goes `start → build → review → ship`. Type `/flow` (or `/`) for
autocomplete.

### When not to use it

The size dial prunes *phases*; it never says "this is not a work at all", so it is worth saying here.
**Do it by hand** when the change is one you can describe in a single sentence, touches one file,
needs nobody's review, and whose entire test story is that the existing suite either passes or it
does not: a typo in a string, a version bump, a log level, a comment. Edit, commit, done — a work
folder, a branch, an artifact trail and a review panel cost more than that change is worth, and the
fastest way to abandon a process is to feel it taxing you on a two-line fix.

It goes back to being a work as soon as **any** of these is true: it needs a ticket, or someone other
than you has to understand later why it was done, or it touches a schema, a contract, or anything
with a rollback story. Those are exactly what the artifacts and the gates buy you. Neither buys
anything on a typo.

**How much of it you drive** is one line in `FLOW.md` — `autonomy.mode`, changeable at any time:

| Mode | Decisions | Advancing to the next phase |
|---|---|---|
| `manual` *(default)* | Stops at every one | **Proposes** the next command as a one-click confirmation — never typed for you, never run unconfirmed |
| `guided` | Resolves the low-risk, unambiguous ones itself and records them; still asks at the real ones | Chains automatically |
| `auto` | Also resolves the rest, with recorded defaults | Chains automatically, without pausing |

The hard gates listed above hold in all three. → [Autonomy reference](docs/CONFIGURATION.md#autonomy)

## Commands

**Feature flow**

| Command | What it does |
|---|---|
| `/flow:feat:start` | Start a new feature: read the tracker, classify size, create the branch and initial artifact |
| `/flow:feat:brainstorm` | Generate options, angles and risks before designing |
| `/flow:feat:design` | Design the technical solution (architecture, DB, APIs, risks) before touching code |
| `/flow:feat:plan` | Split the work into small, independently mergeable MRs/PRs |
| `/flow:feat:build` | Implement following the approved design, keeping a running log |
| `/flow:feat:review` | Mandatory multi-agent code review before shipping |
| `/flow:feat:validate` | Validate tests, edge cases and integrity |
| `/flow:feat:ship` | Commit, push, open the MR/PR, offer to save domain knowledge |

**Bug flow**

| Command | What it does |
|---|---|
| `/flow:bug:start` | Start the incident flow (tracker, size, branch, initial artifact) |
| `/flow:bug:diagnose` | Reproduce the failure and pin down exactly what is broken |
| `/flow:bug:investigate` | Find the root cause, not the symptom |
| `/flow:bug:fix` | Implement the minimal fix and keep a log |
| `/flow:bug:validate` | Regression test + verification that the failure does not return |
| `/flow:bug:review` | Multi-agent code review of the fix |
| `/flow:bug:ship` | Commit, push, MR/PR for the fix |
| `/flow:bug:postmortem` | Lessons learned, areas to monitor, offer to save to domain-memory |

**Work / utilities** — cross-cutting, for both `feat` and `bug`

| Command | What it does |
|---|---|
| `/flow:init` | Wizard that generates this repo's `FLOW.md` (auto-detects, asks the minimum) |
| `/flow:config` | Show the effective `FLOW.md` config: what is set, what is empty (and its fallback), plus validation |
| `/flow:doctor` | **Environment check** — the CLIs installed *and authenticated*, the agents your config names, the hooks executable, the MCP reachable, the base branch resolvable. Read-only, quiet on success |
| `/flow:work:green` | **Mergeable loop** — the open MR/PR cannot merge (red pipeline, conflicts, behind base): triage, fix at the root, push. Never green-washes → [docs](docs/WORKFLOWS.md#mergeable-loop--flowworkgreen) |
| `/flow:work:respond` | **Review loop** — triage the MR/PR threads, debate, implement what you agreed, reply. Never resolves threads → [docs](docs/WORKFLOWS.md#review-loop--flowworkrespond) |
| `/flow:work:query` | **Query duel** — puts a data-access query on trial: fact sheet, blinded challenger, and a verdict settled by its execution plan, never by prose → [docs](docs/WORKFLOWS.md#query-duel--flowworkquery) |
| `/flow:work:watch` | **Post-deploy watcher** — monitors observability after a deploy, flags regressions, autopiloted → [docs](docs/WORKFLOWS.md#post-deploy-watcher--flowworkwatch) |
| `/flow:work:daily` | **Work assistant** — Scrum-style standup across local + forge + tracker; ask a question or get the briefing → [docs](docs/WORKFLOWS.md#work-assistant--flowworkdaily) |
| `/flow:work:status` | Summary of all open work items in `.claude/work/` |
| `/flow:work:resume` | Resume the work tied to the current branch and suggest the next step |
| `/flow:work:try` | Point the main checkout at a branch to test it (then `--back`), re-syncing the env per `git.worktree_resync` |
| `/flow:work:clean` | **Housekeeping** — sweep what finished work left behind: merged worktrees, dead branches, unarchived folders. Never deletes on a guess → [docs](docs/WORKFLOWS.md#housekeeping--flowworkclean) |
| `/flow:work:abandon` | Close a work item without shipping (discarded feature, non-bug…) |
| `/flow:save-knowledge` | Consolidate the branch's findings into the `domain-memory` store |
| `/flow:news` | What changed in the plugin since the version you last saw |

## What a work looks like on disk

One folder per work under `.claude/work/`, named `<TICKET>-<slug>` (or just `<slug>` for
ticket-less work) so concurrent works are told apart at a glance:

```
.claude/work/PROJ-123-billing-retry-window/
├── meta.json              # source of truth: phase, size, branch, MR/PRs, related repos
├── panel.json             # live state for an external reader (see below)
├── 01-context.md          # start:      ticket, size, branch, first questions
├── 02-brainstorm.md       # brainstorm: options, angles, risks
├── 03-design.md           # design:     architecture + ADR-light + external contracts
├── 04-mr-plan.md          # plan:       the MR/PR split, order and dependencies
├── 05-implementation.md   # build:      running log, deviations from the design
├── 06-review.md           # review:     findings and what was done about them
├── 07-validation.md       # validate:   tests, edge cases, integrity
├── 08-feedback.md         # respond:    one entry per review round
└── 09-ci.md               # green:      one entry per round of merge blockers
```

A bug writes `02-diagnose.md`, `03-investigation.md`, `04-fix.md`, `05-validation.md`,
`06-review.md` and, for larger incidents, `99-postmortem.md`. `/flow:work:abandon` writes
`99-abandoned.md` and moves the folder to `.claude/work/_archive/`.

Each phase reads the previous artifacts instead of starting from scratch — that's the whole point.
They are **hand-editable**: rewrite `03-design.md` and the next phase respects it. `meta.json` is
the state, and without it commands refuse to continue rather than guess.

### `panel.json` — the work, readable from outside the chat

Every stop the flow makes in the chat is also written to `panel.json`, so a reader that is not the
chat — a terminal pane, a status bar, a dashboard — can show where a work stands. The chat is a
stream; the question you actually have is a state, and with three works in flight *"which MR/PR is
this one on, is it waiting for me, and what's its link"* shouldn't need scrolling or asking:

```
PROJ-123 feat·M ⏵ validate                           15h ago   ← drawn by the reader
Billing retry window

 ⏸ #1     batch read sources                         !9977 ↗
 ▶ #2     per-event and per-recipient counters
 · #3–#6  channel map · use case · detail · route

 › Now       unit suite and the test agent over #2
 › Next      ship #2
 ⏸ Decision  confirm the MR/PR body before I create it

 ⚠ sibling-repo still needs the endpoint contract
```

The file is a list of lines, and each one says **what it is** rather than how to draw it: a `mark`
(`done` `current` `pending` `wait` `block` `info`) picks the symbol and colour, a `ref` is the label
the reader aligns into a column, and `link` is a field — never a URL pasted into the text — that the
reader shortens, makes clickable and pins to the right. Blank lines separate alignment blocks, so
the MR/PR train and the labels below it don't drag each other wide. Styles stay semantic
(`normal` `dim` `title` `accent` `ok` `warn` `error`), never colours — the reader owns the palette. Two properties make it trustworthy: it is overwritten
**whole**, so it is never half of an old state and half of a new one; and it is written **before** a
long stretch rather than after it, with an honest `updated_at` — a file written only on success
keeps showing as finished a step that in fact died halfway, whereas a stale timestamp is something
the reader can flag. It also carries the phase it is *running*, not the one `meta.json` records —
that field only advances when a phase closes, so a header drawn from it says `build` for as long as
`validate` takes. Writing the file is optional: a work without one still resolves from `meta.json`.
Full schema in [`commands/work/README.md`](plugins/flow/commands/work/README.md#paneljson-schema).

## Configuration: `FLOW.md`

A single file at the repo root describes your conventions. **Anything left empty is auto-detected
or asked for** — a repo with no `FLOW.md` still works, just with more questions.

| Section | What it configures |
|---|---|
| `tracker` | Ticket prefix, CLI, view and comment-thread commands, and optional state transitions (in-progress / done / won't-do) |
| `git` | Host and CLI, base branch, branch pattern, MR/PR sections, squash, worktrees, multi-PR trains, pre-deploy SQL gate |
| `autonomy` | How much a phase decides on its own: `manual` · `guided` · `auto` (hard gates always ask) |
| `quality` | Test / lint / static-analysis / DB commands, plus how deep review goes (`review_depth`) and your review panel |
| `agents` | Role → specialist agent map (architecture, persistence, api, security, frontend, testing…), plus how wide the parallel fan-out goes (`fanout_max`, `fanout_tool`) |
| `models` | Which model each kind of step runs with — `study` · `code` · `test` · `review` · `workers` (empty = the model you launched the command with) |
| `conventions` | Rules the code must respect (layers, patterns, prohibitions) |
| `notes` | Extra mandatory instructions injected per command |
| `domain_memory` | Whether the [`domain-memory`](https://github.com/mashware/domain-memory) MCP is available |
| `observability` | The profile `/flow:work:watch` monitors after a deploy |

**→ [Full configuration reference](docs/CONFIGURATION.md)** — every key, its default, and the
behaviors worth knowing about (review depth scaling, PR trains, worktrees, tracker transitions).

Run `/flow:init` to generate the file, `/flow:config` to see your effective config, or copy
[`plugins/flow/examples/FLOW.template.md`](plugins/flow/examples/FLOW.template.md) by hand.

`FLOW.md` is **personal config, not team config** — it mixes repo facts with your own preferences
(autonomy, the tools/agents you have installed, review depth, assignee), so **add it to your
`.gitignore`**; `/flow:init` offers to. It holds no secrets. A team that wants to share the
repo-fact subset can commit it deliberately.

## Documentation

| | |
|---|---|
| [`docs/CONFIGURATION.md`](docs/CONFIGURATION.md) | Complete `FLOW.md` reference |
| [`docs/WORKFLOWS.md`](docs/WORKFLOWS.md) | The cross-cutting workflows: `green`, `respond`, `watch`, `daily`, cross-repo tasks |
| [`plugins/flow/commands/work/README.md`](plugins/flow/commands/work/README.md) | The plugin's internal guide: principles, `meta.json` schema, size shortcuts, golden rules (`/flow:work:README`) |
| [`plugins/flow/CHANGELOG.md`](plugins/flow/CHANGELOG.md) | What changed, version by version (`/flow:news` shows you just the new part) |
| [`adapters/README.md`](adapters/README.md) | Installing on opencode / Gemini CLI / Codex CLI |

## Structure

```
flow-workflows/
├── .claude-plugin/marketplace.json     # catalog (Claude Code)
├── plugins/flow/                       # Claude Code plugin
│   ├── commands/  (feat/ bug/ work/ + init + config + news + save-knowledge)
│   ├── hooks/     (guard against pushing to the main branch + update notice on session start)
│   └── examples/FLOW.template.md
├── docs/                               # configuration and workflow reference
├── script/check.py                     # release preflight (see below)
├── script/adapter-smoke.py             # are the mirrors usable? (format · prefixes · install)
├── script/adapter-new.py               # generate a new command's three mirrors
├── RELEASING.md                        # release procedure + what the preflight enforces
└── adapters/
    ├── install.sh
    ├── opencode/  ·  gemini/  ·  codex/
```

### Before tagging a release

There is no CI here — a release is a tag on whatever is in the tree — so `script/check.py` is what
stands between a broken tree and a permanent tag. Run it, or wire it in once:

```bash
python3 script/check.py            # includes the static half of the adapter smoke test
python3 script/adapter-smoke.py     # both halves: also runs install.sh against a throwaway HOME
ln -s ../../script/check.py .git/hooks/pre-commit   # optional
```

It refuses a tree with an empty tracked file (a zero-byte `plugin.json` shipped in two releases and
kept the plugin from loading at all), any `.json` that does not parse (`hooks.json` included, which
nothing but the loader reads), a manifest version that disagrees with the newest `CHANGELOG.md`
heading, a hook that lost its executable bit, a command without frontmatter, a `.toml` that does not
parse, an embedded `json` example that does not parse, a `panel.json` example using a `mark`, `style`
or inline URL the reader would not understand, retired panel vocabulary anywhere in the tree, a
divergent copy of the shared phase preamble, and an adapter mirror that is **missing, orphaned or out
of date** — the last one read from git, since the mirrors are condensed by hand and a diff cannot
judge them. Every one of those is something that has actually shipped or nearly shipped.

What none of those could catch is a mirror that exists, is current, and is still unusable — wrapped in
a format its harness does not read, teaching the *other* harness's invocation prefix, or citing a
command or path that is not there. [`script/adapter-smoke.py`](script/adapter-smoke.py) checks that,
and its static half runs inside `check.py`. Run it whole before a release: the second half executes
`adapters/install.sh` for each harness against a throwaway `HOME` and verifies the files land where
that harness looks for them, which needs none of the three harnesses installed.

When you add a command, [`script/adapter-new.py`](script/adapter-new.py) writes its three mirrors for
you — the mechanical part (wrapper per harness, invocation prefix rewritten in either direction, file
in the right place) with the body marked for you to condense. `--from <file>` wraps a body you already
condensed once, for all three.

The full release procedure, and the conventions those checks encode, are in
[`RELEASING.md`](RELEASING.md).

## What it does not ship (on purpose)

To stay agnostic, `flow` **does not bundle concrete agents or a review skill** (those are
language/project specific): you name them in your `FLOW.md` and they must exist on your machine.
It does ship the anti-push-to-`master`/`main` hook, which is generic git. Optional dependencies
that improve the flow when present: the `domain-memory` MCP, your git host CLI, and an issue
tracker CLI. Without them, those specific steps degrade; the rest works.

## License

MIT.
