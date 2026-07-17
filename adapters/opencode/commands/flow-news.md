---
description: Show what changed in the flow plugin since the version you last saw
---

# flow-news

Show the user what is new in the `flow` plugin. Reads the changelog installed alongside the adapter and prints the entries between the version they last saw and the installed one. Read-only, except for a small "last seen" marker so the next run starts where this one ended.

## 1. Locate the data

- **Changelog**: read `~/.claude/flow/CHANGELOG.md` (the `install.sh` copies it there). Each shipped version is a section headed `## vX.Y.Z …`; the top may carry an `## [Unreleased] …` block — **ignore it** here, it is not a shipped version.
- **Installed version**: there is no `plugin.json` in the adapter, so treat the **newest shipped `## vX.Y.Z` header** in the changelog as the installed version (skip any `## [Unreleased]` block above it).
- **Last-seen marker**: `~/.claude/flow/news-last-seen` (one line, e.g. `v0.11.0`). Missing dir/file → first run.

If `~/.claude/flow/CHANGELOG.md` is missing, fall back to the tracker's releases:

- GitHub setup → `gh release list --repo mashware/flow-workflows` and `gh release view <tag> --repo mashware/flow-workflows`.
- GitLab setup → `glab release list --repo mashware/flow-workflows`.
- If neither CLI is available, point the user to <https://github.com/mashware/flow-workflows/releases> and stop.

## 2. Decide the range from `$ARGUMENTS`

- **empty** → every shipped entry strictly newer than the last-seen version, up to and including the installed one. **First run** (no marker) → show only the installed version's entry and mention `/flow-news all` for the full history.
- **`vX.Y.Z`** → every entry newer than that version.
- **`N`** (an integer) → the last `N` shipped entries.
- **`all`** → every entry in the changelog.

Compare versions by **semver** (numeric `major.minor.patch`), never string order (`v0.9.0` < `v0.10.0`).

## 3. Show

Print the matching sections **newest-first**, each with its header and notes, lightly reflowed for the terminal (do not dump raw markdown noise — keep it readable). If nothing matches (already current), say: *"You're on the latest — `vX.Y.Z`, nothing new since you last checked."* End with a one-line pointer to the full GitHub Releases for the richest notes: <https://github.com/mashware/flow-workflows/releases>.

## 4. Update the marker

If `$ARGUMENTS` was **empty** (the "catch me up" case), write the installed version to `~/.claude/flow/news-last-seen` (create the dir if needed) so the next no-arg run starts from here. If `$ARGUMENTS` was an explicit query (`vX.Y.Z`, `N`, or `all` — ad-hoc lookups), **do not move the marker**.

## Note — pull-only on this adapter

The Claude Code plugin has a SessionStart hook that surfaces a one-line nudge the first session after the installed version changes, so users know to run this command. **The adapters have no such hook** — there is no proactive notify here. On opencode, `/flow-news` is **pull-only**: run it on demand to see what changed.
