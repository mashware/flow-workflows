# Contributing

Flow is a set of markdown commands and a handful of shell hooks. There is no build step and no
runtime: what ships is what is in the tree, so a contribution is read the way the agent will read
it. That makes the bar for prose the same as the bar for code.

Before anything else: [README](README.md) for what the plugin is,
[PHILOSOPHY](docs/PHILOSOPHY.md) for why it is shaped this way, and
[work/README](plugins/flow/commands/work/README.md) for the internal contracts a command has to
honour.

## What we want

- **A worked example for a stack.** A complete `FLOW.md` plus the specialist agents `review` asks
  for, under `plugins/flow/examples/<stack>/`, with a README saying what to change for the
  neighbouring stack — the shape is `examples/symfony/`, which is the only one so far. The plugin
  ships no agents on purpose ([why](docs/PHILOSOPHY.md#stack-agnostic-and-what-that-costs)); a
  worked example is the mitigation, and a second stack is the highest-value thing you can send.
- **A harness actually run end to end.** The opencode, Gemini CLI, Codex CLI, Hermes Agent and zcode mirrors are
  generated and checked mechanically, and `adapters/README.md` says plainly that nobody has run a
  full chain in them. A report saying *"I ran `feat:start → ship` on Codex CLI and here is what
  broke"* is worth more than a patch.
- **A case for the review bench.** `plugins/flow/evals/` scores what a review *found*, not what
  it looked like, and eight cases is where it starts. The most valuable addition is a **seeded
  defect from a failure that actually happened** — one you hit, with the diff that hid it — or a
  **clean diff** a review of yours reported a blocker on. `plugins/flow/evals/README.md` says what
  a case is made of; the ground truth is the part only you have.
- **A real work's `.claude/work/` folder**, scrubbed of anything private, as a worked example of
  what the artifacts look like when the flow is used in anger.
- **A bug report with the artifact that shows it.** `meta.json`, `panel.json` and the phase artifact
  say more than a description of what you saw.

## What we do not want

Stated as plainly as the README states what the plugin does not ship, and for the same reasons:

- **Agents or a review skill inside `plugins/flow/`.** They are language- and project-specific.
  Examples, yes; defaults, no.
- **A default model.** Flow runs on four harnesses whose model tiers do not line up; naming one
  vendor's would be wrong on three of them.
- **A stack-specific hook.** The two that ship (push guard, update notice) work in any repo. A hook
  that assumes a test runner, a language or a directory layout belongs in your own config.
- **A tool name outside a detection list.** The plugin may teach the agent to *recognise* eleven
  ecosystems — `/flow:init` does exactly that, between its `stack-detection` markers — and a command
  may say "auto-discover from Makefile / npm / composer / Gradle / dotnet". What none of them may do
  is assume one: a line naming a single ecosystem's tools anywhere else under `plugins/`, or any
  ecosystem at all under `bin/`, is a dependency on that stack, and the preflight refuses it. The
  tool name belongs in a `FLOW.md` key, where each repo writes its own. `examples/` is exempt: being
  one stack's answer is the whole point of a worked example.
- **A new `FLOW.md` key** to configure something the flow can detect, derive from another key, or
  decide well by default. Every key costs a paragraph in the template, a row in CONFIGURATION, a
  branch in `init`, a row in `config`, a check in `doctor`, and a reader deciding whether it applies
  to them.

## How a change lands

1. **Edit the plugin, never the mirror.** `plugins/flow/` is the source of truth;
   `adapters/opencode/`, `adapters/codex/`, `adapters/gemini/`, `adapters/hermes/` and the two
   in-package mirrors (`plugins/flow/codex-skills/`, `plugins/flow/zcode-commands/`) are generated. Run
   `python3 script/adapter-build.py` and commit both — a mirror edited by hand is undone by the next
   build. → [RELEASING §Keeping the adapters in step](RELEASING.md#keeping-the-adapters-in-step)
2. **A hook or CLI change ships with its test.** Under `script/tests/`, in the shape of the five
   that are there, and wired into `.github/workflows/preflight.yml`. The preflight refuses a hook
   that no test file names; `bin/cli.mjs` and `script/bench-compare.py` are under the same rule by
   convention, because what they parse — a harness's answer, a `FLOW.md` key, another tool's result
   document — is exactly what no reader checks by eye.
3. **Version and CHANGELOG move together.** `plugins/flow/.claude-plugin/plugin.json`'s `version`
   must equal the newest heading in `plugins/flow/CHANGELOG.md`; the preflight refuses the drift,
   because `/flow:news` reads the changelog while the loader reads the manifest.
4. **Run the preflight before you open the PR** — the six commands in
   [README §Before tagging](README.md#before-tagging-a-release). CI runs the same six, so a red CI
   is a tree the release steps would have rejected anyway.

Releases are cut by the maintainer; [RELEASING](RELEASING.md) is the procedure.

## Testing a change before it ships

A release here is a tag on whatever is in the tree, and the preflight has no test suite behind it:
it checks that the tree would *load*, not that the flow still *works*. So a change that alters what
a phase does gets run on a real repo before it is tagged — and every way of doing that already
exists, it was simply written nowhere.

**Claude Code, from your own checkout.** The plugin loads straight from the branch:

```bash
claude plugin validate ./plugins/flow      # the same validation a marketplace submission runs
claude --plugin-dir ./plugins/flow         # then /reload-plugins after each edit
```

A local `--plugin-dir` plugin takes precedence over the installed one of the same name for that
session, so you can exercise a branch without uninstalling the release you use every day.

**Claude Code, for someone who should not have to clone.** `claude --plugin-url <url-to.zip>` loads
a plugin from an archive for one session — a CI artifact of `plugins/flow/`, for instance.

**opencode, Gemini CLI, Codex CLI, Hermes — from a branch, with nothing published.** npm resolves a
git spec, so the installer runs straight out of the branch:

```bash
npx github:mashware/flow-workflows#<branch> install codex
```

**From npm, once there is a release candidate.** `npx flow-workflows@next` — see
[RELEASING §A release candidate](RELEASING.md#a-release-candidate). `latest` never moves for an rc.

### What "tested" means for a change to the flow itself

A green preflight says the tree loads. For anything that changes what a phase does — a new command,
a CLI subcommand, a rule a phase now enforces — the bar is **one real work driven start to ship on
a repo that is not this one**. `examples/symfony/` names the obvious candidate, and the fact that
its stack is one the plugin must not know about is what makes it the right test rather than a
convenient one.

**For a change to `/flow:feat:review` there is a second bar, and it is a number.** The bench under
`plugins/flow/evals/` runs that command over fixtures whose outcome is known — a seeded defect at a
known `file:line`, a clean diff where any blocker is a false positive — and scores what came back.
Run it against the baseline for the version you started from, and put the delta table in the PR:

```bash
claude plugin eval ./plugins/flow --scaffold --allow-tools Bash Write Edit --no-publish
python3 script/bench-compare.py plugins/flow/evals/baselines/<version>-<model>.json <result>.json
```

A pass added to that command without a case that shows it finding something is a pass nobody can
ever retire — which is the situation the bench exists to end. Reading it is three rules, all in
[`evals/README.md`](plugins/flow/evals/README.md): the median decides, the base's own range is the
noise floor, and a threshold at `1.0` is a threshold everyone learns to ignore.


## How we write

- **An issue is *Problem / Proposal / Files*.** The problem states what a user runs into, with the
  evidence — a grep, a count, a stop the flow made. The proposal is specific enough to implement
  from. The files list is the blast radius, so the reviewer can see it before reading a diff.
- **A CHANGELOG entry leads with the situation, not the feature.** *"Fifteen agents inherited a
  model nobody had chosen for them"*, not *"add model key resolution"*. Header, an `**In short**`
  paragraph, 3–5 bullets, then the prose. → [RELEASING §Changelog convention](RELEASING.md#changelog-convention)
- **Prose in English, in the register of the file you are editing.** The docs argue; the command
  files instruct. Neither is a bullet dump.
- **No vendor model names in the tree.** Model choice is `FLOW.md`'s, per repo and per harness.
