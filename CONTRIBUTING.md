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
- **A harness actually run end to end.** The opencode, Gemini CLI and Codex CLI mirrors are
  generated and checked mechanically, and `adapters/README.md` says plainly that nobody has run a
  full chain in them. A report saying *"I ran `feat:start → ship` on Codex CLI and here is what
  broke"* is worth more than a patch.
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
- **A new `FLOW.md` key** to configure something the flow can detect, derive from another key, or
  decide well by default. Every key costs a paragraph in the template, a row in CONFIGURATION, a
  branch in `init`, a row in `config`, a check in `doctor`, and a reader deciding whether it applies
  to them.

## How a change lands

1. **Edit the plugin, never the mirror.** `plugins/flow/` is the source of truth;
   `adapters/opencode/`, `adapters/codex/` and `adapters/gemini/` are generated. Run
   `python3 script/adapter-build.py` and commit both — a mirror edited by hand is undone by the next
   build. → [RELEASING §Keeping the adapters in step](RELEASING.md#keeping-the-adapters-in-step)
2. **A hook change ships with its test.** Under `script/tests/`, in the shape of the three that
   are there, and wired into `.github/workflows/preflight.yml`. The preflight refuses a hook that
   no test file names.
3. **Version and CHANGELOG move together.** `plugins/flow/.claude-plugin/plugin.json`'s `version`
   must equal the newest heading in `plugins/flow/CHANGELOG.md`; the preflight refuses the drift,
   because `/flow:news` reads the changelog while the loader reads the manifest.
4. **Run the preflight before you open the PR** — the five commands in
   [README §Before tagging](README.md#before-tagging-a-release). CI runs the same four, so a red CI
   is a tree the release steps would have rejected anyway.

Releases are cut by the maintainer; [RELEASING](RELEASING.md) is the procedure.

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
