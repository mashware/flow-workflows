# flow-workflows

Guided `feat` / `bug` workflows for terminal coding agents: a ticket reaches an open MR/PR through explicit, reviewable phases, not one big prompt.
For developers running Claude Code (or opencode, Gemini CLI, Codex CLI) on real repos with tickets, reviewers and a deploy.
You get named phases, an artifact on disk after each one, hard gates the agent never crosses alone, and an autonomy dial from "ask me everything" to "run it and record what you decided".

## Quickstart

```
/plugin marketplace add mashware/flow-workflows
/plugin install flow@flow-plugins
/flow:init      # writes FLOW.md for this repo — auto-detects, asks the minimum
/flow:next      # routes you to init, resume or status, depending on where you are
```

Your first feature:

```
/flow:feat:start PROJ-123   # read the ticket, size it (XS/S/M/L), create the branch
/flow:feat:design           # architecture, DB, APIs, risks → 03-design.md
/flow:feat:build            # implement following the design, keep a log
/flow:feat:review           # multi-agent code review (mandatory)
/flow:feat:ship             # commit, push, open the MR/PR — after you confirm the preview
```

No ticket? `/flow:feat:start` with no arguments drafts the work from the conversation you just had.

## The two chains

```
feat  start → brainstorm → design → plan → build → review → validate → ship
                (M/L)              (M/L)  └─── repeats per MR/PR of a train ───┘

bug   start → diagnose → investigate → fix → validate → review → postmortem → ship
                                                                   (M/L)

after ship, before merge:  green ⟲   pipeline red / conflicts / behind base
                           respond ⟲ reviewer threads: triage, debate, change, reply

size prunes:  XS  start → build → review → ship     S  + design (abridged) + validate
              M/L full chain; plan splits the work into stacked MR/PRs
```

## Commands you will use every day

| Command | What it does |
|---|---|
| `/flow:next` | Entry point — routes to init, resume or status depending on where you are |
| `/flow:feat:start` | Read the tracker, classify size, create the branch and initial artifact |
| `/flow:feat:build` | Implement following the approved design, keeping a log |
| `/flow:feat:review` | Mandatory multi-agent code review before shipping |
| `/flow:feat:ship` | Commit, push, open the MR/PR, offer to save domain knowledge |
| `/flow:bug:start` | Start the incident flow (tracker, size, branch, initial artifact) |
| `/flow:bug:fix` | Implement the minimal fix and keep a log |
| `/flow:work:status` | All open work items and their next step |
| `/flow:work:resume` | Resume the work tied to the current branch |
| `/flow:work:green` | Mergeable loop — the MR/PR cannot merge: triage, fix at the root, push. Never green-washes |
| `/flow:work:respond` | Review loop — triage the threads, debate, implement what you agreed, reply. Never resolves threads |

## Everything else

| Command | What it does |
|---|---|
| `/flow:feat:brainstorm` | Options, angles and risks before designing |
| `/flow:feat:design` | Architecture, DB, APIs, risks — before touching code |
| `/flow:feat:plan` | Split the work into small, independently mergeable MR/PRs |
| `/flow:feat:validate` | Tests, edge cases and integrity |
| `/flow:bug:diagnose` | Reproduce the failure and pin down what is broken |
| `/flow:bug:investigate` | Find the root cause, not the symptom |
| `/flow:bug:validate` | Regression test that fails before, passes after |
| `/flow:bug:review` | Multi-agent code review of the fix |
| `/flow:bug:postmortem` | Lessons learned, areas to monitor (M/L incidents) |
| `/flow:bug:ship` | Commit, push, MR/PR for the fix (carries the postmortem summary) |
| `/flow:init` | Wizard that generates this repo's `FLOW.md` |
| `/flow:config` | Effective `FLOW.md`: set vs empty (and its fallback), plus validation |
| `/flow:doctor` | Environment check — CLIs installed *and authenticated*, agents, hooks, MCP |
| `/flow:work:query` | Query duel — fact sheet, blinded challenger, verdict by execution plan |
| `/flow:work:watch` | Post-deploy watcher — monitors observability, flags regressions |
| `/flow:work:daily` | Standup across local + forge + tracker; ask a question or get the briefing |
| `/flow:work:try` | Point the main checkout at a branch to test it (then `--back`) |
| `/flow:work:clean` | Sweep merged worktrees, dead branches, unarchived folders. Never deletes on a guess |
| `/flow:work:abandon` | Close a work item without shipping |
| `/flow:save-knowledge` | Consolidate the branch's findings into the knowledge store (`knowledge.save`, or `KNOWLEDGE.md`) |
| `/flow:news` | What changed in the plugin since the version you last saw |

## Autonomy

`autonomy.mode` in `FLOW.md`, changeable at any time:

| Mode | Decisions | Next phase |
|---|---|---|
| `manual` *(default)* | Stops at every one | Proposed as a one-click confirmation, never run unconfirmed |
| `guided` | Resolves low-risk ones and records them; asks at the real ones | Chains automatically |
| `auto` | Also resolves the rest, with recorded defaults | Chains without pausing |

Hard gates — the flow stops and asks in **every** mode:

1. Any push or MR/PR creation (all of `ship`).
2. Creating a branch when the base is ambiguous.
3. A DB schema change or migration.
4. Shipping a review with high-severity findings.
5. The business brief before touching code — what you get afterwards, and what is *not* included.

Symmetrically, `guided`/`auto` never ask about the flow's own machinery (panels, reviewer counts, WIP commits, the next MR/PR of a train). → [CONFIGURATION §autonomy](docs/CONFIGURATION.md#autonomy)

## What a work looks like on disk

One folder per work under `.claude/work/`, named `<TICKET>-<slug>` (or `<slug>` when ticket-less):

```
.claude/work/PROJ-123-billing-retry-window/
├── 00-summary.md          # ≤15-line handoff, read first by every phase
├── meta.json              # source of truth: phase, size, branch, MR/PRs, related repos
├── panel.json             # live state for an external reader (below)
├── 01-context.md          # ticket, size, branch, first questions
├── 02-brainstorm.md       # options, angles, risks
├── 03-design.md           # architecture + ADR-light + external contracts
├── 04-mr-plan.md          # the MR/PR split, order and dependencies
├── 05-implementation.md   # running log, deviations from the design
├── 06-review.md           # findings and what was done about them
├── 07-validation.md       # tests, edge cases, integrity
├── 08-feedback.md         # respond: one entry per review round
└── 09-ci.md               # green: one entry per round of merge blockers
```

A bug writes `02-diagnose.md`, `03-investigation.md`, `04-fix.md`, `05-validation.md`, `06-review.md` and, on M/L, `99-postmortem.md`. `abandon` writes `99-abandoned.md` and moves the folder to `_archive/`.

Artifacts are **hand-editable**: rewrite `03-design.md` and the next phase respects it. `meta.json` is the state; without it, commands refuse to continue rather than guess.

**Work you decide not to do does not evaporate.** Every "idea for a separate ticket", out-of-scope piece, unmitigated risk, unchecked edge case and postmortem prevention action becomes a record in `meta.json`, not just a line in an artifact that gets archived unread. The phases that park them ask nothing. `ship` triages the whole set **once**, at the end, with one question per item: *do it* (which opens the tracker issue and offers to start it), *not worth it*, or *later*. Whatever is still open when the MR/PR is created is named in its description, so a reviewer can see what was consciously left out. `status`, `daily` and `next` keep surfacing the undecided ones — including from `_archive/`, because a finished work is exactly when its deferrals become invisible.

**`panel.json`** makes the work readable from outside the chat: every stop is written there too, so a pane or dashboard can show the MR/PR train with links, what runs now, what comes next, whether it waits on you, and any blocker. Each line says *what it is* (`mark`: `done` `current` `pending` `wait` `block` `info`); the reader owns symbols and colours. Overwritten whole, and written *before* a long stretch with an honest `updated_at`, so a step that died halfway never shows as finished. It carries the phase *running*, not the one `meta.json` records. Schema: [work/README](plugins/flow/commands/work/README.md#paneljson-schema).

## Configuration: `FLOW.md`

One file at the repo root describes your conventions. Anything left empty is auto-detected or asked for — a repo with no `FLOW.md` still works, with more questions.

| Section | What it configures |
|---|---|
| `tracker` | Ticket prefix, CLI, view and comment-thread commands, state transitions |
| `git` | Host and CLI, base branch, branch pattern, MR/PR sections, squash, worktrees, trains, pre-deploy gate |
| `autonomy` | `manual` · `guided` · `auto` (hard gates always ask) |
| `quality` | Test / lint / analysis / DB commands, `review_depth`, review panel, `respond_max_rounds` |
| `agents` | Role → specialist agent map, fan-out width (`fanout_max`, `fanout_tool`) |
| `models` | Model per kind of step — `study` · `code` · `test` · `review` · `workers` |
| `data` | How to read a query's execution plan and the real size of the hot tables |
| `conventions` | Rules the code must respect |
| `notes` | Extra mandatory instructions per command |
| `knowledge` | Knowledge sources by role — `search`, `stage`, `read_staging`, `save` — any MCP ([`domain-memory`](https://github.com/mashware/domain-memory), `codegraph`…), CLI or skill |
| `observability` | The profile `/flow:work:watch` monitors after a deploy |

`/flow:init` writes a compact `FLOW.md` with only the keys you set, and offers to git-ignore `FLOW.md` and `.claude/work/`. It is personal config, not team config ([why](docs/PHILOSOPHY.md#personal-config-not-team-config)). Reference: [CONFIGURATION](docs/CONFIGURATION.md).

## Token budget

- The shared rules live in the `flow-core` skill, loaded once per session; a command file carries only its phase.
- Every phase reads `meta.json` and `00-summary.md` first and opens a full artifact only on demand.
- `quality.review_depth: light` runs only the base code-review — no panel, reinforcements or skeptics.
- `agents.fanout_max` caps every parallel round (default 4); what the cap drops is reported.
- The review output prints its cost: subagents launched, tier and effort.

## Other harnesses

`adapters/install.sh <tool>` installs the same commands for opencode, Gemini CLI and Codex CLI; only the invocation syntax differs (`/flow:feat:start` vs `/flow-feat-start`).
The mirrors are **generated** from the plugin commands by `script/adapter-build.py` and checked mechanically on every preflight (format, prefix, cited paths, install location).
They have **not** been executed end to end in those harnesses — validate as you use them. → [adapters/README](adapters/README.md)

## Documentation

| | |
|---|---|
| [CONCEPTS](docs/CONCEPTS.md) | Glossary — every term, with where it is specified |
| [PHILOSOPHY](docs/PHILOSOPHY.md) | Why it is built this way (short) |
| [DESIGN](docs/DESIGN.md) | The rationale behind every rule |
| [CONFIGURATION](docs/CONFIGURATION.md) | Complete `FLOW.md` reference |
| [WORKFLOWS](docs/WORKFLOWS.md) | `green`, `respond`, `query`, `watch`, `daily`, `clean`, cross-repo tasks |
| [work/README](plugins/flow/commands/work/README.md) | Internal guide: principles, schemas, size shortcuts, golden rules |
| [CHANGELOG](plugins/flow/CHANGELOG.md) | What changed, version by version |
| [adapters/README](adapters/README.md) | Installing on opencode / Gemini CLI / Codex CLI |
| [RELEASING](RELEASING.md) | Release procedure and what the preflight enforces |

## Structure

```
flow-workflows/
├── .claude-plugin/marketplace.json   # catalog (Claude Code)
├── .github/workflows/preflight.yml   # CI: the checks below, on every PR
├── plugins/flow/
│   ├── commands/      feat/ bug/ work/ + next, init, config, doctor, news, save-knowledge
│   ├── skills/flow-core/             # shared rules, loaded once per session
│   ├── hooks/         push guard · update notice
│   └── examples/FLOW.template.md
├── docs/              CONCEPTS · PHILOSOPHY · DESIGN · CONFIGURATION · WORKFLOWS
├── script/check.py                   # release preflight
├── script/adapter-build.py           # generates the adapter mirrors
├── script/adapter-smoke.py           # are the mirrors usable?
├── script/tests/                     # hook tests
├── RELEASING.md
└── adapters/          install.sh · opencode/ · gemini/ · codex/
```

## Before tagging a release

```bash
python3 script/check.py              # preflight: manifest, JSON/TOML, hooks, frontmatter, mirrors (static)
python3 script/adapter-smoke.py      # also runs install.sh against a throwaway HOME
bash script/tests/push-guard.sh      # the push guard's cases
bash script/tests/notify-update.sh   # the update-notice hook's cases
```

CI runs the same four on every PR. The preflight refuses what has shipped broken before: an empty tracked file, unparsable JSON or TOML, a manifest version out of step with `CHANGELOG.md`, a hook without its executable bit, a stale or unusable mirror. → [RELEASING](RELEASING.md)

## What it does not ship (on purpose)

No agents and no review skill — those are stack-specific; you name yours in `FLOW.md`. Two generic hooks ship: a guard against pushing to `master`/`main`, and an update notice at session start. Optional dependencies (a knowledge source such as `domain-memory` or `codegraph`, your git host CLI, a tracker CLI) improve specific steps; without them those steps degrade and the rest works.

## License

MIT.
