# Why flow is built this way

The short version of the reasoning behind the plugin. The long version — the rationale behind
every individual rule — is [`DESIGN.md`](DESIGN.md). Terms are defined in [`CONCEPTS.md`](CONCEPTS.md).

## Phases, not prompts

One big "do this task" prompt hands the agent every decision at once and leaves you nothing to
inspect until the diff lands. Flow splits the work into phases — `start`, `design`, `build`,
`review`, `ship` — that each gate the next and each write an artifact to disk. The artifact is the
point, not a by-product: it is what lets the next phase start from what was decided instead of
from scratch, what lets you resume tomorrow in a different pane, and what lets you rewrite a
decision by hand (`03-design.md`) and have the following phases respect it. A phase that left no
trail could not be audited, resumed or corrected; it could only be redone.

## The autonomy dial cuts both ways

`autonomy.mode` is a dial. On `manual` every phase stops at each decision and waits for you. On
`auto` the flow runs itself — ticket, design, implementation, review, validation, one phase
chaining into the next without you typing a command — resolving the small decisions with sensible
defaults and **writing down every one it took**, so you can read afterwards what it chose and why.
`guided` sits in between: it decides the low-risk calls and still asks at the real ones.

What makes `auto` safe is that the dial never moves the **hard gates**. In every mode, including
`auto`, the flow stops before a push or an MR/PR, before a branch on an ambiguous base, before a DB
schema change, before shipping a review that came back with high-severity findings, and before the
business brief it writes just before touching code. It goes alone; it does not go behind your back.

The other half matters just as much, and it is the half that is usually forgotten. `guided` and
`auto` **never** ask about the flow's own machinery — whether to launch a review panel, how many
reviewers, whether to make a WIP commit, whether to continue to the next MR/PR of a train, or
anything already decided and written down. Each of those questions is individually reasonable. Asked
together, they turn an unattended run back into an attended one, and `auto` decays into `manual` one
reasonable-looking question at a time. A gate that always stops is only half a contract; the list of
what is never asked is the other half. Reopening a settled decision is the expensive case: it makes
you decide twice and costs the flow your trust that a decision stays decided. Only new evidence that
contradicts the premise reopens one — and then the evidence leads, not the question.

## Every stop opens with where you are

The agent's context and yours are not the same one. It has read every tool call, every subagent
report and every artifact; you have read none of them, and quite possibly you have three other works
running in three other panes. Left alone, a report opens on the detail that was fresh in the agent's
head, and the one fact that is pure bookkeeping for it and pure orientation for you — *how many
MR/PRs are left, and which one is this* — never gets written down.

So every stop, in every mode, opens with a fixed header before any prose: ticket, size, phase,
`MR #3 of 7`, what each MR/PR is waiting on, what just finished, and the one thing it needs from you.
Then at most ten lines of body, in the language of what changed for whoever uses the software rather
than of the code that changed. The fewer stops a mode produces, the more each one has to carry: in
`auto` there are two per MR/PR, the brief and `ship`, and everything between them ran while you were
looking elsewhere. The same header has a twin on disk, `panel.json`, because the chat is a stream
and the question you actually have is a state — something a pane or a status bar can answer without
you scrolling or asking.

## When not to use it

The size dial prunes *phases*; it never says "this is not a work at all", and XS is still four
commands, a branch and a folder. So it is worth saying plainly: **do it by hand** when the change
is one you can describe in a single sentence, touches one file, needs nobody's review, and whose
entire test story is that the existing suite either passes or it does not. A typo in a string, a
version bump, a log level, a comment. Edit, commit, done. A work folder, a branch, an artifact trail
and a review panel cost more than that change is worth, and the fastest way to abandon a process is
to feel it taxing you on a two-line fix. Ceremony that has not earned itself is not rigour.

It goes back to being a work the moment **any** of these holds: it needs a ticket; someone other than
you has to understand later why it was done; or it touches a schema, a contract, or anything with a
rollback story. Those are exactly what the artifacts and the gates buy you. Neither buys anything on
a typo. `/flow:feat:start` applies this judgement itself and offers the two-line alternative instead
of opening a work.

## Stack-agnostic, and what that costs

Nothing about a stack is hardcoded. Each repo is described by a `FLOW.md` at its root — tracker,
git host, test commands, review agents, observability — and anything left empty is auto-detected or
asked for. The price of that is deliberate: flow ships **no** agents and **no** review skill, because
those are language- and project-specific, and it never picks a model for you, because a plugin that
shipped one vendor's tiers as gospel would be wrong on three of the four harnesses it runs on. You
name what you have; the flow delegates to it and degrades where it is missing.

## Personal config, not team config

`FLOW.md` mixes repo facts (tracker, quality commands) with your own preferences (autonomy mode, the
agents and MCPs *you* have installed, review depth, your assignee name). The same file on a
teammate's machine may point at agents that are not there. So it is personal by default — `/flow:init`
offers to git-ignore it, along with `.claude/work/` — and it holds no secrets, which stay in your
credential store. A team that wants to share the repo-fact subset can commit it deliberately; the
default just refuses to make one person's preferences everyone's.
