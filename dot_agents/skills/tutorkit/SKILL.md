---
name: tutorkit
description: >-
  Teach a topic across many sessions — one learning repo with a folder per topic, lessons pitched at what you already know, and spaced retrieval that makes it stick. Use when the user says "teach me X", "tutor me on X", "I want to learn X", "explain how X works", "quiz me on what I learned", "what's due for review", "test me", "am I ready", "exam me on X", "place me on X", "where am I with my learning", "what am I studying", "learning status", "show my progress", or runs "/tutorkit". Tuned for software engineering topics and works for any other.
license: MIT
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, WebSearch, WebFetch, AskUserQuestion, Task, Agent
metadata:
  internal: false
---

# tutorkit

Teach a topic over many sessions and remember what stuck. tutorkit keeps one learning repo with a folder per topic, pitches each lesson at the edge of what the user already knows, writes the lesson as a printable HTML artifact, and schedules retrieval cues that come due later. A tutor is someone who remembers you and adapts; that persistence is the whole design.

Four postures, not four presentations: [`explain`](#mode-explain) answers and writes nothing, [`lesson`](#mode-lesson) teaches and is the only mode that opens a track, [`drill`](#mode-drill) tests recall across topics, [`exam`](#mode-exam) measures and refuses to teach.

[`status`](#mode-status) is a fifth mode and not a fifth posture. It teaches nothing, asks nothing, and grades nothing — it reads the two router files, prints where every track stands, and crowns the next move. Run it to decide which of the four postures to run.

## What tutorkit is not

- **Not a code writer.** It never implements a feature in the user's project. It reads their code to build examples and stops there.
- **Not a decision report.** "Which queue library should we use" is a research question, even though both read primary sources.
- **Not project documentation.** It documents nothing about the user's repo.
- **Not a spaced-repetition engine.** A fixed five-step interval ladder, no SM-2 or FSRS tuning, no Anki export, no retention modelling. The schedule exists to make review happen, not to be optimal.
- **Not general-purpose by design.** It works for any topic and it is tuned for software engineering — repo grounding, runnable exercises, and source-code citations are all sharper there.
- **It never commits the learning repo on its own.**

## Mode selection

**This is the skill's first decision, and the triggers overlap on purpose.** "Explain how X works" is `explain` and "teach me X" is `lesson`, but the wording is a weak signal. Resolve on intent rather than phrasing: a question that wants an answer gets `explain`, a request that wants to end up knowing the thing gets `lesson`. "What's due", "quiz me", "test me" get `drill`. "Am I ready", "how much do I actually know", "exam me" get `exam`. "Where am I", "what am I learning", "learning status", "show my progress" get `status`.

**An ask that names no topic is almost always `status`.** That is the sharpest divider in the whole set: the other four modes need a slug and `status` refuses one. "Am I ready" names a topic and measures it, so it is `exam`; "where am I" names none and reports every track, so it is `status`.

When the ask is genuinely ambiguous, **take the cheap branch** — run `explain` and offer the track at the end. Guessing `lesson` costs a mission interview the user did not want; guessing `explain` costs one extra sentence.

## The learning repo

All state lives in one repo outside the user's work repos, at `~/learning` unless `$TUTORKIT_HOME` names somewhere else. Keeping it out of a work repo is what lets the skill read a work repo for examples without writing notes into it.

```
~/learning/                          ← one git repo; $TUTORKIT_HOME overrides
  INDEX.md                           ← the router
  REVIEW.md                          ← cross-topic due queue, one row per topic
  NOTES.md                           ← how the user likes to be taught, global
  assets/lesson.css                  ← copied from the skill on first run, never overwritten
  topics/<slug>/
    MISSION.md                       ← append-only; why they are learning it, plus the grounding consent
    PROGRESS.md                      ← placement result, what stuck, what is shaky, where they are
    CUES.md                          ← retrieval cues, key points, due dates, interval step, last seen
    SOURCES.md                       ← vetted primary sources, so the agent stops re-searching
    lessons/0001-<dash-case>.html
    reference/<name>.html            ← printable cheat sheets and the glossary
    exercises/                       ← runnable practice, code topics only
```

Create the repo on first use and run `git init` in it. The progress history is genuinely useful and the repo is the user's own. **Never commit automatically** — offer a commit at the end of a session and take no for an answer.

**The routing rule is the load-bearing guard.** Read `INDEX.md` and `NOTES.md` at session start, resolve exactly one slug, then read only `topics/<slug>/`. Never glob across `topics/`. Without this rule the skill degrades as the user learns more, which is the exact wrong direction — thirty topics costs about sixty lines to route and tens of thousands of tokens to open.

Two modes are exceptions, and both are bounded. `drill` resolves its slugs from `REVIEW.md` rather than from the ask, then opens the `CUES.md` of those topics only. It never reads their lessons, and it never globs. Interleaving needs more than one topic in view; it does not need more than one file per topic.

`status` is the stricter exception: it reports on every topic and opens no topic folder at all. That is possible because `INDEX.md` and `REVIEW.md` already carry every field the dashboard prints. **A cross-topic view that opens topic folders is a design failure, not a trade-off** — the two router files exist precisely so this read stays flat as the user's topic count grows.

**When cwd is the learning repo itself, treat it as the learning repo and not as a grounding source.** The two roles never overlap, so a `lesson` run from inside the learning repo skips the grounding question rather than offering to teach the user about their own notes.

### The router

`INDEX.md` carries aliases so a fuzzy ask routes without opening anything:

```markdown
| Topic | Slug | Also called | Status | Last touched |
|-------|------|-------------|--------|--------------|
| Postgres MVCC | `postgres-mvcc` | transaction isolation, snapshot, vacuum, row locking | active | 2026-08-11 |
```

Status is `active` or `learned`. Three routing outcomes, all cheap:

- The ask matches a slug or an alias → open that folder.
- It matches nothing and the user wants depth → create the folder and open a track.
- It matches nothing and the user wants an answer → run `explain` and write nothing.

`REVIEW.md` holds one row per topic, never per cue — `2026-08-18 · postgres-mvcc · 4 due · min step: 3d`. `drill` reads it, sees which topics are due, and opens only those `CUES.md` files. Storing cue text here instead would duplicate the answers and let them drift from the lessons that own them.

**`min step` is the lowest interval step any cue in that topic has reached**, and it earns its place by making one question answerable from the router alone: has this track finished? A topic whose lowest cue sits at `60d` has passed the schedule half of the `learned` gate, so `status` can crown [`exam`](#mode-exam) without reading a single `CUES.md`. Store the minimum rather than an average, because the gate is *every* cue at `60d` and one cue at `1d` fails it.

**Both files are caches, and a cache needs a repair path.** Rewrite the affected row whenever you touch a topic. Rebuild both by scanning `topics/` whenever you find a folder they do not list. Without the self-heal, one hand edit misroutes silently forever.

A `REVIEW.md` row with no `min step` is a row written before this field existed. Read that topic's `CUES.md` once, write the field, and move on. Repairing one row costs one file read; refusing to repair it costs the same read on every later run.

### The stylesheet

`assets/lesson.css` ships beside this file. On first run, resolve this skill's own installed directory and copy the stylesheet to `<repo>/assets/lesson.css` — the working directory is the user's project, not the skill directory, so a relative path will not find it. **Copy it once and never overwrite it.** A later skill update then ships a new default for new repos and leaves every existing lesson rendering the way it was written. Linking the installed path instead would break every lesson the moment the skill moves.

## Mode: `status`

The front door. One screen showing every track, what is due, and the one move worth making next. It never teaches, never asks a question, and never grades an answer.

### 1. Read the two routers, and nothing else

Read `INDEX.md` and `REVIEW.md`. List `topics/` to check for a folder neither file names. Open no topic folder, no `CUES.md`, no `PROGRESS.md`, no lesson.

Listing a directory is not reading it, so the repair rule still runs here. **`status` is the only mode that sees both routers whole, which makes it the one place drift reliably surfaces.** Rebuild a row you find broken, and name the repair in the hand-off.

**No learning repo, or an empty one** — say so in one line and stop. Offer to open a first track. Do not print an empty dashboard.

### 2. Rank — retrieve before you add

One rule produces the crowned move: **finish the retrieval you owe before you take on new material.** A cue that is due decays while it waits, and a lesson does not. Adding a sixth track to five stalled ones feels like progress and is the most common way a learning habit fails.

| # | State | Move → |
|---|-------|--------|
| 1 | any cue is due today or earlier | `drill` |
| 2 | an `active` track has nothing due and `min step` below `60d` | the next `lesson` on that track |
| 3 | an `active` track has nothing due and `min step` at `60d` | `exam` — the transfer test |
| 4 | every track is `learned`, or no track exists | say there is no next step, and offer a new track |

**Ties break on the most recently touched track.** The user's mental model is warmest where they worked last, so that track costs the least to re-enter. This is the same reason a track untouched for months is *not* promoted: crowning the coldest track asks for the most expensive re-entry at the moment the user is only orienting.

Two findings are printed and never crowned, because acting on either is the user's judgement rather than a move the skill can defend:

- **A stale track** — `active`, and untouched for more than 30 days. Name it and say what closes it: one `lesson` to restart it, or `exam` to close it out.
- **More than five `active` tracks.** Attention is the scarce resource here, and a sixth track does not add capacity — it divides the same capacity further. Say the count and say that finishing one beats starting one.

### 3. Print the dashboard

One screen. One line per panel, tables under the panel they belong to, and an empty panel does not print.

```
# Learning status — YYYY-MM-DD

## Tracks    active N · learned N · stale N

Active (N)  — most due first
| Topic | Due | Min step | Last touched |
|---|---|---|---|
| postgres-mvcc | 4 | 3d | 2026-08-11 |
| rust-lifetimes | 0 | 21d | 2026-08-16 |
| raft-consensus | 0 | 60d | 2026-06-02 |

## Review    N cues due across M topics          (omit when nothing is due)

## Learned   <slug>, <slug>                      (omit when none)

## Next move
**→ <the move>** — <how to ask for it>.

Then:
- <runner-up>
- <runner-up>
```

**Sort the table by due count descending, then by last touched descending.** The row you act on first belongs on the first line. Say `— most due first` on the count line, so the reader can check the order against the columns rather than infer it.

**Print every active track.** Past 10 rows, cap the table and close with a `+N more` line. Never truncate silently.

**Write every move line in the procedural register.** One instruction per line, active voice, present tense, no metaphor. Say "run `drill`", not "get back on the horse".

### 4. Write nothing

`status` produces no file. statuskit saves a snapshot because a repo dashboard is a ranked to-do list that exists nowhere else; here every fact on the screen is already durable in `INDEX.md`, `REVIEW.md`, and `PROGRESS.md`. A snapshot would be a third cache to keep honest, and it would go stale the moment the next `drill` run moves a due date.

The one exception is a router row this mode repaired. That is a cache write, not a record of learning. Then go to [Hand off](#hand-off).

## Mode: `explain`

The fast path. One ask, one answer, nothing written — no mission interview, no folder, no index row.

Answer in this order: the shortest correct answer first, then the mechanism, then one worked example, then the primary source to read next. Apply [Citation discipline](#citation-discipline) here as everywhere.

Offer a track **once** at the end — "I can open a track on this and teach it properly over a few sessions" — and take no for an answer. A second offer turns the fast path into the thing it exists to avoid.

## Mode: `lesson`

The core loop, and the only mode that opens a track.

### 1. Route

Read `INDEX.md` and `NOTES.md`. Resolve the ask to exactly one slug. On a known slug, open that topic folder only and go to the target step below. On an unknown slug, open the track first.

### 2. Open the track, on an unknown slug only

Run a **short** mission interview — three or four questions, not an interrogation. What do they want to be able to do with this, by when, and what have they already tried? Then:

- **Ask once for grounding consent.** When cwd is a real project and is not the learning repo, ask whether tutorkit may read it to build examples from their own code. Record the answer in `MISSION.md` as `grounding: <repo path>` or `grounding: declined`, and **never ask again for that topic**. A prompt that fires every lesson gets switched off; one prompt buys the whole track. Consent covers one repo, so a different cwd on a later session asks again.
- Write `MISSION.md` under a `## YYYY-MM-DD` heading.
- Create the topic folder, the `INDEX.md` row, and the first `SOURCES.md` rows from whatever you searched to scope the topic.
- Offer placement — [`exam`](#mode-exam) at track start — so lesson 1 is not pitched blind. On a decline, pitch from the mission interview and say the pitch is a guess.

**`MISSION.md` is append-only.** A mission that drifts gets a new dated entry; existing lessons are never rewritten and never archived. Re-pitching would rewrite files the user may have printed and annotated, and archiving would hide work they did and break the anchors between lessons.

### 3. Pick the target

Read `PROGRESS.md` and `CUES.md`. Pick one target at the edge of what they already know — the next thing that is reachable from what stuck, not the next thing in a syllabus. A wrong belief recorded in `PROGRESS.md` outranks a gap: the wrong model actively blocks the correct one, so it is the higher-value target.

### 4. Make them predict, before you explain

**This is the highest-value part of the skill.** Pose a concrete scenario and make the user commit to a prediction before you teach anything. Wait for the answer. A wrong prediction names their broken mental model, and that model is the actual teaching target — you now know what to correct rather than what to cover.

### 5. Teach the minimum

Teach the mechanism, nothing beside it. Then one worked example. When `grounding` names a repo, build the example out of the user's own code: a lesson on dependency injection written against their actual service container beats one written against `FooService`. Apply [Citation discipline](#citation-discipline) to every non-obvious claim.

### 6. Practice against a feedback loop

Give one piece of practice with a real signal attached. For a code topic, write a runnable file into `exercises/` and print the command that runs it — a test run is the tightest feedback loop available and a browser quiz cannot match it. For a non-code topic, use a scenario the user works through and you grade.

### 7. Gate on explain-back

**The lesson does not close until the user restates the concept in their own words.** That retrieval is what converts fluency into storage strength, and it is the cheapest possible check that the lesson landed. On a thin restatement, re-teach the part they skipped and ask again.

### 8. Write the artifact and schedule the cues

Write the lesson per [The lesson artifact](#the-lesson-artifact). Then:

- Append every source you used to `SOURCES.md`.
- Add 2–4 cues to `CUES.md` per [The spacing schedule](#the-spacing-schedule), each with 2–3 key points that define a correct answer.
- Update `PROGRESS.md` with what stuck, what is shaky, and where they are.
- Rewrite the topic's row in `INDEX.md` and `REVIEW.md`.

Then go to [Hand off](#hand-off).

## Mode: `drill`

Retrieval practice across topics. This is the reason one parent repo exists rather than one repo per topic.

### 1. Build the queue

Read `REVIEW.md`. Open the `CUES.md` of due topics only — never their lessons, never a glob. Collect every cue whose `due` is today or earlier.

### 2. Cap it at 12

Sort by `due` ascending, then by `misses` descending. Fill the 12 slots from `active` topics first and let `learned` topics take what is left. **Print what you left behind** — `12 of 41 · 29 still due`.

An uncapped queue is the failure mode that ends every spaced-repetition habit: forty cues on return trains the user to stop opening it. Hiding the backlog is only a nicer way to lose it. **The overflow keeps its original `due`**, so it stays first in line tomorrow rather than having its debt quietly rescheduled.

### 3. Interleave and ask

Mix cues from different topics rather than running one topic to exhaustion. Ask **one at a time, with no answer visible** — a cue printed beside its answer tests nothing. Show `last seen` on the line when it is far in the past, so the user can judge their own miss with the fact in view.

### 4. Grade, offer the override, then reschedule

Grade the free-text answer against the cue's stored key points per [Grading a free-text answer](#grading-a-free-text-answer), **offer the override on every grade**, then write the new `due`, `step`, `misses`, and `last seen`. On `missed`, re-teach the cue inline in two or three sentences before moving on.

Update `REVIEW.md` and `PROGRESS.md` when the run ends. Then go to [Hand off](#hand-off).

## Mode: `exam`

Measures and never teaches. Ask, grade, record, refuse to explain. Two entry points, one posture — splitting them would name a presentation difference as a behavioural one.

**`drill` and `exam` both ask questions, and the difference is what the answer is for.** `drill` is practice: it asks to strengthen the memory, it repeats a cue for months, and a miss costs one reset. `exam` is measurement: it asks to produce a verdict, it runs twice per track, and the verdict decides where lesson 1 starts or whether the track closes. Never grade a cue in `exam`, and never write a status in `drill`.

### At track start — placement

Pose **3–5 scenario predictions, broad to narrow**, graded on the same three-level scale. **Stop early on two consecutive misses** — a beginner does not need three more questions to prove it.

This reuses the prediction device the skill already owns rather than inventing a second assessment mechanism. Self-report is the weakest signal available, and a single transfer problem fails a genuine beginner flat on first contact.

Write `placed: <rung>` and **every wrong belief, in the user's own words** into `PROGRESS.md`. Those wrong beliefs become lesson 1's target.

### At track end — the transfer test

Pose a problem the user has not seen, which needs the concept without naming it. Solving only the taught shape means the surface was learned, not the concept.

**A topic goes `learned` in `INDEX.md` only when both gates pass:** the transfer test is solved, **and** every cue has reached step `60d`. `exam` is the only mode that writes that status. The transfer test alone would close a topic whose cues still sit at `1d`; cues at `60d` alone measure recall of taught shapes. When one gate passes and the other does not, say which one held it and leave the status `active`.

**A `learned` topic keeps its cues.** Retiring them at close is exactly when forgetting starts. They keep coming due, and the fill order in `drill` stops them displacing a live track.

`exam` writes `PROGRESS.md` at both ends and touches `INDEX.md` only to close a track. It never writes `MISSION.md` — the mission belongs to `lesson`, which is the mode that opens one. Then go to [Hand off](#hand-off).

## The spacing schedule

Intervals: `1d → 3d → 7d → 21d → 60d`. Cues live per topic in `CUES.md`:

```markdown
| id | cue | key points | due | step | misses | last seen |
|----|-----|------------|-----|------|--------|-----------|
| 3 | Why does a long-running read never block a write in MVCC? | readers see a snapshot; writers make a new row version; visibility is decided per transaction | 2026-08-21 | 3d | 1 | 2026-08-18 |
```

- `got it` advances one interval.
- `partial` repeats at the same interval.
- `missed` resets to `1d` and re-teaches the cue inline.

**There is no decay for lateness.** A cue held back by the cap is the skill's debt, not the user's, and the cap can hold a cue thirty days past due. One schedule rule is easier to reason about than two, and the `partial` grade already absorbs most of what a decay rule would.

### Grading a free-text answer

Three grades, judged against the cue's 2–3 stored key points:

- **`got it`** — the answer covers the key points, in any words.
- **`partial`** — some key points, or the right shape with a wrong detail.
- **`missed`** — the key points are absent, or the answer contradicts them.

Binary grading forces a wrong call on the half-right answer, which is most answers. The third grade absorbs that ambiguity instead of resolving it wrongly in either direction.

**Offer the override on every grade, not only on a miss.** The whole interval ladder runs on this judgement, so the user has to be able to correct it — most often when they gave a correct answer in words the key points did not anticipate.

## The lesson artifact

One self-contained HTML file at `topics/<slug>/lessons/NNNN-<dash-case>.html`, linking `../../../assets/lesson.css`. Tufte constraints: one column, generous margins, sidenotes rather than footnotes, and **roughly 700 words as a ceiling**. Working memory is small, and a long lesson is a lesson that does not finish.

Each lesson carries, in order:

1. The one-line tie back to the mission, **naming the dated `MISSION.md` entry it was written against**.
2. The prediction the user made, and where it was wrong.
3. The mechanism.
4. One worked example.
5. The practice, with its feedback loop.
6. The cues that were scheduled.
7. The primary source to read next.
8. Anchors to sibling lessons and reference sheets.
9. A closing line reminding the user that the agent is available for anything still unclear.

Naming the mission entry is what lets a mission change leave old lessons alone: a lesson written against a superseded mission reads as dated rather than wrong.

**Reuse before authoring.** Read `assets/` first and build from the components already there. The stylesheet is what makes a pile of one-off files read as one course, and components the user's own topics earn accumulate beside it. Never inline something a second lesson would duplicate.

**Reference sheets are the thing that gets revisited**, so they carry the compressed essence rather than the narrative — a table, a decision rule, a diagram, not a retelling. Write them to `reference/<name>.html`. A glossary, once written, binds every later lesson.

**Quiz options are the same length in words and characters**, so formatting leaks no answer.

**Opening the lesson is best-effort and never blocking.** Try the platform's opener — `open` on macOS, `xdg-open` on Linux, `start` on Windows — and if none succeeds, print the file path and move on. A lesson that was written successfully must not report failure because a browser did not launch.

## Citation discipline

Every non-obvious claim carries a primary source: the spec, the RFC, the source code, the official docs, the changelog. **Prefer reading source over reading blog posts.** When you cannot find a source, say "I believe X but could not source it" rather than asserting it.

Record what you read in `SOURCES.md` — title, URL, date read, and one line on what it settles — so later sessions stop re-searching the same ground. Check `SOURCES.md` before searching.

## Hand off

_Write this section in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

**What changed** — name the lesson written, the cues scheduled, the grades recorded, and what you marked as shaky. Name what did not change too: a declined track, a cue you could not source, a status you refused to write.

**Where it landed** — give the topic folder path and the lesson path. Give the repo path when this run created the repo.

**Next** — crown one move, chosen by state:

- Cues are due now → run `drill`.
- The track is mid-flight and nothing is due → run the next `lesson`.
- Every cue sits at step `60d` and the track looks finished → run `exam`.
- The track just closed as `learned` → say there is no next step. tutorkit is largely terminal. Do not invent a follow-up.

Then offer a commit of the learning repo. Never run it without a yes.

**A `status` run closes differently, because its whole output is a hand-off.** The dashboard already names the crowned move, so do not print the move twice. State that nothing changed, or name the single router row you repaired. Do not offer a commit on a run that wrote nothing.

Two sibling routes exist, and both are narrow. Name a sibling skill only when it is installed, and otherwise describe the action plainly. Route to a research skill when the question turns out to be a tool decision rather than a knowledge gap. Route to a prototype skill when the only honest answer is to build the thing and find out.

## Notes

- **The context guard beats every other rule here.** A skill that opens thirty topic folders to teach one gets slower as the user learns more. Resolve one slug, open one folder. `status` reports on all thirty and opens none of them, which is the guard working rather than an exception to it.
- **`status` reports; it never grades.** Printing a due count is a fact read. Judging whether the user knows a topic is [`exam`](#mode-exam), and it needs an answer from the user before it can say anything. A dashboard that inferred mastery from a `min step` column would manufacture the exact signal it claims to report.
- **Predict before you explain, every time.** The temptation is to skip it on an easy topic. The prediction is the diagnosis, and teaching without it is teaching blind.
- **Never assert an unsourced claim as fact.** A confident wrong explanation is worse than no lesson, because the user will build on it.
- **No writable filesystem** — a browser-based agent — then say so plainly, print the lesson as a code block for the user to save, and note that spacing cannot persist without state. Do not pretend to schedule a cue you cannot write. `status` still runs when the filesystem is readable, because it writes nothing but a repair; say that the repair was skipped.
