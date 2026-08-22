---
name: ideakit
description: >-
  Think an idea through across many sessions, with one ideas repo holding a folder per idea, one idea open at a time, and nothing written to disk until you ask for it. Use when the user says "capture this idea", "I just had an idea", "let's think about the <X> idea", "brainstorm <X> with me", "what was I thinking about <X>", "where do my ideas stand", "what should I think about next", or names their ideas repo or runs "/ideakit".
license: MIT
allowed-tools: Read, Write, Edit, Glob, Bash, AskUserQuestion, WebSearch, WebFetch
metadata:
  internal: false
---

# ideakit

Keep one ideas repo, one folder per idea, and think about exactly one of them at a time. ideakit captures an idea the moment it arrives, runs the discussion sessions, reports where every idea stands, dispatches the research and validation work to the kits that own it, and folds an answer back into that idea's own log when the user asks to keep it.

An idea is a subject someone wants to think about, not a project they have committed to building. Some ideas become products. Most stay notes, and that is the design.

Six modes. [`capture`](#mode-capture) writes an idea down and stops. [`session`](#mode-session) is the mode that thinks. [`status`](#mode-status) reports and writes nothing. [`research`](#mode-research) and [`validate`](#mode-validate) send a question out and bring the answer back. [`close`](#mode-close) records a verdict.

**`capture` and `close` write on their own. Every other mode offers its writes and takes no for an answer.** See [Saving is a demand, not a default](#saving-is-a-demand-not-a-default).

## Mode selection

Resolve on intent, not on phrasing.

- "I have an idea", "capture this", "write this down" get `capture`. It records and stops.
- "Let's think about X", "brainstorm X", "pick up the X idea" get `session`.
- "Where do my ideas stand", "what should I think about next", "where was I on X" get `status`.
- "Who else builds this", "which library would this need", "what does this category cost" get `research`.
- "Is this a business", "would anyone pay for this", "should I build this" get `validate`.
- "I'm dropping this", "I'm building this", "park this one" get `close`.

**An ask that names no idea is `status` or `session`, never a guess between them.** `status` reports every idea; `session` asks which one to open. When the ask wants a picture, run `status`. When the ask wants to think, run `session` and ask for the idea.

When the ask is genuinely ambiguous between `capture` and `session`, run `capture` first. A captured idea can always get a session next; a session on an unrecorded idea leaves nothing behind.

## The ideas repo

All state lives in one repo outside the user's work repos, at `~/ideas` unless `$IDEAKIT_HOME` names somewhere else.

```
~/ideas/                            ← one git repo; $IDEAKIT_HOME overrides
  INDEX.md                          ← the router
  topics/<slug>/
    IDEA.md                         ← a stable head plus an ## Open block
    NOTES.md                        ← the dated log, append-only
    SOURCES.md                      ← collected links, created lazily
    docs/plans/                     ← a plan skill writes here
    docs/research/                  ← research answers, kept on request
    docs/validation/                ← validation write-ups, kept on request
    docs/sessions/                  ← full session records, on request only
    docs/adr/                       ← decision records
    assets/                         ← diagrams and screenshots
```

**Resolve `$IDEAKIT_HOME` first and write absolute paths.** No mode changes the working directory. A mode fired from a work repo touches no file in that repo, so the host repo's own conventions never apply to what ideakit writes. That is what lets an idea arriving mid-task go straight into the ideas repo.

Create the repo on first use and run `git init` in it. **Never commit automatically.** Offer a commit at the end of a session and take no for an answer.

### The router

`INDEX.md` carries one row per idea, with aliases, so a loose ask routes without opening anything:

```markdown
| Idea | Slug | Also called | Summary | Open question | Status | Last touched |
|------|------|-------------|---------|---------------|--------|--------------|
| Agent memory substrate | `agent-memory` | memory layer, agent recall, context store | A shared store an agent writes facts to and reads back across sessions | Does retrieval beat a bigger window | active | 2026-08-19 |
```

Status is `active`, `building`, `parked`, or `closed`. `building` means implementation runs in another repo, and its cell carries that repo: `` `building` · owner/repo ``. `parked` means the user stopped. `closed` means a verdict is written in that idea's `NOTES.md`.

**The router cell bound: `Summary` and `Open question` are one line each.** Each states *what* the idea is and *what* is open. Neither carries a reason, a position, or a half-formed argument. A Markdown table gets read whole, so the isolation guard below cannot be kept by reading the router selectively; it is kept by bounding what the router is allowed to hold. Ten ideas then cost ten lines to route and nothing to contaminate.

### Read one idea folder, never two

**This is the load-bearing rule.** Read `INDEX.md`. Resolve the ask to exactly one slug. Then read only `topics/<slug>/`. Never glob across `topics/`, and never grep the repo for context. Listing `topics/` is fine, because listing a directory is not reading it.

Two reasons hold it up. Ideas contaminate each other: half-formed thinking about one subject bleeds into the next when both sit in the same window, and the second idea inherits the first one's framing without anyone noticing. And the cost grows the wrong way, because thirty ideas cost about thirty router lines to route and tens of thousands of tokens to open.

**One bounded exception.** Open a second topic folder only when the user names that idea in the ask ("does this connect to the agent memory idea?"). That folder is **read-only** for the session, and the connection is written into the primary idea's `NOTES.md` alone. One session, one owner of the log. When a link looks obvious and the user has not asked, say the link in one sentence and leave the folder shut.

### The three topic files

**`IDEA.md` is the living statement, in two parts.** The head says what the idea is, who it is for, and what has to be true for it to matter. An `## Open` block below it lists the open questions and the possible next moves.

Rewrite the head when a session changed what the idea *is*. Draft a refreshed `## Open` block every session without exception, and save it with the entry it matches. That split gives a checkable bound: **the `## Open` block matches the last `NOTES.md` entry.** It also stops an inconclusive session churning the head for no change.

**`NOTES.md` is the log, and it is append-only.** One `## YYYY-MM-DD` heading per saved session, recording what was decided, what was rejected and why, and the open question the session stopped on. Leave earlier entries alone; a change of mind gets a new dated entry. The log is the record and `IDEA.md` is a cache of it, so rewrite `IDEA.md` from `NOTES.md` when the two disagree.

**`SOURCES.md` collects links**, one row per link with the date read and one line on what it settles. Create it on first use, not at capture. Check it before searching.

### The router is a cache, so repair it

Repair runs at two levels, and each mode repairs only what it can see.

- **Offer a topic's router row rewrite whenever a mode has that folder open and changed it**, in the same save offer as the entry that changed it. `capture` and `close` write their row without asking.
- **Report an unregistered folder rather than opening it.** A folder missing from the router needs five fields that live inside it, and reading it would break the guard for a bookkeeping errand. So `status` names the folder and says to run `session` on it to register it.

### The slug is permanent

A slug is short, lowercase, kebab-case, and taken from the idea's core noun. **`capture` proposes it and confirms it with the user before creating anything**, because no mode renames a folder afterwards. The cost lands once at creation instead of in rename machinery for a rare event. The router's `Idea` column carries the current human name and stays free to change.

### Artifacts land inside the topic folder

**The artifact root is the topic folder, not the repo root.** A skill that documents a path under `docs/` writes it under `topics/<slug>/docs/` instead, keeping its own subpath and filename convention intact. `docs/plans/plan-sso-2026-07-23.md` becomes `topics/<slug>/docs/plans/plan-sso-2026-07-23.md`.

This is a root swap, so it holds for every skill, including one added after this file was written. The repo root has no `docs/` directory and does not gain one.

Filenames follow `<type>-<slug>-YYYY-MM-DD.md`, with the artifact's creation date at the end. Keep that date stable when the file is edited later.

## Saving is a demand, not a default

**The discussion is the deliverable. A file is what the user asks for when the discussion earned one.** Most sessions explore and stop there, and a repo of entries nobody wanted is worse than a thin one, because a later `status` run reads every row as something the user meant.

So every write runs through one gate:

1. **Compose the write anyway.** Draft the `NOTES.md` entry, the `## Open` block, and the router row in full.
2. **Print the draft as a code block, under the absolute path it would land at.**
3. **Ask save, edit, or drop.** Take a no for an answer, and write nothing.

Composing first is what makes the yes cheap. An offer that asks "want me to save this?" with nothing attached gets declined for the wrong reason.

**The gate covers every file, the router row included.** `INDEX.md` holds a summary and an open question, which are thinking rather than bookkeeping, so the row goes with the entry it describes. A session the user did not save did not touch the idea, so `Last touched` stays where it was.

**`capture` and `close` are exempt, because in each the ask is the write.** "Write this down" and "I'm dropping this" are demands already made, and the file is the whole output of the mode. Turning either into an offer asks the user to confirm the thing they just requested.

**The user can say "save that" at any point.** Write the entry then, and carry on. Offer a save unprompted only once mid-session, when the discussion settles something that would cost real work to reconstruct.

**The cost, stated plainly.** `session` opens on a status report, and `status` crowns the coldest idea carrying an open question. Both read `NOTES.md`. Unsaved sessions leave those reads behind what the user actually thinks. The hand-off says so on every run that writes nothing, so a thin log never passes for a quiet month.

## Mode: `capture`

Write the idea down and stop. It does not discuss, does not research, and offers a session once at most.

### 1. Match before you create

Read `INDEX.md`. Match the ask against every slug, every alias, and every summary. **When anything is close, show the candidate row and ask** whether this belongs on that idea or starts a new one. Read only the router here, so the guard holds.

Two folders for one idea splits the log, and the guard means a later session opens one of them with nothing signalling the other exists.

### 2. Confirm the slug, then create

On a new idea, propose a slug and **confirm it before writing anything**, because it is permanent. Then create `topics/<slug>/`, write `IDEA.md` from the user's own words, and write the first dated `NOTES.md` entry.

**When the mode fires from another repo, record that repo in the first entry.** Where an idea arrived from is usually part of the idea.

### 3. Write the router row

Add the row with two or three aliases the user would plausibly say later, the one-line summary, and the open question when one is obvious. Status is `active`.

On an append instead of a create, add the dated `NOTES.md` entry, refresh the `## Open` block, and rewrite the router row.

**Done when** the router row exists and `IDEA.md` states the idea in the user's own words. Then go to [Hand off](#hand-off).

## Mode: `session`

The mode that thinks.

### 1. Route to exactly one idea

Read `INDEX.md` and resolve one slug. On an unknown slug, run [`capture`](#mode-capture) first, then continue here.

**With no idea named, ask.** Offer the ideas by last touched, plus "a new idea". Use `AskUserQuestion` when four or fewer candidates fit, and a numbered list otherwise. Never guess the idea, and never fall through to `status`.

### 2. Read only that folder

Read `IDEA.md`, then `NOTES.md`, then only the artifacts those two name. Open nothing else.

### 3. Open with the status report

Print the single-idea report from [`status`](#mode-status) as the first thing the user sees. The session then starts from where the last one stopped rather than from a cold restatement.

### 4. Discuss

**The posture: state the strongest version of the idea, then name what would kill it.** Build the case first, because an idea argued down before it is stated properly never gets a fair test. Then say the one condition that would end it.

**When the user says they are thinking out loud, build only and skip the stress pass.** Record the kill condition as the open question either way, so an expansive night still costs the log nothing.

### 5. Close the session

Compose three writes, then offer them as one save:

1. The dated `NOTES.md` entry, three to six lines minimum, naming a decision, a rejection, or an open question. That entry is the spine the next session reads.
2. A refreshed `## Open` block for `IDEA.md`, plus a rewritten head when the idea itself changed.
3. The router row, including `Last touched`.

Print all three under their paths and ask save, edit, or drop, as [Saving is a demand, not a default](#saving-is-a-demand-not-a-default) sets out. On a yes, write them in the order above. On a no, write nothing, and say so in the hand-off.

A full session record goes to `topics/<slug>/docs/sessions/` **only when the user asks for one**. Do not offer it.

A `parked` or `closed` idea that gets a saved session returns to `active` under a new dated entry.

**Done when** the user has seen the composed entry and answered. On a save, the entry names a decision, a rejection, or an open question, the `## Open` block matches that entry, and the router row matches both. On a drop, nothing in the folder changed. Then go to [Hand off](#hand-off).

## Mode: `status`

Reports, and writes nothing at all.

### Cross-idea scope, no idea named

Read `INDEX.md` and list `topics/`. **Open no topic folder.** Print one table sorted by last touched, grouped by status, with each row's age in days (`untouched 94 days`). Name any folder the router does not list, and say to run `session` on it to register it.

There is no stale marker. A tag most rows would wear inside a year is a verdict on a repo whose whole point is that ideas sit, and the crown below already promotes the cold ones.

Then crown one move:

| # | State | Move → |
|---|-------|--------|
| 1 | an `active` idea carries a recorded open question | `session` on the **coldest** such idea, naming its age |
| 2 | an `active` idea carries no open question | `session` on it, to find one |
| 3 | a `building` idea carries an open question | `session` on it |
| 4 | every idea is `parked` or `closed`, or none exists | say there is no next move, and offer `capture` |

**Within rule 1 the crown goes to the coldest idea, not the warmest.** Cold plus an open question means the user stopped mid-thought, which is the recoverable case, and it is the row a table sorted by recency buries. Ranking on recency would make the crown restate row one.

**No ideas repo, or an empty one?** Say so in one line, offer `capture`, and print no empty table.

### Single-idea scope, one idea named

Read `IDEA.md`, the last two or three `NOTES.md` entries, and a **listing** of `docs/` without reading the artifacts. Print what the idea is, where it stands, and the open questions. Then crown one move:

| # | State | Move → |
|---|-------|--------|
| 1 | an open question blocks the others | `session` on that question |
| 2 | the idea rests on an unresearched external fact | `research` |
| 3 | the idea is a business and has no verdict | `validate` |
| 4 | the idea is settled enough to shape work | plan it in the project repo |
| 5 | nothing is open and no next question exists | `close`, naming which verdict fits |

**Done when** the printed state matches the files read and exactly one move is crowned. Then go to [Hand off](#hand-off).

## The dispatch contract

`research` and `validate` both send a question to a sibling skill. Four rules govern every dispatch:

- **Let the sibling answer inline.** researchkit and validatekit both default to answering in the conversation and saving nothing, and that default is ideakit's too. Do not answer their save prompt on the user's behalf.
- **Suppress the sibling's hand-off and print ideakit's own.** The dispatch is a sub-step, and two competing next-step lines help nobody.
- **Offer the artifact after the answer, never before.** Ask once whether to keep it. On a yes, write the file yourself from the sibling's inline answer, at `topics/<slug>/docs/…`, keeping the sibling's own subpath and filename convention. Re-running the sibling to save would land the file in the working directory, because a sibling skill documents its own root and defers to no host. Asking before the dispatch asks before the user knows whether the answer was worth keeping.
- **Fold back only what gets saved.** On a yes, offer the dated `NOTES.md` entry naming the question, the answer, and the artifact path, together with the `IDEA.md` and router updates. On a no, the answer stays in the conversation and the log stays as it was.

The idea's own log holds one authoritative thread of everything the user kept, so a later session reads one file and finds every saved answer.

## Mode: `research`

Route to one slug first, then classify the question before acting.

- **A tool, library, framework, or architecture question** goes to a research skill (**researchkit** when installed), answering inline. Offer to keep it at `topics/<slug>/docs/research/` afterwards.
- **A build-or-drop question** is not research. Redirect it to [`validate`](#mode-validate).
- **A market, competitor, category, or customer-signal question** has no sibling owner, so ideakit runs it directly: who else does this, what the category is called, how incumbents price it, and what users publicly complain about. **Give every claim a source and a date.** Offer the result at `topics/<slug>/docs/research/research-<slug>-YYYY-MM-DD.md`.

Without a research skill installed, run the comparison against primary sources directly and **say plainly that it is the short version**.

**Done when** the user has seen the answer and answered the save offer. On a yes, the artifact exists, the `NOTES.md` entry names the question and the answer, and `IDEA.md` and the router row match. On a no, the folder is untouched. Then go to [Hand off](#hand-off).

## Mode: `validate`

Route to one slug, then hand the idea to a validation skill (**validatekit** when installed), answering inline. Offer to keep the write-up at `topics/<slug>/docs/validation/` afterwards.

**Honor the sibling's side-project off-ramp rather than working around it.** It will fire often here, because most ideas in a personal ideas repo are not businesses, and an honest "this is a side project, not a company" is a real answer worth offering to write down.

Offer the verdict, the wedge, and the assignment as one `NOTES.md` entry, with the router status change when the verdict moves it.

Without a validation skill installed, run a short forcing-question set and a graded verdict, and **say plainly that it is the short version**.

**Done when** the user has seen the verdict and answered the save offer. On a yes, the verdict, the wedge, and the assignment are in `NOTES.md`, and the router status matches the verdict. On a no, the folder is untouched. Then go to [Hand off](#hand-off).

## Mode: `close`

Route to one slug. Ask which verdict applies: `building`, `parked`, or `closed`. **Require the reason**, and refuse to write a verdict without one.

Then write, without a save offer. The verdict and its reason are the demand, and the reason question already gave the user a place to stop.

1. Write a dated verdict entry into `NOTES.md`, recording what was decided, what evidence decided it, and what would reopen it.
2. Rewrite `IDEA.md` so the verdict sits at the top of its head.
3. Update the router row.
4. On `building`, record the implementation repo in the status cell and in the entry.

**A closed idea keeps its folder.** This mode never deletes a topic folder, never moves a file out of one, and never migrates anything to another repo. An idea that gets built runs its implementation in a separate repo, and the folder stays open for future thinking about the same subject.

**Done when** the verdict entry, `IDEA.md`, and the router row agree, and nothing else in the folder changed. Then go to [Hand off](#hand-off).

## Hand off

_Write this section in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

**What changed.** Name the entry written, the artifact saved, and the status set. Name what did not change too: a save the user declined, a folder you reported and did not open, a dispatch that ran the short version, a verdict you refused to write without a reason.

**Say when a run wrote nothing.** State it in one line: this session leaves no record in the repo. Do not soften it, and do not imply the discussion was saved. Offer the save once more only if the user asks.

**Where it landed.** Give the topic folder path. Give the artifact path when a mode wrote one. Give the repo path when this run created the repo.

**Next.** Crown one move, chosen by state:

- The session stopped on an open question → run `session` again on that question.
- The open question needs an external fact → run `research`.
- The idea is a business with no verdict → run `validate`.
- The idea is settled enough to shape work → plan it in the project repo, with a plan skill (**plankit** when installed).
- Nothing is open → run `close`, and name which verdict fits.
- The idea just closed → say there is no next step. Do not invent a follow-up.

Then offer a commit of the ideas repo. Never run it without a yes. **Skip the commit offer on a run that wrote nothing.**

**A `status` run closes differently.** Its whole output is a hand-off, and the dashboard already crowns the move. State that nothing changed. Do not print the move twice, and do not offer a commit.

## Notes

- **The isolation guard beats every other rule here.** Resolve one slug, open one folder. `status` reports on every idea and opens none of them, which is the guard working rather than an exception to it.
- **The user decides what gets kept.** Compose the write, show it, and wait. `capture` and `close` are the two exemptions, and there are no others.
- **`capture` stops.** Its job is to lose nothing when an idea arrives at a bad moment. Turning it into a session is how the idea gets dropped instead.
- **Never rename a slug.** Confirm it at creation and leave it alone. The router's `Idea` column is where a changed name goes.
- **This repo ships no code.** ideakit never writes application code and never opens issues. An idea that becomes real work moves to a project repo and gets issues there.
- **Never commit the ideas repo on its own.**
- No writable filesystem (a browser-based agent)? The save offer becomes a print. Say so plainly, print the `NOTES.md` entry and any artifact as code blocks for the user to save, and give the paths they belong at. Do not report a write that did not happen. `status` still runs when the filesystem is readable.
