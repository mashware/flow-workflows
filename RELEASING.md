# Releasing, and the conventions the preflight enforces

A release is a tag on whatever is in the tree, so everything below is either a step you take by
hand or a check `script/check.py` makes on your behalf. CI runs the same checks on every push and
pull request (`.github/workflows/preflight.yml`), but a green tree is cheaper to keep than to
restore — run the preflight before every release, and ideally as a pre-commit hook:

```bash
ln -s ../../script/check.py .git/hooks/pre-commit
```

## The release itself

```bash
git switch --create <short-slug> --no-track origin/main
# … the work …
python3 script/check.py                # must be green before the version bump means anything
```

1. **Bump `version`** in `plugins/flow/.claude-plugin/plugin.json` (semver: a behaviour change
   users will notice is a minor, a correction is a patch).
2. **Add the changelog entry** at the top of `plugins/flow/CHANGELOG.md` (convention below).
   The heading must match the manifest version exactly — `/flow:news` reads the changelog while the
   loader reads the manifest, so when the two drift the release notes describe a version nobody is
   running. The preflight checks this.
3. **Open a PR, squash-merge it.** The commit subject is the changelog title plus `(vX.Y.Z)`.
4. **Tag by publishing the release**: `gh release create vX.Y.Z --title "<title>" --notes "…"`.
   The GitHub release notes are the canonical, richest version; the bundled changelog is the
   summary that travels with the plugin.

`.claude-plugin/marketplace.json` carries no version, so there is nothing to bump there.

### Changelog convention

Every entry is headed `## vX.Y.Z — <title>  ·  <date>` and **opens with a `**In short**`
paragraph followed by 3–5 one-line bullets**, then the prose. The short form is what `/flow:news`
prints by default — header line plus the In-short bullets, per version — so those bullets have to
stand on their own; `/flow:news full` prints the whole entry. An older entry without an In-short
block falls back to its first paragraph.

## Keeping the adapters in step

`plugins/flow/` is the source of truth; `adapters/opencode/`, `adapters/codex/` and
`adapters/gemini/` are **generated from it** by `script/adapter-build.py`. Every file under
`opencode/commands/`, `codex/prompts/`, `gemini/commands/flow/` and each `<harness>/CORE.md` is
written from the plugin commands and `plugins/flow/skills/flow-core/SKILL.md`. The prose is not
rewritten; only the wrapper, the invocation prefix, `$ARGUMENTS` → `{{args}}` for Gemini, the
pointer to `~/.claude/flow/CORE.<tool>.md`, and a legend after the title mapping the Claude Code
primitives to that harness (the `LEGEND` dict in the script — see `adapters/README.md`).

So the rule is mechanical: **edit the plugin, run `python3 script/adapter-build.py`, commit both.**
The script rewrites every mirror and deletes orphans; `--check` renders everything in memory and
exits non-zero on a mirror that is missing, stale or orphaned, and the preflight runs it. A mirror
edited by hand is undone by the next build — there is nothing to condense and nothing to keep in
parity by discipline.

`script/adapter-smoke.py` still checks the *result* is usable: the wrapper its harness reads, that
harness's prefix throughout, every command and path cited real, and `install.sh` landing the files
(commands, `CORE.<tool>.md`, changelog, manifest) where the harness and `/flow:news` look.

## What else the preflight will not let you ship

`script/check.py` runs these, in order. Each exists because it shipped broken once:

- **No empty tracked file.** A zero-byte manifest went out in two releases and broke the plugin.
- **The manifests** — `plugin.json` has `name` and `version`, `marketplace.json` has `plugins`, and
  every plugin source it advertises exists on disk.
- **Every tracked `.json` parses**, `hooks/hooks.json` included — nothing but the loader reads it,
  so a stray comma there ships hooks that are simply absent.
- **Hooks are executable.** A lost `chmod +x` is a guard that silently stops guarding.
- **`version` equals the newest changelog heading.**
- **Command frontmatter** exists, is closed, and has a `description`.
- **Every `.toml` parses** (the Gemini mirrors). On Python < 3.11 there is no `tomllib` and the
  run says out loud that it skipped them.
- **Embedded `json` blocks parse**, and the `panel.json` examples use only marks and styles the
  reader knows — a typo there loses the line's column and no parse check would catch it.
- **The adapters are generated and current** — `adapter-build.py --check`: no mirror missing,
  stale, or orphaned.
- **The mirrors are usable, not just present** — `adapter-smoke.py --static-only`: each parses in
  its harness's wrapper (opencode frontmatter · Codex none · Gemini TOML), every `/flow…` invocation
  uses that harness's prefix, and every command and path it cites exists.
- **The flow-core skill is present** (`plugins/flow/skills/flow-core/SKILL.md`, `name: flow-core`)
  **and no command carries a copy of its blocks.** Those blocks used to be pasted into 18 commands
  and drifted; a command that repeats one points at the skill instead.
- **The config key table is current** — `config-keys.py --check`: `docs/CONFIGURATION.md`'s table is
  generated from `FLOW.template.md`.
- **No retired `panel.json` vocabulary** (`Right now:`, `Waiting on you:`, grouping the train
  `under Left`) anywhere in the plugin or the adapters. The panel's reader knows `mark` and `ref`;
  those labels render as prose and quietly lose the column — this is where the spec drifted once.

## CI

`.github/workflows/preflight.yml` runs on every push and pull request: `script/check.py`,
`script/adapter-smoke.py` whole (static + install against a throwaway `HOME`), both generators'
`--check` (`adapter-build.py`, `config-keys.py`), and the two hook tests
(`script/tests/push-guard.sh`, `script/tests/notify-update.sh`). It is the same list as below, so a
red CI is a tree the pre-tag steps would have rejected.

## Before the tag, run it whole

```bash
python3 script/adapter-smoke.py
bash script/tests/push-guard.sh
bash script/tests/notify-update.sh
```

The half of the smoke test the preflight skips is the slow one: it executes `adapters/install.sh`
for each harness against a throwaway `HOME` and checks the files land where that harness reads
them, in the expected number, with the `CORE.<tool>.md` every command opens and the changelog
`/flow-news` needs. It needs none of the three harnesses installed, and it is the only thing that
would notice `install.sh` copying into a path that no longer exists. The two hook tests exercise
the push guard and the SessionStart update notice the same way, against a throwaway `HOME`.
