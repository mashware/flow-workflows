# Design rationale — why flow's rules are what they are

The command prompts under `plugins/flow/commands/` say **what** to do. This document keeps the
**why**: the reasoning behind each rule and, where one exists, the incident that produced it. It is
for maintainers who want to change a rule without re-learning its lesson, and for users who want to
know why the flow stops where it stops.

Every reason comes from two sources: the original, uncondensed command prompts, and the narrative
entries in `plugins/flow/CHANGELOG.md`, which record the incidents version by version (cited as
`v0.NN.0`). Nothing is reconstructed from memory; a rule with no recorded incident gets only its
reasoning.

Organisation is by **theme**, not by command. Each rule is one bold line, then the reasoning, then
*Now:* — where it lives. "flow-core §N" is the shared skill `plugins/flow/skills/flow-core/SKILL.md`,
which now carries the preamble once copied by hand into every phase command; "work/README" is
`plugins/flow/commands/work/README.md` (principles and the `meta.json`/`panel.json` schemas); a bare
`feat:ship §6.3` is that command's numbered section; "CONFIGURATION" is `docs/CONFIGURATION.md`.

---

## 1. Why phases and artifacts on disk

**The flow orchestrates what already exists; it does not replace it.** Its job is to persist context
across phases, stop each step from starting from scratch, and enforce a review gate before closing.
*Now:* work/README "Principles".

**One folder per ticket, numbered artifacts, all hand-editable.** The folder — not the chat — is the
record: that is what makes a work resumable, auditable after an unattended run, and correctable
(rewrite `03-design.md` by hand and the next step obeys it).
*Now:* work/README "Principles", "Golden rules" 3.

**If the implementation invalidates the design, go back to design.** `review` and `validate` read
`03-design.md` as truth; two significant deviations, one overturned ADR decision, or a primitive built
under another name ("vocabulary drift") mean the design lies and everything downstream judges against
a lie. Same for `bug:fix` against the investigation, and for `green`/`respond` when a failure shows the
design was the mistake: fix the artifact before the code.
*Now:* feat:build §4.1, bug:fix §4.1, work:green §5, work:respond §6.

**Ask everything at once, before starting.** Open questions that affect the design go in one
`AskUserQuestion`; "inventing answers the user would later have to correct is worse than asking".
*Now:* feat:start §3, feat:brainstorm §5.

**Reuse before creating.** `design` inventories what exists first; every new piece in the design
implicitly claims "I found nothing that fits". Not forcing a poor fit — not adding out of habit.
*Now:* feat:design §3–§4.

**Fit + YAGNI, bias "remove, not add".** Every defensive mechanism (guard, retry, lock, fallback,
cache, flag…) needs evidence from the code and `domain-memory` — never textbook patterns — that the
scenario can happen *here* and is needed *now*. Anchored three times (design challenger, design table,
review audit) because the natural tendency is to add too many defences.
*Now:* work/README "Principles"; feat:design §5–§6; feat:review §4; bug:review §4; feat:plan §2.

**Challenge the design and the root cause before executing.** A challenger attacks the design
(fit/need first, then fragile assumptions, simplification, operation, and the idiom of each ADR row —
false dichotomies, "manual-sounding" rationales) and the investigation (a more probable cause, gaps in
the evidence chain, symptom mistaken for cause). Unanswered `high` findings block: "applying a fix on
an incorrect root cause is the primary way incidents reappear". Finding nothing is a good result.
*Now:* feat:design §6, bug:investigate §5.

**The business brief comes before any code and stops in every mode.** Three to five bullets of what
the user will be able to do and what is *not* included — the last point to fix scope before there is a
diff, since scope creep "is invisible in code review once mixed in with everything else". Anything
outside the brief goes back through the user; for bugs, expanded fixes are the primary cause of
collateral regressions.
*Now:* feat:build §2/§2.4, bug:fix §2/§2.3; flow-core §2 gate 5.

**A comment only for a why the code cannot say — never a ticket ID.** Traceability lives in the
commit, branch and MR/PR, "where it stays accurate, not in the source, where it rots".
*Now:* feat:build §2.1, bug:fix §2.1, work:green §5, work:respond §6.

**The MR/PR communicates functionality; the preview is mandatory.** Title and body come from the
brief so a PM understands the change without the diff; technical detail is collapsed, except the
pre-deploy SQL, a deployment gate that must stay visible. The block is confirmed before creation with
no exceptions, because the underlying skill may decide not to ask and ship a generic title.
*Now:* feat:ship §2–§3, bug:ship §1–§2.

**Accept a verified signal, not a plausible one (v0.24.0, three places).** *Green is a count, not an
exit code*: nearly every runner exits `0` on a filter matching nothing, so a test that never ran read
as a pass; judge the executed count and names. *Borrowed code carries its reason*: a `catch` copied
from a neighbouring file imports that file's decisions — name why it applies here or do not copy it;
"borrowed-and-plausible reads as deliberate". *Evidence before staging*: two domain findings proved
false against `origin/master` and the generated DQL, so a finding is staged with one evidence line —
code claims checked against `git.default_base` (never a train branch), output claims against the output
actually produced. No evidence → withdrawn; a stored finding gets believed.
*Now:* feat:build §4, §2.1; feat:design §8.

**Work folders carry a slug.** `MT-1234/` said nothing with five works open; the folder is
`<TICKET>-<slug>`, the id stays pure, and commands locate a work by `meta.json.branch` so older
folders keep working (v0.20.0).
*Now:* feat:start §1, bug:start §0.

**`00-summary.md` is the short handoff.** Reading every artifact whole each phase is the largest
token cost; a ≤15-line summary is read first and a full artifact opened only when needed — a summary
that does not answer is the cue to open it, never a licence to guess. (Introduced with the
condensation; no incident yet.)
*Now:* flow-core §5.

**`FLOW.md` is personal config.** It mixes repo facts with one developer's machine and tastes;
committed as-is it imposes preferences and assumes tools. `init` offers to git-ignore it (v0.18.0).
*Now:* init §5; CONFIGURATION "Getting a FLOW.md".

**`domain-memory` is optional, silent, and saves only the why.** Searched per phase with a different
question, staged only on a clear signal, consolidated at `ship`/`postmortem`; 2 s timeout, failure
never mentioned.
*Now:* flow-core §0; work/README "domain-memory".

---

## 2. `meta.json` as the source of truth

**Without `meta.json`, commands refuse.** Every header and panel takes its facts from it, "never
from memory" — an invented MR/PR state trusted at a glance is worse than a blank.
*Now:* work/README "Principles"; flow-core §3.

**Gates read `phases_done` per MR/PR.** v0.14.0: `ship` read the work-level list, which never
resets, so once the first MR/PR of a train was reviewed every later one shipped for free — "it bit
exactly on the MR/PR that carried a defect". Each `mrs[]` entry has its own list, seeded `[]`.
*Now:* feat:plan §4; feat:build §5; feat:review §1/§9; feat:validate §1/§7; feat:ship §1.

**A phase name says a review happened; the shas say what it looked at.** v0.36.0: `review` → more
commits → `ship`, gate satisfied, new commits read by nobody. `reviewed_sha`/`validated_sha` are
written only when the phase advances ("a review that ended in blockers reviewed nothing that stands");
`ship` compares them to `HEAD` and judges a mismatch by what the delta touches, never its size — test
files and the work folder pass with a note, anything else stops in every mode with a re-review of
`<sha>..HEAD`. Absent shas are not a mismatch; refusing would strand every work in flight.
*Now:* feat:review §9; feat:validate §7; bug:review §8; bug:validate §5; feat:ship §1; bug:ship §0.

**`respond_rounds` lives in `meta.json`.** A session resumed days later would otherwise lose count,
and a loop re-arguing a settled thread is visible only to whoever reads all of `08-feedback.md`.
*Now:* work:respond §1, §8.

**`related_repos` and `contract_handoff` are two different questions.** Flow is per-repo, so without
the first the sibling's slice was "recorded nowhere" (v0.19.0); the second exists because "is the
sibling's work done" and "does it know the payload" differ, and `scope` is prose while a contract is a
literal (v0.24.0). Flow notes and reminds; it never scans the other repo.
*Now:* feat:start §3.5; feat:design §7.5; feat:ship §6.3.

**`panel.json` is the view; `meta.json` the state machine.** A work that never wrote a panel still
resolves from `meta.json`. See §5.
*Now:* work/README "`panel.json` schema".

---

## 3. Size as a route (XS → L)

**Size drives which phases run, and it is revisable.** Later phases reclassify; a wrong size
"contaminates subsequent phases (wrong skips, unnecessary MR/PR plans, unneeded postmortems)". `plan`
and the brainstorm panel are skipped on XS/S because the cost does not justify them.
*Now:* work/README "Shortcuts by size"; feat:start §4; feat:brainstorm §3.0/§6; feat:design §7;
feat:plan §1/§5; bug:diagnose §5; bug:investigate §6.

**Size confirmation is never a question in `guided`/`auto`.** One of the four machinery questions
that made an unattended run attended (v0.26.0).
*Now:* flow-core §2 (d).

**Below XS there is no work.** Size prunes phases; until v0.36.0 nothing asked whether this should
be a work at all, so XS — four commands, a branch, a folder — read as the floor. A one-sentence,
one-file change needing no review gets the edit-and-commit alternative in every mode; it is a work
again when it needs a ticket, a later explanation, or touches a schema, a contract, or anything with a
rollback story. "Ceremony that has not earned itself is not rigour; it is how a process gets
abandoned."
*Now:* feat:start §4; work/README "Entering the flow is a choice".

**Bugs validate before review.** v0.35.0: the tables said `fix → review → validate` while
`bug:review` refused without `validate` on S+. The regression test proves the fix; "a review that has
not seen it green is reviewing a claim". `bug:ship` requires postmortem on M as well as L, so
suggestion and gate are one rule.
*Now:* bug:start §2; bug:review §1/§8; bug:ship §0.

**A huge MR/PR "because it can't be split" is a planning failure.** Return to `plan`.
*Now:* work/README "Principles"; feat:plan §2.

---

## 4. The autonomy dial and the hard gates

**Three modes.** `manual` stops at every decision and proposes the next command as one click;
`guided` resolves low-risk decisions with the recommended default, records them and chains; `auto`
also resolves the rest. Every decision a mode took alone is written to the artifact.
*Now:* flow-core §2; CONFIGURATION "autonomy".

**Hard gates stop in every mode, each for a reason.** *Push or MR/PR creation* — outward-facing;
hence `validate`, `bug:review` (XS/S) and `postmortem` never chain into `ship`: the unattended run
"ends where it always should have: asking whether to publish" (v0.25.0). *A branch on an ambiguous
base* — a real accidental deploy sits behind it (§9). *Schema changes*, including any DDL or database
the query duel wants. *High-severity review findings* — nothing chains downstream of a red gate. *The
business brief.* Commands add their own where an action is outward or irreversible: posting a reply,
re-running a pipeline, integrating the base, creating a tracker issue, publishing a contract, every
deletion in `clean`.
*Now:* flow-core §2; work:respond §6.2/§7; work:green §5.C/§6; work:query step 0; feat:start §2.5.4;
feat:ship §6.3; work:clean §0.

**What is never a question is as binding as what always is.** v0.26.0: a 7-MR/PR feature in `auto`
produced sixteen questions in four hours, four about the flow's own machinery — "`auto` was degrading
into `manual` one reasonable-looking question at a time". Never asked in `guided`/`auto`: flow
mechanics (panels, skeptics, width — calls on cost and latency, where the recommended default *is* the
answer); WIP commits; continuing a train on `always`, never offering to wait; size; and anything
already decided — the expensive one, where a decision settled at 14:07 was reopened at 14:29.
"Reopening a settled decision is not prudence; it makes the user decide twice and costs the flow their
trust that a decision stays decided." Only new evidence reopens it, and the evidence leads.
*Now:* flow-core §2.

**A mode-less "ask" beats a mode-aware handoff.** `plan` said "ask for approval" and three lines
later "in `auto`, record and chain"; the unconditioned instruction won (v0.26.0). Every decision point
is now written per mode.
*Now:* feat:design §9; feat:plan §6; feat:brainstorm §3.0/§7; bug:investigate §3.1.

**A named next command is not a handoff.** v0.25.0: ten of twelve phase commands closed with "next
command: …" and nothing else; naming a command is an instruction to stop, and "a specific instruction
beats a general preamble", so `auto` stalled at every boundary while claiming to chain. Every Close
now says: `manual` proposes with one `AskUserQuestion` (never making the user type it); `guided`/
`auto` chain in the same turn.
*Now:* every phase command's `## Close`; flow-core §2.

**Choosing `auto` is the commit authorization.** v0.25.0: an `auto` build ended with "nothing
committed — the 5 files are in the working tree for you to validate first", because the system rule
*never commit unless asked* reinforced a mode-less hard rule. Setting `auto` and typing the command
*is* the explicit ask — the reasoning that already authorized `ship`'s commits. WIP commits only;
push stays a gate. `manual` buys inspection at the cost of an attended build.
*Now:* feat:build §2.2; bug:fix §2.1; work:green §5; work:respond §6.

**If it is a question, it is `AskUserQuestion`.** In prose it hides in `manual` and is an
unauthorised stop in `guided`/`auto`.
*Now:* flow-core §3.

**`autonomy.mode` does not authorize deletion.** It governs mechanics, not "the one action in the
plugin that can destroy work existing nowhere else".
*Now:* work:clean §0, §7.

---

## 5. Reporting rules and the live panel

**Every stop opens with where you are.** v0.26.0: seventeen stops averaging ~1,500 characters and
none opened with the state; four were spent explaining that subagents had become free. "No command said
a single word about how to report", so each stop opened on what was freshest in the agent's head. The
agent's context and the user's are not the same: it read everything, they read none, possibly with
three works in other panes. Header: `<TICKET> · <size> · phase · MR #n of N`, plan state, what
finished, what is needed.
*Now:* flow-core §3.

**~10 lines, short lines, product altitude.** Only what could change a decision. v0.33.0: the limit
"turned out to be a ceiling, not a shape" — ten lines of paragraph are still a wall — so a headline plus
two to five bullets; and when the agent writes the code the human is doing product, not archaeology:
"ten lines about `AttachmentUploader` are a report about the agent's afternoon". A class earns a line
only when the user must decide about it, asked, or named it first. A technical question still gets a
full answer.
*Now:* flow-core §3.

**Process to the artifact; zero-context.** Own mistakes, subagent corrections and bookkeeping go to
the artifact; subagent completion notices never earn a turn. An identifier's first mention carries 4–6
words of what it is; a section number is never cited without naming it.
*Now:* flow-core §3.

**The two stops that survive in `auto` carry the full header.** A brief without "#3 of 7, two
shipped" above it is unreadable (v0.26.0). `plan` prints the waves before its table and `resume` gained
`MR/PRs:`/`Waves:` lines, because "how many are left" is what a break loses.
*Now:* feat:build §2; bug:fix §2; feat:validate §7; feat:plan §6; work:resume §2.

**The stop is also written to disk.** v0.29.0: three panes, and the question about each is always
which MR/PR, how many left, waiting on me, what link — all in `meta.json`, none readable without asking
the agent for a link it opened forty minutes ago. "The chat is a stream; the question is a state."
*Now:* flow-core §4; work/README "`panel.json` schema".

**Written before a long stretch, overwritten whole, honest `updated_at`.** A file written only on
success keeps showing as finished a step that died halfway — "the failure mode a panel makes *worse*
than no panel"; written before, a stale timestamp is flaggable. Whole overwrite means never half old,
half new. `stale_after_minutes` covers known-long stretches: `watch` sets twice its cycle, since the
default "would let a dead monitoring loop pass for a live one through five missed cycles".
*Now:* flow-core §4; work:watch §5.

**`mark` says what a line is; the panel draws it.** Semantic styles over colours so the reader owns
the palette (v0.29.0); then `done`/`current`/`pending`/`wait`/`block`/`info`, which "kills the last place
where flow was making a presentation decision it had no business making" and states the train honestly
— an open MR/PR is `wait` (v0.30.0). `style` on a marked line is wrong except when the colour *is* the
information (a monitoring verdict).
*Now:* flow-core §4; work:watch §5.

**No headings over the train; the panel has its own `phase`.** v0.29.1: `Done  #1 …  MR open`
contradicted itself — in a train a shipped MR/PR is open and waiting, so `Done` "states something false
in the one place the user is trusting at a glance". And `meta.json.phase` advances only at Close, so a
header drawn from it read `build` while the body said "validating".
*Now:* flow-core §4; work/README "No headings over the train".

**`link` is a field; `ref` need not be a number; blank lines separate alignment blocks.** The
reader shortens a URL to `!9977 ↗`; `Now`/`Next`/`Decision` align like `#1`; per-block widths keep the
train and the labels from dragging each other wide (v0.30.0). The "~55 characters" rule was withdrawn
as written from a misread screenshot. Panels are in the artifacts' language, after one English panel
over a Spanish work.
*Now:* flow-core §4.

**Who writes it.** Phase commands at pre-flight, every stop, long stretches, Close; `ship` the
instant the URL exists — "until it is in those two files it exists only in this turn's scrollback";
`plan` when the train is born; `resume` after a break; `watch` every cycle; `abandon` with a terminal
state. Read-only commands never write it.
*Now:* work/README "Who writes it"; feat:ship §4.1; bug:ship §3.1; work:resume §5; work:abandon §6.

---

## 6. Contracts — anchoring against self-deception

**The problem.** The same agent designs and then builds, and the contract "dissolves under the
gravity field of repo patterns". Four anchors hold it.
*Now:* work/README "Anchoring to design contracts".

**Anchor 1 — every external surface is a literal shape, never prose.** A contract in prose "is
ambiguous and will be a source of failures at build time"; a pattern break is announced.
*Now:* feat:design §5.

**Anchor 2 — `build` copies the contracts verbatim, then compares key by key.** "The contract lives in
the file you are writing, not in another you are no longer reading." The close-out check is a
deliberate textual comparison, not a test.
*Now:* feat:build §2.0bis, §4.2.

**Anchor 3 — a double-blind contract reviewer, and a blinded idiom audit.** Fed the full design, "the
agent rationalizes the mismatch by reading nearby justifications". The idiom audit is blinded for the
same reason: the wrong primitive survives structural review because it is "locally coherent and
justified in writing — and they read that justification" (v0.10.0).
*Now:* feat:review §5, §5.5; bug:review §2.2; work:respond §6.1.

**Known limitation, stated.** A contract transcribed or declared wrong is faithfully confirmed; the
package reduces the failure to those two cases.
*Now:* work/README (Known limitations).

**Anchor 4 — the contract crosses to the other repo via the ticket.** v0.24.0: an epic across a
backend and its consumer; the contracts lived in git-ignored `.claude/work/`, so "the most expensive
artifact of the whole flow died with the session while the cheapest — `scope`, one line of prose — was
the only half that crossed", and the consumer invented routes already decided. `ship` publishes the
literals whose "Known consumer" names that sibling as a ticket comment (fallback: a versioned file),
previewed in every mode because the team reads it. Criteria and ADRs do not cross — this repo's *how*.
`bug:ship` does the same for a changed surface, "worse than a new contract, since the sibling has
working code and no reason to suspect the shape moved".
*Now:* feat:ship §6.3; bug:ship §4; feat:design §5, §7.5.

**A paraphrased contract is a new contract.** Every copy in the chain is verbatim; anchor 4 "moves
rather than removes the risk: a contract published wrong is now believed by two repos instead of one".
Received contracts are not negotiable — the emitter may be deployed, and a local improvement "just
breaks integration more quietly".
*Now:* feat:build §2.0bis; feat:ship §6.3; feat:start §3.6; bug:start §1.1; work:resume §2.5.

**"Read the ticket" includes the comment thread.** v0.28.0: the contract was published as a comment
exactly as designed, and the consuming `start` never saw it because every default `view_cmd` stops at
the description — "an empty search for a contract reads exactly like a ticket with no contract". The
thread is where a ticket is *decided*; the most recent deciding comment wins over the description, but
a contradiction that moves scope becomes a question.
*Now:* feat:start §2.1; bug:start §1.1; CONFIGURATION "Why `comments_cmd` exists".

**An unread thread is a named gap; an absent contract is named out loud.** "I could not read the
comments" and "there were no comments" are opposite facts, only one fixable by pasting; and when a
ticket points at another repo with no contract, silence is filled by "invention that reads like
knowledge".
*Now:* feat:start §2.1/§3.6; bug:start §1.1; work:resume §2.5.

**`resume` re-reads the thread, shows only what is new, never amends the design.** The break is when
the sibling ships; a comment contradicting something built is a collision handed to the user in every
mode — "the one case where an `auto` run quietly fixing it produces two contracts for one ticket".
*Now:* work:resume §2.5.

---

## 7. Review design

**Review is mandatory.** `ship` does not run and `postmortem` does not close without it.
*Now:* work/README "Golden rules" 1.

**Depth is proportional to size and risk.** A panel over a tiny diff "is almost pure latency"; a
sensitive surface (auth, secrets, payments, personal data, public contract, migration) raises one
effort tier and forces the panel, so L-sensitive runs at `max` — "risk, not just line count, buys the
most thorough pass" (v0.12.0).
*Now:* feat:review §2.0; bug:review §2.0; CONFIGURATION "How much review runs".

**The panel runs whole, and a partial panel says so.** v0.23.0: full flow, green suite, a human found
four things. Members "own whole categories that the rest of the flow explicitly does not revisit — so a
skipped reviewer is a category with no owner at all"; `Agents launched` records ran vs defined.
*Now:* feat:review §2.1/§8; bug:review §2.1/§7.

**Design truth vs rationale; a settled decision is context, never a scope exclusion.** Contracts and
criteria are truth; the ADR "Why" is hypotheses — "a plausible written justification is the single most
common way a wrong idiom survives review". Briefs say *"X is decided — tell me its consequences"*, never
*"do not report X"*, since excluding a topic excludes everything hanging off it (v0.23.0).
*Now:* feat:review §2.2; bug:review §2.1; work:respond §6.1; work:green §5.

**Performance is not only the database.** The v0.23.0 case was an external API inside a loop over
100 items with a `catch` returning `null`, each failure enqueuing downstream; the trigger had been "DB
/ heavy queries". Now any repeated call leaving the process, and what each *failed* iteration sets off.
*Now:* feat:review §3; bug:review §3; feat:validate §2.

**The completeness sweep exists because reviewers abandon early.** A blinded coverage auditor gets
only the file list and one line per reviewer; leftover gaps are recorded — "better to declare the limit
than to feign complete coverage".
*Now:* feat:review §3.5; bug:review §4.5.

**The over-engineering audit is the second barrier.** "If I remove this, what breaks in the project —
today, not in a hypothetical future?"
*Now:* feat:review §4; bug:review §4.

**Skeptic verification: narrow gate, one skeptic, a ceiling, and what the ceiling drops gets said.**
v0.31.0: three skeptics per finding with no bound — twelve findings meant 36 agents on a 69-line MR
labelled M. Now M/L **and** over 150 changed lines ("a work labelled M can perfectly well ship a
70-line MR/PR") **and** ≥4 *ambiguous* findings. One skeptic: "this filter's failure mode is cheap,
since a wrongly-discarded finding stays recorded in the artifact". `agents.fanout_max` (empty → 4)
caps every round; a truncated sweep reports `4/7`, because "a silently truncated fan-out reads as full
coverage". Skipped and clean are not the same result.
*Now:* feat:review §6; bug:review §5; bug:investigate §3.A; feat:brainstorm §3.A.

**The synthesis is never a subagent; fan-out is plain subagents unless a repo opts in.** Judging
returns to the main agent, which holds the context — delegating "cost an agent and a context hop to get
markdown copied back". The rounds had been Claude Code `Workflow` DSL, which "exists in Claude Code and
nowhere else"; plain subagents are the one primitive every harness has, `agents.fanout_tool` opts back
in (v0.31.0).
*Now:* feat:brainstorm §3.A; bug:investigate §3.A; work:query §3; CONFIGURATION "agents".

**Panels are proportional too.** The brainstorm's cross-critique "keeps the chairman from ranking on
presentation instead of substance — and it is also the expensive one", so L only. The hypothesis sweep
gathers evidence for *and against*, because "an agent asked only to confirm will always find
something".
*Now:* feat:brainstorm §3.A; bug:investigate §3.A.

**The net that worked is not thickened.** In v0.24.0 the panel caught what reached it; the lesson was
cheaper detection upstream, and the review was left alone.

---

## 8. The query duel

**A query is judged on its plan, not its prose.** v0.32.0: a query passed `design`, `build` and a
full panel; a reviewer asked *"why is the limit in the code and not in the query?"*; the flow answered
from theory. `EXPLAIN` on real data: a join on columns with different character sets, 63,000 rows
scanned to return fifteen, 449 ms, the same defect a year old next door, and the winning shape the one
the flow had dismissed. Cost lives in the plan, which depends on facts nowhere in the diff — index,
column order and **direction**, collation of both join sides, rows per key; a mixed-direction
`ORDER BY` sorts the whole set, a collation mismatch loses the index, and both pass every test. "A
plausible sentence in the design makes the reviewer stop looking sooner."
*Now:* work:query; work/README; CONFIGURATION "data".

**Facts first, a blinded challenger, the main agent judges.** Unknowns are written as unknown — "a
fact you assumed is the thing that later makes the whole duel worthless"; indexes come from the
schema, never the mapping, which is only what the code believes. The challenger gets no rationale and
must name a data scenario per attack.
*Now:* work:query §2–§3.

**Three judging rules and a real `unresolved`.** *No number, no win.* *No dogma in either direction*
— "N small queries is an N+1" and "one batched query always wins" are both preferences until measured.
*The objector's variant is measured next to yours*, especially when theory says it loses. The premise
may have been wrong (the objection was a bound, the cost a lost index). `unresolved` "is a real verdict,
not a failure to produce one"; the verdict leads with one recommendation, because hedging "reads as *I
don't know* and makes the reviewer decide twice".
*Now:* work:query §3, §5.

**Any size, XS included.** "A category no other reviewer owns" — a general performance reviewer
"almost never reads its plan" — and a one-line `ORDER BY` change is exactly the invisible cost.
*Now:* feat:review §3.6; bug:review §3.5; work:respond §6.1.

**The functional test database proves nothing about a plan.** With fixture rows the optimizer picks
whatever is cheapest at that size; "not measured" is legitimate, a test-database plan is not evidence.
`validate` measures against `data.volumes` or a set shaped like them; `volumes` is the cheapest key —
"an adversarial reviewer with no volumes invents them". Creating or seeding a database is a hard gate,
never production.
*Now:* work:query §4; feat:validate §2; CONFIGURATION "data"; init §3.

**A performance objection is answered with a plan, never with reasoning.** "A reasoned reply that has
not looked at an execution plan is the most expensive answer this command can produce": authoritative,
so it costs a round trip; grounded in the design's rationale, so it feels verified. Category `G`
measures both variants, tickets a predating defect rather than using it to bless or widen the diff, and
keeps the table in the artifact.
*Now:* work:respond §3 (G), §4.G, §8.

**A trick that fixes a plan ships with its reason.** Deleting a cast or hint "turns nothing red, it
only turns slow", so it carries a comment saying why and what removes it, plus the root-cause ticket.
*Now:* work:query §3 item 11; bug:review §3.5.

**Slowness is a plan problem until proven otherwise.** A plan changes with no code change and `git
blame` cannot find it, so a commit-reading investigation "will converge on the wrong thing with high
confidence". The design's Access-paths table decides an index while it is cheap; `build` records the
plan as it writes.
*Now:* bug:investigate §3.B; feat:design §5; feat:build §2.1.

---

## 9. Trains, branches and worktrees

**Explicit base and `--no-track`, because an accidental deploy happened.** Never branch from
"wherever I am" (inherited commits), and never let the base be the upstream: with
`branch.autoSetupMerge=true` a blind push resolves to the remote base and can deploy. First push is
`git push -u origin HEAD`; `ship`, `green` and `respond` block if HEAD or its upstream is the base.
*Now:* feat:start §5; bug:start §3; feat:ship §4.0; bug:ship §3.0; work:green §6; work:respond §6.2.

**The push guard judges the directory the push runs in, strips flags, blocks without `jq`.**
v0.35.1: it read `HEAD` in the session directory and refused every push from a worktree — "an agent
stopping to ask for a push is the failure this hook was supposed to prevent, not cause"; an
unresolvable path errs towards refusing. v0.35.0: any flag pushed the blind-push match off the end of
the command, and a missing `jq` waved everything through — "a guard that cannot read its input must not
report nothing dangerous here".
*Now:* `plugins/flow/hooks/block-push-to-master.sh`; `script/tests/push-guard.sh`.

**Link the branch to the GitHub issue at creation; fixes follow `branch_pattern`.** GitHub ignores
`Closes #N` on a non-default target — exactly the train — so `gh issue develop` registers a linked
branch. A hardcoded fix branch "never reached its ticket" on trackers that link by name (v0.35.0).
*Now:* feat:start §5.5; bug:start §3.

**Never write the plan's `#n` in an MR/PR body.** Forges auto-link it to the wrong thing —
`#5 (closed)` (v0.10.0). URLs for created MR/PRs, quoted titles for pending.
*Now:* feat:ship §2; bug:ship §1.

**`n` is the execution order.** Topological waves, so `#1` is always startable — no "start at #5"
(v0.10.0). A parallel sibling is never stacked on an unrelated branch just because it is built next.
*Now:* feat:plan §2/§4; feat:build §1; feat:ship §6.2.

**The train never waits for the previous MR/PR to merge.** "Waiting is what makes people give up and
open one huge PR instead." Only `train_chain: wait` holds; offering to wait otherwise "is the stop that
most often turns a configured train back into a manual one". Continuing is not a gate — the next
`ship` will stop.
*Now:* feat:ship §6.2; CONFIGURATION "Multi-PR trains".

**Estimates are a thermometer; the hot cut never rewrites history.** At +50% lines or +2 files:
cut, continue and record, or reopen the plan; a cut inserts a fresh entry with `phases_done: []` and
moves work by `cherry-pick`. A second overrun means the plan is wrong, not the estimate.
*Now:* feat:build §2.3; feat:plan §4; work:status §2.

**Worktrees coexist; `try` tests in detached HEAD.** Detached "prevents accidental commits onto the
branch you are only testing"; `worktree_resync` runs after each switch, confirmed because it is
invasive.
*Now:* feat:start §5.0/§5.4; work:try.

**`clean` sweeps what `ship` never gets to ask about.** v0.27.0: 22 and 14 worktrees, thirteen of
fourteen merged, sixteen work folders and zero archived. Every offer was "a prompt at the end of a long
command, easy to answer past — and in a train it never fires at all". Evidence, never age.
*Now:* work:clean; work:status §4; work:daily §4; feat:ship §6.3.

**The forge is the evidence, asked exactly twice; squashes need patch equivalence.** Two list calls
joined locally. `git branch --merged` misses every squash (8 of 13 were invisible), so `clean` replays
the tree and asks `git cherry`. v0.27.1: `@{u}` was the wrong ruler because `--no-track` branches have
no upstream after merging; a *closed* MR/PR is its own verdict — "one says a decision was made, the
other says nobody ever looked"; a bounded per-branch pass runs only when ≤25 remain unknown.
*Now:* work:clean §4–§5.

**The refusals are most of the design.** `unknown` is never a candidate — "silence is not a merge";
dirty worktrees protected; no `--force`, ever; `-D` only on a forge verdict; folders archived, never
deleted; the remote never touched. A train whose last `ship` never ran is confirmed individually and
gets `phase: done` before archiving. `--purge-archive` removes only what is already in git.
*Now:* work:clean §0, §5–§8.

---

## 10. Tracker transitions and timing

**Flow moves the ticket with the commands you give it.** `start_cmd`, `done_cmd`, `abandon_cmd`
(never "done" for abandoned work); tickets used to rot in "To Do" (v0.21.0). Best-effort, idempotent,
gated in `manual`; "a tracker hiccup never blocks your work". On GitHub/GitLab `done_cmd` stays empty —
`Closes #N` already closes on merge.
*Now:* feat:start §6.5; bug:start §4.5; feat:ship §6.1.1; bug:ship §4; work:abandon §6; init §3.

**Done only after merge — creating the MR/PR is not finishing.** v0.35.0: `bug:ship` set `done` on
opening, so on Jira the ticket closed while the fix awaited its first reviewer — "it is the tracker,
not the flow, that they read". `phase` stays `ship` until the merge is confirmed; `green`, `respond`
and `clean` read the difference, "and a work parked at `done` with an open MR/PR sends all three at the
wrong target". `done_cmd` is tied to `phase: done`, never to the archive prompt.
*Now:* feat:ship §6.1/§6.1.1; bug:ship §4.

**The daily standup keys on "awaiting you", not "unresolved".** v0.17.1: `respond` never resolves,
so an answered thread stays unresolved and `daily` kept flagging `!9707` after it was fully answered.
The signal is whose comment is last; threads awaiting the reviewer are informational, never Blockers.
*Now:* work:daily §2, §5.

---

## 11. The loops between ship and merge: `green` and `respond`

**Two signals, two loops.** Machine (pipeline, mergeability) is `green`; human (threads) is
`respond`. A red pipeline can happen with zero comments (v0.15.0). Both repeat per round, log to
`09-ci.md`/`08-feedback.md`, and never advance `phase`.
*Now:* work/README "After ship, before merge".

**`green` means mergeable, not just green.** v0.22.0: on a conflicted MR it saw green jobs and said
"you're good to go". It reads the forge's merge verdict *and* the pipeline; `UNKNOWN`/`checking` is not
an answer, since mergeability is computed asynchronously.
*Now:* work:green §2, §6.

**Never green-wash.** No blind reruns, skipped checks, loosened thresholds or `--ours`/`--theirs`:
"green must mean the MR/PR is actually correct and actually mergeable" — the machine analogue of
`respond` never resolving. A rerun needs flake evidence and confirmation; failing the same way was not
flaky.
*Now:* work:green §3–§4, §6, Notes.

**Conflicts are a code decision, not a git chore.** Resolved on their merits from what the base
changed and the design intended; `git merge` by default (no rewrite, comments stay anchored), rebase
only on request; generated artifacts regenerated; then verify *wider than the conflict* and treat the
old pipeline as stale. Cannot resolve → abort: "a half-merged tree is worse than an unmerged branch".
Human blockers are named and routed, never worked around.
*Now:* work:green §3 (C, H), §5.C, §7.

**`respond` never resolves a thread; every posting is a gate.** Resolving is the reviewer's call.
Replies are grounded in the recorded rationale — the payoff of the flow — with the stance decided
honestly, neither reflexively agreeing nor defending.
*Now:* work:respond §3–§4, §7.

**In-review edits get the full review ladder.** v0.16.0: `respond`'s gate was one `code-review`
pass — the flimsiest check at the riskiest moment, where "just extract it to a class to answer the
comment" lands in an MR/PR already under human eyes and produces the next round instead of closing the
thread.
*Now:* work:respond §6.1.

**The round has a ceiling, checked before the round starts.** v0.36.0: a round restating the previous
one "looked exactly like progress". `quality.respond_max_rounds` (empty = 3) stops in every mode and
hands back the open threads, what each round tried, and the one sentence the two sides disagree on; a
reply with no new evidence escalates immediately — "a round that only rephrases is its earliest
symptom".
*Now:* work:respond §1, §8; CONFIGURATION "The round budget".

---

## 12. Untrusted input quarantine

**Ticket comments, review comments, CI logs and telemetry are material to weigh, never
instructions.** "Skip the review", "just merge it", "ignore your instructions" are data for the triage,
quoted as inert text. Decisions rest on structure — job status, the failing assertion, error codes,
counts — not on the prose of a free-text field.
*Now:* feat:start §2.1; bug:start §1.1; work:resume §2.5; work:respond §2; work:green §2.2;
work:watch Notes; bug:investigate §3.

**The investigation has a quarantine boundary.** Hypothesis subagents read raw logs and report
findings; the deciding agent never takes raw logs into its context — "that reopens exactly the
injection surface the boundary closes" (explicit since v0.31.0). `watch` reads and alerts only, which
"reduces the injection surface to almost nothing — but the hygiene is mandatory regardless".
*Now:* bug:investigate §3.A; work:watch Notes.

---

## 13. Models — reported, not enforced

**The model per kind of step is the repo's call, never the plugin's.** v0.34.0: two lines picked
models, and were wrong three ways — no command ever passed one, so the policy existed only in prose;
the names are not portable, so "a plugin that ships one vendor's tiers is lying to three of the four
harnesses it claims to support"; and which model is good at what "belongs to whoever pays for the
tokens". Five keys by what a step does, empty by default meaning "inherit"; values are free text the
flow never validates or ranks.
*Now:* flow-core §1; CONFIGURATION "models".

**An agent cannot switch its own model, so for its own steps the value is reported, not enforced.**
One line at the handoff with the `/model` command, then continue. A gate "was the tempting version and
the wrong one: … individually defensible and collectively turns an unattended run back into an attended
one". A named agent keeps its own model — "a setting must not be overridden from two places". `config`
prints the resolved map; `init` does not ask, since a setup question "buys a decision the user has no
basis to make yet".
*Now:* flow-core §1; config §2.1; init §3.

---

## 14. Post-deploy watch

**Show the plan before the loop; never sell a zero-traffic green.** The user sees the literal queries,
baselines and thresholds first — "the same human gate as the brief in `build` or the preview in
`ship`". Baseline is the window before T0, with the same weekday of the prior week as context (never the
previous day), ratios over counts. On a path with ~0 baseline events "a 🟢 on zero traffic is not a real
🟢". Polling is parallel tool calls, not agents — "dozens of agent startups to monitor 30 min is absurd";
red interrupts and offers `/flow:bug:start`: the loop "does not investigate; it escalates".
*Now:* work:watch §4–§7.

---

## 15. Tooling and release discipline

**There is no CI; `check.py` stands between a broken tree and a permanent tag.** "Every check here
exists because something shipped broken", each verified by reintroducing its defect — how the first two
embedded-JSON checks "turned out to be worthless" (v0.30.2).
*Now:* `script/check.py`; `RELEASING.md`.

**No empty tracked file — the zero-byte manifest.** v0.30.1: `plugin.json` shipped empty for two
releases and the plugin could not load; `open(p, "w").write(open(p).read()…)` truncated before reading,
and nothing but the loader reads the manifest. The manifest version must match the newest changelog
heading, or "the release notes describe a version nobody is running".
*Now:* `check_no_empty_tracked_files`, `check_manifests`, `check_version_matches_changelog`.

**The recommended hook checked nothing.** v0.30.3: through the documented symlink,
`abspath(__file__)` landed in `.git/hooks` and the hook exited green on every commit — "worse than no
hook, because the previous release's own instructions installed it". It now resolves the link and asks
git for the toplevel.
*Now:* `repo_root()` in `script/check.py`.

**Hooks keep their executable bit; `hooks.json` parses.** A lost `+x` "is a guard that silently stops
guarding"; a stray comma disables the hooks without a word. `doctor` checks at runtime, `check.py` at
release.
*Now:* `check_hooks_executable`, `check_all_json`; doctor §2.4.

**Embedded JSON parses; panel vocabulary is only what the reader knows.** An unknown `mark` quietly
loses its column and renders as prose; v0.35.0 found seven commands still teaching `Right now:` /
`Waiting on you:` / `under Left`, and the checks keep a third generation from appearing.
*Now:* `check_embedded_json`, `check_panel_vocabulary`, `check_panel_vocabulary_prose`.

**The shared preamble: from eighteen hand copies to one skill.** At HEAD it was copied "on purpose (a
command prompt must be self-contained)" and `check_shared_preamble` named the odd copy out; the
condensed commands load `flow-core` once per session, and the preflight checks the skill and the config
keys instead.
*Now:* `plugins/flow/skills/flow-core/SKILL.md`; `check_core_skill`, `check_config_keys`.

**Adapters: from hand-condensed mirrors to build output.** At HEAD three adapters mirrored every
command by hand, held by parity, freshness (an adapter "could sit five versions behind and pass",
v0.35.0) and a smoke test (present, current and unusable — wrong wrapper or prefix, v0.36.0). The
working tree generates them: "1.7 MB of near-verbatim copies that drifted one release at a time … are
now build output", varying only wrapper, prefix and a primitives legend per harness. The warning stays:
verified on paper, never executed end to end elsewhere.
*Now:* `script/adapter-build.py` (`check_adapters_generated`); `script/adapter-smoke.py`;
`adapters/*/CORE.md`.

**`config` reads the file; `doctor` reads the world it assumes.** v0.36.0: a host CLI installed but
unauthenticated — passing every presence check — discovered at `ship` with the work finished; a missing
reviewer discovered never, because the panel runs smaller and reports clean. `doctor` is read-only,
quiet on success ("a wall of green ticks is noise that trains you to stop reading it"), and orders
findings by cost: what fails open and silently first, "because the loud one cannot ship a mistake".
*Now:* doctor; config §3.

**`news` and the session-start nudge use separate markers.** A shared one would let the nudge eat the
delta (v0.13.0); versions compare by semver, never string order.
*Now:* news; `hooks/notify-update.sh`.

**The changelog is the primary record.** This document is a thematic index of it, not a replacement;
where they disagree, the changelog wins.
