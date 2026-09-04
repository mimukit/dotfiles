---
name: ideakit
description: >-
  Think an idea through across many sessions, with one ideas repo holding a folder per idea, a jotpad for the thoughts that have none, one idea open at a time, and nothing written to disk until you ask for it. Use when the user says "capture this idea", "I just had an idea", "jot this down", "random thought", "promote that jot", "let's think about the <X> idea", "brainstorm <X> with me", "what was I thinking about <X>", "where do my ideas stand", "what should I think about next", or names their ideas repo or runs "/ideakit".
license: MIT
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Bash, AskUserQuestion, WebSearch, WebFetch
metadata:
  internal: false
---

# ideakit

Keep one ideas repo, one folder per idea, and think about exactly one of them at a time. ideakit captures an idea the moment it arrives, runs the discussion sessions, reports where every idea stands, dispatches the research and validation work to the kits that own it, and folds an answer back into that idea's own log when the user asks to keep it.

An idea is a subject someone wants to think about, not a project they have committed to building. Some ideas become products. Most stay notes, and that is the design.

A jot is smaller again: a thought with no folder, no slug, and no commitment. The jotpad takes any subject at any time, and a jot earns a folder by coming back.

Eight modes. [`jot`](modes/jot.md) drops a loose thought into the pad. [`promote`](modes/promote.md) turns a jot that keeps returning into its own idea. [`capture`](modes/capture.md) writes an idea down and stops. [`session`](modes/session.md) is the mode that thinks. [`status`](modes/status.md) reports and writes nothing. [`research`](modes/research.md) and [`validate`](modes/validate.md) send a question out and bring the answer back. [`close`](modes/close.md) records a verdict.

**`jot`, `promote`, `capture`, and `close` write on their own. Every other mode offers its writes and takes no for an answer.** See [Saving is a demand, not a default](#saving-is-a-demand-not-a-default).

## Mode selection

Resolve on intent, not on phrasing.

- "Jot this down", "random thought", "add this to the jotpad" get `jot`. It records and stops.
- "Promote that jot", "this one deserves a folder", "make j-042 an idea" get `promote`.
- "I have an idea", "capture this", "write this down" get `capture`. It records and stops.
- "Let's think about X", "brainstorm X", "pick up the X idea" get `session`.
- "Where do my ideas stand", "what should I think about next", "where was I on X" get `status`.
- "Who else builds this", "which library would this need", "what does this category cost" get `research`.
- "Is this a business", "would anyone pay for this", "should I build this" get `validate`.
- "I'm dropping this", "I'm building this", "park this one" get `close`.

**An ask that wants a picture or wants to think, but names no idea, is `status` or `session`, never a guess between them.** `status` reports every idea; `session` asks which one to open. When the ask wants a picture, run `status`. When the ask wants to think, run `session` and ask for the idea.

When the ask is genuinely ambiguous between `capture` and `session`, run `capture` first. A captured idea can always get a session next; a session on an unrecorded idea leaves nothing behind.

**When the ask is genuinely ambiguous between `capture` and `jot`, run `jot`.** A jot costs no folder and no permanent slug, and `promote` upgrades it the moment it earns one. The word "idea" is the discriminator: a user who calls the thought an idea gets `capture`.

## The ideas repo

All state lives in one repo outside the user's work repos, at `~/ideas` unless `$IDEAKIT_HOME` names somewhere else.

```
~/ideas/                            ← one git repo; $IDEAKIT_HOME overrides
  INDEX.md                          ← the router
  jotpad/
    INDEX.md                        ← the jot router
    YYYY-MM-DD.md                   ← that day's jots, written once
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

**The rule holds across the pad in both directions.** A topic mode opens no file under `jotpad/`, and a jotpad mode opens no folder under `topics/`. See [The jotpad](#the-jotpad) for how a jot session bounds its own reads, and [`promote`](modes/promote.md) for the one mode that touches both.

### The three topic files

**`IDEA.md` is the living statement, in two parts.** The head says what the idea is, who it is for, and what has to be true for it to matter. An `## Open` block below it lists the open questions and the possible next moves.

Rewrite the head when a session changed what the idea *is*. Draft a refreshed `## Open` block every session without exception, and save it with the entry it matches. That split gives a checkable bound: **the `## Open` block matches the last `NOTES.md` entry.** It also stops an inconclusive session churning the head for no change.

**`NOTES.md` is the log, and it is append-only.** One `## YYYY-MM-DD` heading per saved session, recording what was decided, what was rejected and why, and the open question the session stopped on. Leave earlier entries alone; a change of mind gets a new dated entry. The log is the record and `IDEA.md` is a cache of it, so rewrite `IDEA.md` from `NOTES.md` when the two disagree.

**`SOURCES.md` collects links**, one row per link with the date read and one line on what it settles. Create it on first use, not at capture. Check it before searching.

### The jotpad

**`jotpad/` holds a thought that has no folder.** Any subject, no slug, no commitment. A folder is a commitment, and most thoughts do not deserve one on the night they arrive. The pad is where they wait.

`jotpad/INDEX.md` is the jot router, one row per jot:

```markdown
| Jot | Id | Summary | Entries | State |
|-----|----|---------|---------|-------|
| Cheap OCR for receipts | `j-042` | A phone photo of a receipt turned into a line-item table, run locally | 2026-08-24, 2026-09-02 | live |
```

State is `live`, `promoted`, or `dropped`. A `promoted` cell carries the slug it became: `` `promoted` · `agent-memory` ``. A `dropped` row stays, so the same thought does not come back as a new jot. **The `Summary` cell is one line and carries the same bound as the idea router**, because this table also gets read whole.

`jotpad/YYYY-MM-DD.md` holds that day's jots, one block each:

```markdown
## j-042 · Cheap OCR for receipts

Two to six lines in the user's own words: what the thought is, and what set it off.
```

**A dated file is written once and never edited again.** Every state change lands in `jotpad/INDEX.md` instead. The pad then has one place to look and one place to repair, and the date a thought arrived survives everything that happens to it afterwards.

**An id is permanent and never reused.** Allocate it by reading `jotpad/INDEX.md`, taking the highest id, and adding one. A jot the user returns to gets a second block under the same id in the new day's file, and its row gains that date. **Three entries is the promotion signal**, because the user has now come back twice and that is what a folder is for.

**Dropping a jot is a one-cell edit.** When the user says a jot is nothing, set its state to `dropped` and write nothing else. It needs no mode and no verdict entry: a jot never claimed enough to need one.

**The isolation guard covers the pad.** A `jot` run reads `jotpad/INDEX.md` and `INDEX.md`, both bounded routers. A jot discussion reads those plus only the dated files that one jot's row names. Neither opens a folder under `topics/`, and no topic mode opens a file under `jotpad/`. [`promote`](modes/promote.md) is the single crossing, and it reads one jot and writes one topic folder.

A dated file does hold unrelated jots side by side, so reading one thread carries its neighbours into the window. That cost is accepted and it is bounded. The pad holds loose thoughts by definition, and a thread heavy enough to be worth protecting from them is a thread that has earned `promote`.

### The router is a cache, so repair it

Repair runs at two levels, and each mode repairs only what it can see.

- **Offer a topic's router row rewrite whenever a mode has that folder open and changed it**, in the same save offer as the entry that changed it. `capture` and `close` write their row without asking.
- **Report an unregistered folder rather than opening it.** A folder missing from the router needs five fields that live inside it, and reading it would break the guard for a bookkeeping errand. So `status` names the folder and says to run `session` on it to register it.
- **Repair the jot router without asking.** Its cells hold an id, entry dates, and a state, which is bookkeeping rather than thinking. A jot's row is the only record of that jot's state, so it is written whenever a mode changes one.

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

**`jot`, `promote`, `capture`, and `close` are exempt, because in each the ask is the write.** "Jot this down", "give that one a folder", "write this down", and "I'm dropping this" are demands already made, and the file is the whole output of the mode. Turning one into an offer asks the user to confirm the thing they just requested. `promote` still confirms the slug before it creates anything, which is a different question: not whether to write, but under what permanent name.

**The user can say "save that" at any point.** Write the entry then, and carry on. Offer a save unprompted only once mid-session, when the discussion settles something that would cost real work to reconstruct.

**The cost, stated plainly.** `session` opens on a status report, and `status` crowns the coldest idea carrying an open question. Both read `NOTES.md`. Unsaved sessions leave those reads behind what the user actually thinks. The hand-off says so on every run that writes nothing, so a thin log never passes for a quiet month.

## The modes

The mode bodies live in one file each under `modes/`. Route with [Mode selection](#mode-selection), read that one file, and follow it. Everything above this line, and the shared sections below, apply to every mode and are not restated in the mode files.

- Mode `jot` → read [modes/jot.md](modes/jot.md), then follow it.
- Mode `promote` → read [modes/promote.md](modes/promote.md), then follow it.
- Mode `capture` → read [modes/capture.md](modes/capture.md), then follow it.
- Mode `session` → read [modes/session.md](modes/session.md), then follow it.
- Mode `status` → read [modes/status.md](modes/status.md), then follow it.
- Mode `research` → read [modes/research.md](modes/research.md), then follow it.
- Mode `validate` → read [modes/validate.md](modes/validate.md), then follow it.
- Mode `close` → read [modes/close.md](modes/close.md), then follow it.

## The dispatch contract

`research` and `validate` both send a question to a sibling skill. Four rules govern every dispatch:

- **Let the sibling answer inline.** researchkit and validatekit both default to answering in the conversation and saving nothing, and that default is ideakit's too. Do not answer their save prompt on the user's behalf.
- **Suppress the sibling's hand-off and print ideakit's own.** The dispatch is a sub-step, and two competing next-step lines help nobody.
- **Offer the artifact after the answer, never before.** Ask once whether to keep it. On a yes, write the file yourself from the sibling's inline answer, at `topics/<slug>/docs/…`, keeping the sibling's own subpath and filename convention. Re-running the sibling to save would land the file in the working directory, because a sibling skill documents its own root and defers to no host. Asking before the dispatch asks before the user knows whether the answer was worth keeping.
- **Fold back only what gets saved.** On a yes, offer the dated `NOTES.md` entry naming the question, the answer, and the artifact path, together with the `IDEA.md` and router updates. On a no, the answer stays in the conversation and the log stays as it was.

The idea's own log holds one authoritative thread of everything the user kept, so a later session reads one file and finds every saved answer.

## Hand off

_Write this section in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

**What changed.** Name the entry written, the artifact saved, and the status set. Name what did not change too: a save the user declined, a folder you reported and did not open, a dispatch that ran the short version, a verdict you refused to write without a reason.

**Say when a run wrote nothing.** State it in one line: this session leaves no record in the repo. Do not soften it, and do not imply the discussion was saved. Offer the save once more only if the user asks.

**Where it landed.** Give the topic folder path. Give the jot file path and the jot id when a mode wrote a jot. Give the artifact path when a mode wrote one. Give the repo path when this run created the repo.

**Next.** Crown one move, chosen by state:

- The run wrote a jot → say there is no next step. Do not offer a session on it.
- A `live` jot carries three or more entries → run `promote` on that jot.
- The jot just became an idea → run `session` on the new slug.
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
- **The user decides what gets kept.** Compose the write, show it, and wait. `jot`, `promote`, `capture`, and `close` are the exemptions, and there are no others.
- **`capture` and `jot` both stop.** Their job is to lose nothing when a thought arrives at a bad moment. Turning either into a session is how the thought gets dropped instead.
- **The pad takes anything, and the folder is what gets earned.** A jot needs no subject, no slug, and no relevance to an existing idea. `promote` is the gate, and returning to a thought is what opens it.
- **Never rename a slug, and never reuse a jot id.** Confirm the slug at creation and leave it alone. The router's `Idea` column is where a changed name goes.
- **This repo ships no code.** ideakit never writes application code and never opens issues. An idea that becomes real work moves to a project repo and gets issues there.
- **Never commit the ideas repo on its own.**
- No writable filesystem (a browser-based agent)? The save offer becomes a print. Say so plainly, print the `NOTES.md` entry and any artifact as code blocks for the user to save, and give the paths they belong at. Do not report a write that did not happen. `status` still runs when the filesystem is readable.
