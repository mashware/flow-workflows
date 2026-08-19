# Releasing, and the conventions the preflight enforces

There is no CI here. A release is a tag on whatever is in the tree, so everything below is
either a step you take by hand or a check `script/check.py` makes on your behalf. Run the
preflight before every release — and ideally as a pre-commit hook:

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
2. **Add the changelog entry** at the top of `plugins/flow/CHANGELOG.md` as `## vX.Y.Z — <title>  ·  <date>`.
   The heading must match the manifest version exactly — `/flow:news` reads the changelog while the
   loader reads the manifest, so when the two drift the release notes describe a version nobody is
   running. The preflight checks this.
3. **Open a PR, squash-merge it.** The commit subject is the changelog title plus `(vX.Y.Z)`.
4. **Tag by publishing the release**: `gh release create vX.Y.Z --title "<title>" --notes "…"`.
   The GitHub release notes are the canonical, richest version; the bundled changelog is the
   summary that travels with the plugin.

`.claude-plugin/marketplace.json` carries no version, so there is nothing to bump there.

## Keeping the adapters in step

`plugins/flow/` is the source of truth. `adapters/opencode/`, `adapters/codex/` and
`adapters/gemini/` mirror all 31 commands — about 14k lines against the plugin's 5.7k — and there
is **no generator**: they are condensed by hand, roughly 15% shorter, with subsections merged, and
each in its own harness's invocation syntax (`/flow-feat-ship` for opencode and Codex,
`/flow:feat:ship` for Gemini CLI). That condensation is deliberate, which is why a mechanical diff
cannot verify them.

So the rule is a discipline, and the preflight holds you to it: **edit a plugin command and its
three mirrors in the same commit.** `check_adapter_freshness` reads git — a plugin command whose
newest commit is later than a mirror's, or one edited in the working tree while its mirror is
untouched, fails the preflight.

When an edit genuinely does not need mirroring — it touched something each harness spells its own
way — record it in [`script/adapter-parity.exceptions`](script/adapter-parity.exceptions) with the
plugin command's current sha. The entry is scoped to that one commit: the next real edit moves the
sha, the exception stops matching, and the check speaks up again.

## What else the preflight will not let you ship

Each of these exists because it shipped broken once:

- **No empty tracked file.** A zero-byte manifest went out in two releases and broke the plugin.
- **Every tracked `.json` parses**, `hooks/hooks.json` included — nothing but the loader reads it,
  so a stray comma there ships hooks that are simply absent.
- **Every `.toml` parses** (the Gemini adapter's 31 commands). On Python < 3.11 there is no
  `tomllib` and the run says out loud that it skipped them.
- **Hooks are executable.** A lost `chmod +x` is a guard that silently stops guarding.
- **Command frontmatter** exists, is closed, and has a `description`.
- **Embedded `json` blocks parse**, and the `panel.json` examples use only marks and styles the
  reader knows — a typo there loses the line's column and no parse check would catch it.
- **Command parity in both directions**: every plugin command mirrored in all three adapters, and
  no adapter file for a command the plugin no longer has.
- **The shared phase preamble is identical** across the 18 phase commands. It is copied by hand on
  purpose (a command prompt must be self-contained), so the check names the odd copy out. The
  `Models` and `Autonomy` blocks are excluded: their wording legitimately varies per command.
- **No retired `panel.json` vocabulary** (`Right now:`, `Waiting on you:`, grouping the train
  `under Left`) anywhere in the plugin or the adapters. The panel's reader knows `mark` and `ref`;
  those labels render as prose and quietly lose the column — this is where the spec drifted once.
