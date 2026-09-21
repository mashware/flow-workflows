# The review bench

Everything else in this repository checks **shape**. `script/check.py` proves the adapters match
their sources byte for byte and that a cited path exists; the hook tests pin behaviour that is
deterministic by construction. None of it can answer the only question a change to
`/flow:feat:review` is ever about: did it find more defects, fewer, or the same ones more
expensively.

This suite answers that one, and nothing else. **Scope is `review`.** The rest of the chain is out
deliberately: review is where ground truth is cheap to build and where the open decisions are — the
completeness sweep, the data-access duel, the idiom audit, the 150/600/1500 thresholds, the
sensitive-surface bump. Every one of them was argued from judgement and has never been checked
against an outcome.

## What a case is

A case is a small repository the scaffold builds, a flow work parked at `build`, and a branch with
a diff whose outcome is known before the review runs. Two kinds, and **both are mandatory**:

- **A seeded defect** (`seeded-*`): the bug sits at a known `file:line` and the review must raise it.
  The scored grader is recall, and nothing else.
- **A clean diff** (`clean-*`): there is no defect, and any must-fix finding is a false positive.
  Without this half the bench rewards the noisiest review, and noise is what makes people stop
  reading reviews at all.

The seeded defects come from **this repository's own history**, not from imagination. Every one is
the shape of a failure the CHANGELOG records: a value recorded after the mutation instead of before
(v0.66.0's `reviewed_sha`), a failing call reported as a clean result, a filter that drops the item
it exists to carry, several writers on one shared key, a threshold that is code in one place and a
literal in another. A defect we invent is a defect shaped like something we were already looking for.

## How a case is graded

Deterministic graders carry the score — `regex` over a file, nothing a judge model decides. The
prompt asks for `verdict.md` at the repository root, one line per must-fix finding as
`path:line — problem` or the word `none`, and that file is what the graders read. It is asked for
in the prompt rather than taken from `06-review.md` on purpose: the baseline arm writes no flow
artifact, and a grader the baseline cannot pass pushes that arm to zero and inflates the delta the
bench exists to read.

`06-review.md` is still graded, as an **indicator outside the score** (`arm: with-only`): the three
computed lines of §8 — `Review tier`, `Effective size`, `Review path`. They say the round measured
its tier rather than narrating it, which is exactly what v0.66.0 made checkable. That grader reads
the **transcript**, not the file: an eval run is refused every write under `.claude/`, so the
artifact the phase composes never reaches disk, and the phase reports it as a limit of the run. The
transcript carries what it wrote either way.

No `llm` grader scores anything here. A judge introduces the variance this bench exists to measure,
and it changes the measuring stick exactly when the model changes — the one moment the bench has to
stay fixed.

## The prompt runs the command, and the baseline arm gets the same words

Each case's prompt opens with the literal `/flow:feat:review` and then states the task in plain
words. That is not decoration: inside an eval run the agent has no way to invoke a plugin command
on its own — the harness expands a prompt that *is* a command, and a model asked in prose to "use
the review command" reads files instead and never reaches it. The plain-words half is what the
no-plugin arm answers, so both arms are asked for the same thing and `Δ` means something.

## Running it

The suite needs a shell, so it needs a sandbox backend: `bubblewrap` and `socat` on Linux (`apt
install bubblewrap socat`), otherwise every run is refused before it starts.

```bash
# one case, one arm, once — for iterating on a case or a grader
claude plugin eval ./plugins/flow --case seeded-record-after-mutation \
  --runs 1 --ablation none --scaffold --allow-tools Bash Write Edit --no-publish

# the suite, as the release runs it
claude plugin eval ./plugins/flow --scaffold --allow-tools Bash Write Edit \
  --trust-plugin --no-publish --max-cost-usd 120 --threshold 0.5 \
  --json evals/results/latest.json
```

`--scaffold` runs each case's `fixture.sh` as you, outside the agent's sandbox. It is a fixture
builder in this repository's own tree; read it before you pass the flag, the way you would for any
suite you did not write.

**`--threshold` is set below the observed range of the base, never at the `1.0` default.** A
threshold that goes red at random is a threshold everyone learns to ignore.

## Reading two runs against each other

`claude plugin eval` scores a case as the mean of its runs. A mean over three runs of a
non-deterministic agent moves on its own, so the comparison is made with:

```bash
python3 script/bench-compare.py <base.json> <candidate.json>
python3 script/bench-compare.py --save <result.json> --model <model>   # record a baseline
```

It reports the **median** of each case's runs, the **range the base's own runs spanned**, and prints
`—` for any difference that lands inside it. A delta inside the base's own range is not a delta.

Baselines live in `baselines/<version>-<model>.json`, one per plugin version and model. When a new
model ships, run the suite with `--model` and everything else frozen — same plugin version, same
fixtures, same `FLOW.md` — and compare against the baseline for the model it replaces.

## Two tiers of case, and why the second one is not here yet

Every case in the suite today is tagged `xs`, and that is a limit rather than a choice. At XS the
command resolves to the built-in `code-review` alone: no panel, and §3.5's completeness sweep is
M/L only. So the layers this bench was built to judge — the panel, the sweep, the data-access duel,
the idiom audit — **did not run once** in the 48 sessions of the first baseline. That is the first
reason the two arms came out level.

The second tier is `deep`: M-sized diffs with `quality.reviewers` populated, where the panel and the
sweep run by themselves, the defect is split across files, and the contract it breaks lives in
`03-design.md` rather than three lines above the bug. Those cases cost what they exercise —
estimate 4–7 $ and 10–15 minutes per with-plugin run against 1–2 $ without — so the suite splits:

```bash
claude plugin eval ./plugins/flow --tag xs    ...   # iterating: ~50 min, ~$47
claude plugin eval ./plugins/flow --tag deep  ...   # a release, or a change to the panel
```

Each tier keeps its own baseline, so a comparison is always the same cases against themselves.

## Adding a case

1. `mkdir -p <kind>-<what>/graders` — `seeded-` or `clean-`, named after the failure, not the fix.
2. `fixture.sh`: source `../_lib/fixture.sh`, call `fx_repo <TICKET> <title> <size> <what the
   implementation log says>`, write the diff, call `fx_commit`. Build it once locally and note the
   **line number** the defect lands on.
3. `case.yaml`: `schema_version`, `name`, `tags: [review, seeded|clean]`, `runs: 3`,
   `expected_outcome` (for humans — the ground truth in one sentence), and
   `context: {scaffold_script: fixture.sh}`.
4. `prompt.md`: the shape every other case uses. Do not reword the `verdict.md` contract; the
   graders read it.
5. `graders/`: one scored grader for a seeded case (the `file:line` window), two for a clean one
   (no `file:line` at all, and the word `none`), plus the `artifact-facts` indicator.
6. Run it once with `--runs 1 --ablation none` and read the report before you commit it. A case
   that fails for a reason other than the defect is a case that measures the reason.

Nothing here may depend on one ecosystem's tools: the fixture is a repository, and what a
repository is built with is `FLOW.md`'s business. `script/check.py` enforces that over this
directory exactly as it does over the rest of the plugin.

## What the first run said

`baselines/0.67.0-rc.1-claude-opus-5.json`, the base every later run is read against: 48 sessions,
52 minutes, $47.27, threshold 0.5.

| | with the plugin | without it |
|---|---|---|
| cases at or above the threshold | 8/8 | 8/8 |
| suite score | 0.96 | 1.00 |
| seeded defects found | 15 of 16 run-cases | 16 of 16 |
| clean diffs kept clean | 3/3 | 3/3 |
| per run | $1.57 · 4.5 min | $0.40 · 1.9 min |

Mean Δ **−0.04**. One case, `seeded-divergent-threshold`, missed the defect in one run of three with
the plugin and never without it. The `artifact-facts` indicator passed in 23 of 24 with-plugin runs,
so the phase does compose the computed lines it is supposed to compose.

**The reading is about these fixtures before it is about the command.** Eight XS diffs of a single
file, each with a docstring stating the contract the code breaks, is a defect an unguided review
finds too — so what this suite has measured so far is that it cannot yet tell the two apart at 3.9×
the cost. That is what a base run is for, and it names the next cases: larger diffs, across files,
with the contract in `03-design.md` rather than three lines above the bug. Nothing was retired and
no threshold moved.

## Two limits of the harness, and what they cost

Both are the eval runner's, not the plugin's, and both are visible in any run's transcript.

**A granted shell does not work inside an eval run on Linux.** Every command comes back
`apply-seccomp: write /proc/self/setgroups (nested userns is capability-restricted)`: the run is
already confined, and the Bash tool's own sandbox cannot nest inside it. The same command works in
a plain `claude -p` session on the same machine, so it is the eval's confinement and nothing here.
What it costs the bench is the CLI path: `flow bundle` and `flow tier` never run, the review reads
the files instead of the diff, and the tier is the prose fallback. **It does not cost the score** —
the recall and false-positive graders read what the review concluded, and a review that reached the
seeded line by reading files reached it. The cases keep asking for `Bash` so the day the runner
allows it the bench measures the path a user actually gets, and the fixture keeps installing the
CLI for the same reason.

**Writes under `.claude/` are refused**, so `06-review.md`, `panel.json` and `meta.json` are never
written. The phase says so in its own report. The indicator graders read the transcript instead,
and the score never depended on those files.

## What this does not measure

The fixtures leave `quality.test`, `static_analysis` and `style_fix` empty, so the local quality
gates of §7 are out of scope — a gate that shells out adds a failure mode that is not the review's.
No case exercises a multi-MR/PR train, a re-review over a previous `reviewed_sha`, or a panel with
`quality.reviewers` set. Those are the next cases to write, not claims this suite already makes.
