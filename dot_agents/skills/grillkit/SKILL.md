---
name: grillkit
description: >-
  Grill the user relentlessly about any idea, plan, or design, a round of unblocked decisions at a time, each with a recommended answer, until you both share the same picture. Use when the user wants to stress-test or pressure-test an idea, says "grill me", "grill this plan", "poke holes in this", "interrogate my design", or otherwise asks to interrogate a concept before committing to it, whether a rough idea, a plan file, an architecture, or a PR.
license: MIT
allowed-tools: Bash, Read, Grep, Glob, Write, Edit, AskUserQuestion, Task, Agent, Skill
metadata:
  internal: false
---

# grillkit

Interview the user relentlessly about their idea until the two of you reach a genuinely shared understanding. The subject can be anything: a rough concept, a design in their head, an existing plan file, an architecture, a PR. You don't need a formal plan to grill. Map it as a **design tree**, where every decision branches into the decisions that hang off it. Do not start building; the point is to surface every unresolved decision *first*.

## How to grill

- **Open by reflecting the idea back.** Before the first question, restate the subject in your own words: the goal you understand, the shape you're about to grill. This surfaces a misread up front, so you and the user are grilling the same idea rather than diverging silently for ten questions.
- **Work the tree in rounds.** The **frontier** is every decision whose prerequisites are already settled, meaning the questions you can ask *now* without guessing at answers you haven't heard yet. Ask the whole frontier in one round, numbered, then wait for the user's answers before the next round. A question whose answer depends on another question still open in this round belongs to a *later* round, not this one. [Asking the round](#asking-the-round) is the format.
- **Each round reshapes the tree.** The answers settle decisions, which pushes the frontier outward and unblocks the questions that depended on them. Recompute the frontier and ask the next round.
- **Always recommend an answer.** For every question, state the option you'd pick and why. A naked question offloads the thinking; a recommendation gives the user something concrete to accept, reject, or refine.
- **Probe the soft spots.** Push hardest on unstated assumptions, hand-waved edge cases, error and failure paths, scope boundaries, and anything described vaguely. If an answer is thin, follow up in the next round rather than letting it stand.

## Asking the round

A grill is only as good as the user's ability to answer it fast. Dense paragraphs with choices buried mid-sentence make a good question unanswerable, because the reader has to parse prose to find the decision. Every rule below exists to keep a round scannable in one pass.

### The shape of a round

```
### Round 2: 3 open decisions
Blocked behind this round: storage format, migration path.

❓ **Q4. Where does the doc map live?**
Stakes: `update` needs a code-path → page lookup without reading every page, and `audit`'s recency prefilter needs to know which paths a page describes.

- **(a) Per-page colocated metadata.** Can't drift from the page, one grep pass, invisible in every renderer
- **(b) YAML frontmatter.** GitHub renders it as a visible table, and it may collide with an engine's own schema
- **(c) Central manifest.** One more file to keep in sync
- **(d) Re-derive each run.** No drift, but throws away the cheapness `audit` depends on

➡️ **(a)** as an HTML comment under the visible stamp: `<!-- wikikit: documents: src/cli/**, package.json -->`

---

❓ **Q5. Contributor docs: in or out?**
Stakes: dev-env setup and release steps are *derivable from the repo*; a CONTRIBUTING.md is a social contract that isn't in the repo at all.

- **(a) Split on that seam.** Mechanical half becomes how-tos, the social half stays out
- **(b) All in.** Pulls PR etiquette and CoC into scope, which can only be invented
- **(c) All out.** Loses two how-tos that verify cleanly

➡️ **(a)** with `how-to/set-up-a-dev-environment.md` and `how-to/cut-a-release.md` joining the doc set; root `CONTRIBUTING.md` is never written, only linked.

---

⏳ **Q6. Which renderer serves these pages?** Waiting on a sub-agent checking the repo for a docs generator. It gates the frontmatter decision, so it lands next round.

Reply `4a 5b`, or "go with your picks" to take both.
```

### The rules that produce it

- **Options are a list, never prose.** One option per line, always, even for a binary. `Options: (a) …, (b) …, (c) …` inside a sentence is the single worst readability offender in a grill. Forcing a two-way choice into list shape is also what surfaces a seam you'd otherwise bury in sentence four.
- **Each option carries its own trade-off.** Put the reason to reject (b) on (b)'s line. A recommendation that argues against three options the reader last saw 200 characters ago makes them ping-pong up and down the round.
- **Stakes first, two sentences max.** Label it `Stakes:` and say why the decision is load-bearing, meaning what breaks or stays undecided downstream. Everything else belongs on the option lines.
- **The recommendation is one line.** `➡️ **(a)** <the concrete form it takes>`. Point at the letter, then add only what the list couldn't carry: the exact syntax, path, or shape you'd write. Never restate the option's own description.
- **Rule off between questions.** A `---` renders as a horizontal line in every terminal and stops questions bleeding into each other.
- **Number continuously across rounds.** Q1–Q3 in round one, Q4 onward in round two. Restarting at Q1 each round makes "Q2" ambiguous the moment anyone refers back, including your own recap in [Hand off](#hand-off).
- **Code spans are for literals only.** Paths, filenames, flags, commands, identifiers. Use *italics* for conceptual emphasis. Code-spanning ordinary prose words turns the round into rainbow noise and hides the spans that are real references.
- **Show what's pending, don't hide it.** When a sub-agent is still fetching a fact a question depends on, list that question with `⏳` and name what it's waiting for. A visible branch that goes unasked reads as forgotten; one line explains it's blocked, not dropped.
- **Head the round and close it.** The header gives a progress signal, meaning how many decisions are open now and what they unblock, which is otherwise unknowable and makes a long grill feel endless. The closing line names the reply format so the user doesn't invent one every round.

### Offer the picker when you have one

With `AskUserQuestion` available, run the round **hybrid**: print the full text round first, with stakes, trade-offs, evidence, and recommendation, then call the tool for the picks alone. The user clicks instead of retyping letters, and the reasoning still gets read.

- **The picker mirrors the text round exactly.** Same questions in the same order, same options in the same order inside each question. The widget is a second view of the round the user just read, not a fresh presentation of it. Reorder either one and the letters stop meaning anything: the user reads the case for `(c)`, then clicks the third option and gets something else.
- **Write the recommended option as `(a)` whenever the list has no order of its own.** The user takes the recommendation most of the time, so landing it in the first slot means a single click with no arrow keys, and because the picker mirrors the text round, ordering it once at the top gets it right in both views. Keep the merits order instead when the options carry one (a spectrum, escalating scope, a chronology), since scrambling that to save a keystroke costs the reader more than it saves.
- **Do the ordering while writing the options, never between the two views.** Reordering at picker time is what breaks the letters, and it's unnecessary: `(Recommended)` marks the pick wherever it sits.
- **Prefix every label with its letter**, as in `(a) Per-page metadata`, `(b) YAML frontmatter`. That makes the correspondence explicit rather than positional, so a `(b)` still reads as `(b)` even when the widget stamps its own numbering down the side.
- Mark the recommended option `(Recommended)` at the end of its label, wherever in the order it happens to fall, so the picker agrees with the `➡️` line.
- Keep the labels short; the rationale lives in the text round, not in the option descriptions.
- The tool caps at 4 questions per call and 4 options per question, and it always appends an "Other" escape for the user's own answer. A wider frontier means batching calls in round order or falling back to the text round alone; never trim the frontier to fit the widget. A question with a fifth option can't be mirrored at all: either fold two options together in *both* views, or leave that one question to the text round rather than showing the picker a truncated list.

## Facts are your job, decisions are theirs

Finding *facts* is never the user's job. If something is discoverable by reading the codebase, docs, or config, find it yourself instead of asking, and reserve your questions for genuine *decisions*, the judgment calls that are the user's to make.

When a frontier question needs a fact from the environment (filesystem, tools, config) and you have a sub-agent tool, **dispatch a sub-agent to find it, and don't block on it.** A running exploration is just an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report; ask the rest of the frontier now and list the blocked one with `⏳` so the user can see it's pending rather than missing. With no sub-agent tool available, look the fact up inline before you put the dependent question to the user.

## When to stop

The grill is done when the frontier is empty, every branch of the design tree visited, nothing left silently assumed. Then hand off, and do not begin implementing until the user explicitly says to proceed.

## What to do with the result

grillkit's job is the shared understanding, not a particular file, but where that understanding lands depends on how the session started:

- **Started from a plan file.** When the input was an existing plan document (e.g. a `plan-<slug>-YYYY-MM-DD.md`), **fold the settled decisions back into that same file by default**, without asking. The user handed you a plan to harden; returning it hardened is the expected outcome. Rewrite that same file in place, without spawning a parallel copy or changing its creation-date suffix, and tell the user you updated it. Only skip or redirect the write if the user explicitly asked for something else (a standalone note, no file, a different location). **Stamp the hardened plan** with a `Grilled: YYYY-MM-DD` line directly under the title (today's date; update it on a re-grill). The stamp is a durable, machine-readable signal that this plan has survived a grill, and downstream tooling reads it as provenance: issuekit, for one, only labels a plan's issues `ready` (safe for unattended work) when the source carries this stamp, and files ungrilled plans as `needs-planning` instead. It is provenance rather than a tracker artifact, so it is written the same way on a project that files no issues at all. No filesystem? Print the stamp line with the recap for the user to add themselves.
- **Started from anything else.** With a rough idea, a design in someone's head, an architecture, or a PR, there's no file to return to, so **ask** where the decisions should go: update some existing file in place, write a standalone note in the current directory, or nothing at all. Don't write a file unprompted and don't assume a location; grillkit doesn't own a canonical plan-doc format or a `docs/plans` convention.

If grilling settled a domain term or a hard-to-reverse trade-off decision worth keeping, **domainkit** is the scribe when installed; otherwise note the settled decision for the user to record as a glossary entry or ADR. grillkit does the interrogating rather than owning that format.

## Hand off

_Write this section in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

Close every grill the same way, naming a sibling skill only when it's installed and otherwise describing the action plainly:

**What changed.** Give a brief recap of the decisions you settled together, each in a line. Name any question you raised and *didn't* resolve; a decision the user deferred is not a decision, and it will surface again downstream as a blocked build.

**Where it landed.** Name the plan file you rewrote in place and its `Grilled:` stamp, or the file you were asked to write instead, or nothing at all when the user declined a file.

**Next.** The stamp is the whole point of finishing a grill, so say what it unlocks. Where the project tracks work in GitHub Issues, a hardened plan is ready to become issues, and **issuekit** reads the stamp to file them as `ready` (safe to work unattended) rather than `needs-planning`. Where it tracks work elsewhere or nowhere, the same stamp clears the plan to be built, so name **implementkit** and its first phase instead. Do not assume the first case: a project on GitHub may still run its backlog in Linear, Jira, or a file, and the prompt or the repo's agent-guide file is what says which. Without a plan file, name what the decisions feed instead, either the build itself (**implementkit**) or a decision record (**domainkit**). Don't start either; grilling ends at the shared understanding.
