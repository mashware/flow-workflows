---
description: The one entry an orchestrator launches for an unattended run — asks it why it was launched and routes to the phase that answers it
argument-hint: "[ticket]"
---

# `/flow:work:run`

Load the `flow:flow-core` skill first (shared rules: `FLOW.md` step 0, autonomy modes and hard gates, how a stop reads, the live panel, `00-summary.md`) — skip if it is already in this session's context. **Models: this command runs with the model it was launched with (no `models` key).**

**Panel words are closed** — `mark`: `done` · `current` · `pending` · `wait` · `block` · `info`; `style`: `normal` · `dim` · `title` · `accent` · `ok` · `warn` · `error`. Anything else is dropped by the reader in silence: the panel still paints, and nobody is told.

**In `unattended`, before this phase's first step, read flow-core §2.1 whole — from its heading to the next section, unless it is already in your context whole; having read parts of it does not count** — the orchestrator command, the question stop and the way its answer comes back are all in it, and a phase that reads only part of it skips them.

The command an orchestrator puts in its launch line, for every run of every ticket. It does no work
of its own: it asks the orchestrator why this run exists and hands the run to the phase that
answers it. `$ARGUMENTS` is the ticket, optional — the orchestrator's `ticket` order is the source
of truth, and an argument that disagrees with it is ignored and named in the log.

## 1. Pre-flight

- Effective FLOW configuration per flow-core §0. `autonomy.mode` is not `unattended` → say this
  command only routes unattended runs, name the mode and where it came from, and end: in any
  other mode a person is the router (`/flow:next`).
- `autonomy.orchestrator_cmd` empty → flow-core §2.1: no phase runs.
- Run `<cmd> why`. It fails, or prints anything but `start`, `answer`, `review`, `pipeline` or
  `merged` → print what it returned and its stderr in the §3 header and end. No closing order: an
  orchestrator that cannot say why it launched the run cannot take one either.
- Run `<cmd> ticket --json` and keep `number`, `title`, `base` and `kind` (`kind` absent → `feat`).
  Find the work: the `meta.json` under `.claude/work/` whose `ticket` equals `number` (archive
  excluded). It fails or is empty → `blocked` (flow-core §2.1).

## 2. Route

| `why` | The work | Run |
|---|---|---|
| `start` | none for this ticket | `/flow:feat:start <number>` — `/flow:bug:start <number>` when `kind` is `bug` |
| `start` | exists, `pending` set | a stop whose `ask` never landed, or a crash after it: set `pending` to `null` and run `pending.resume` from its pre-flight — the question is reached and asked again |
| `start` | exists, nothing pending | the next phase its `phase` and `size` name — the same table `/flow:work:resume` §4 uses. A work folder the orchestrator restored from a study made elsewhere enters here, and is never started a second time |
| `answer` | `pending` set | apply `<cmd> answer` as flow-core §2.1 "The answer comes back" says, then `pending.resume` at `pending.resume_at` |
| `answer` | nothing pending | `blocked` — there is no question for that answer to decide |
| `merged` | exists | the entry of `meta.json.mrs` whose `status` is `published` (the only one: one MR/PR per run) becomes `merged`; set `meta.json.base` to the `base` just read; the next startable MR/PR → `/flow:feat:build` (`/flow:bug:fix` for a bug work, which has one); none left, or a work with no `mrs` (one MR/PR) → `done`, the summary naming the ticket as complete |
| `merged` | none | `blocked` — nothing of this ticket was published from here |
| `review` · `pipeline` | any | `blocked` — not supported yet in `unattended`; the reason says so |

The phase you hand the run to is unattended too: it reads §2.1, chains as `auto` and makes the
run's one closing order. This command makes none of its own except the `blocked` and `done` of the
table above.

## 3. Close

Nothing to write here beyond the routing above — the phase it hands to owns the artifacts, the
panel and the closing order. When the route ended the run itself (`blocked`, `done`), publish the
panel with that `attention` (flow-core §4) and print the §3 header.
