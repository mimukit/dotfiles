---
name: tutorkit
description: >-
  Teach a topic across many sessions, with one learning repo holding a folder per topic, lessons pitched at what you already know, and spaced retrieval that makes it stick. Use when the user says "teach me X", "tutor me on X", "I want to learn X", "explain how X works", "quiz me on what I learned", "what's due for review", "test me", "am I ready", "exam me on X", "place me on X", "where am I with my learning", "what am I studying", "learning status", "show my progress", or runs "/tutorkit". Tuned for software engineering topics and works for any other.
license: MIT
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, WebSearch, WebFetch, AskUserQuestion, Task, Agent
metadata:
  internal: false
---

# tutorkit

Teach a topic over many sessions and remember what stuck. tutorkit keeps one learning repo with a folder per topic, pitches each lesson at the edge of what the user already knows, writes the lesson as a printable HTML artifact, and schedules retrieval cues that come due later. A tutor is someone who remembers you and adapts; that persistence is the whole design.

Four postures, not four presentations: [`explain`](modes/explain.md) answers and writes nothing, [`lesson`](modes/lesson.md) teaches and is the only mode that opens a track, [`drill`](modes/drill.md) tests recall across topics, [`exam`](modes/exam.md) measures and refuses to teach.

[`status`](modes/status.md) is a fifth mode and not a fifth posture. It teaches nothing, asks nothing, and grades nothing. It reads the two router files, prints where every track stands, and crowns the next move. Run it to decide which of the four postures to run.

## What tutorkit is not

- **Not a code writer.** It never implements a feature in the user's project. It reads their code to build examples and stops there.
- **Not a decision report.** "Which queue library should we use" is a research question, even though both read primary sources.
- **Not project documentation.** It documents nothing about the user's repo.
- **Not a spaced-repetition engine.** A fixed five-step interval ladder, no SM-2 or FSRS tuning, no Anki export, no retention modelling. The schedule exists to make review happen, not to be optimal.
- **Not general-purpose by design.** It works for any topic and it is tuned for software engineering, where repo grounding, runnable exercises, and source-code citations are all sharper.
- **It never commits the learning repo on its own.**

## Mode selection

**This is the skill's first decision, and the triggers overlap on purpose.** "Explain how X works" is `explain` and "teach me X" is `lesson`, but the wording is a weak signal. Resolve on intent rather than phrasing: a question that wants an answer gets `explain`, a request that wants to end up knowing the thing gets `lesson`. "What's due", "quiz me", "test me" get `drill`. "Am I ready", "how much do I actually know", "exam me" get `exam`. "Where am I", "what am I learning", "learning status", "show my progress" get `status`.

**An ask that names no topic is almost always `status`.** That is the sharpest divider in the whole set: the other four modes need a slug and `status` refuses one. "Am I ready" names a topic and measures it, so it is `exam`; "where am I" names none and reports every track, so it is `status`.

When the ask is genuinely ambiguous, **take the cheap branch**: run `explain` and offer the track at the end. Guessing `lesson` costs a mission interview the user did not want; guessing `explain` costs one extra sentence.

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

Create the repo on first use and run `git init` in it. The progress history is genuinely useful and the repo is the user's own. **Never commit automatically.** Offer a commit at the end of a session and take no for an answer.

**The routing rule is the load-bearing guard.** Read `INDEX.md` and `NOTES.md` at session start, resolve exactly one slug, then read only `topics/<slug>/`. Never glob across `topics/`. Without this rule the skill degrades as the user learns more, which is the exact wrong direction: thirty topics costs about sixty lines to route and tens of thousands of tokens to open.

Two modes are exceptions, and both are bounded. `drill` resolves its slugs from `REVIEW.md` rather than from the ask, then opens the `CUES.md` of those topics only. It never reads their lessons, and it never globs. Interleaving needs more than one topic in view; it does not need more than one file per topic.

`status` is the stricter exception: it reports on every topic and opens no topic folder at all. That is possible because `INDEX.md` and `REVIEW.md` already carry every field the dashboard prints. **A cross-topic view that opens topic folders is a design failure, not a trade-off**, because the two router files exist precisely so this read stays flat as the user's topic count grows.

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

`REVIEW.md` holds one row per topic, never per cue: `2026-08-18 · postgres-mvcc · 4 due · min step: 3d`. `drill` reads it, sees which topics are due, and opens only those `CUES.md` files. Storing cue text here instead would duplicate the answers and let them drift from the lessons that own them.

**`min step` is the lowest interval step any cue in that topic has reached**, and it earns its place by making one question answerable from the router alone: has this track finished? A topic whose lowest cue sits at `60d` has passed the schedule half of the `learned` gate, so `status` can crown [`exam`](modes/exam.md) without reading a single `CUES.md`. Store the minimum rather than an average, because the gate is *every* cue at `60d` and one cue at `1d` fails it.

**Both files are caches, and a cache needs a repair path.** Rewrite the affected row whenever you touch a topic. Rebuild both by scanning `topics/` whenever you find a folder they do not list. Without the self-heal, one hand edit misroutes silently forever.

A `REVIEW.md` row with no `min step` is a row written before this field existed. Read that topic's `CUES.md` once, write the field, and move on. Repairing one row costs one file read; refusing to repair it costs the same read on every later run.

### The stylesheet

`assets/lesson.css` ships beside this file. On first run, resolve this skill's own installed directory and copy the stylesheet to `<repo>/assets/lesson.css`, because the working directory is the user's project, not the skill directory, so a relative path will not find it. **Copy it once and never overwrite it.** A later skill update then ships a new default for new repos and leaves every existing lesson rendering the way it was written. Linking the installed path instead would break every lesson the moment the skill moves.

## The modes

The mode bodies live in one file each under `modes/`. Route with [Mode selection](#mode-selection), read that one file, and follow it. Everything above this line, and the shared sections below, apply to every mode and are not restated in the mode files.

- Mode `status` → read [modes/status.md](modes/status.md), then follow it.
- Mode `explain` → read [modes/explain.md](modes/explain.md), then follow it.
- Mode `lesson` → read [modes/lesson.md](modes/lesson.md), then follow it.
- Mode `drill` → read [modes/drill.md](modes/drill.md), then follow it.
- Mode `exam` → read [modes/exam.md](modes/exam.md), then follow it.

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

- **`got it`.** The answer covers the key points, in any words.
- **`partial`.** Some key points, or the right shape with a wrong detail.
- **`missed`.** The key points are absent, or the answer contradicts them.

Binary grading forces a wrong call on the half-right answer, which is most answers. The third grade absorbs that ambiguity instead of resolving it wrongly in either direction.

**Offer the override on every grade, not only on a miss.** The whole interval ladder runs on this judgement, so the user has to be able to correct it, most often when they gave a correct answer in words the key points did not anticipate.

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

**Reference sheets are the thing that gets revisited**, so they carry the compressed essence rather than the narrative: a table, a decision rule, a diagram, not a retelling. Write them to `reference/<name>.html`. A glossary, once written, binds every later lesson.

**Quiz options are the same length in words and characters**, so formatting leaks no answer.

**Opening the lesson is best-effort and never blocking.** Try the platform's opener (`open` on macOS, `xdg-open` on Linux, `start` on Windows) and if none succeeds, print the file path and move on. A lesson that was written successfully must not report failure because a browser did not launch.

## Citation discipline

Every non-obvious claim carries a primary source: the spec, the RFC, the source code, the official docs, the changelog. **Prefer reading source over reading blog posts.** When you cannot find a source, say "I believe X but could not source it" rather than asserting it.

Record what you read in `SOURCES.md`, with title, URL, date read, and one line on what it settles, so later sessions stop re-searching the same ground. Check `SOURCES.md` before searching.

## Hand off

_Write this section in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

**What changed.** Name the lesson written, the cues scheduled, the grades recorded, and what you marked as shaky. Name what did not change too: a declined track, a cue you could not source, a status you refused to write.

**Where it landed.** Give the topic folder path and the lesson path. Give the repo path when this run created the repo.

**Next.** Crown one move, chosen by state:

- Cues are due now → run `drill`.
- The track is mid-flight and nothing is due → run the next `lesson`.
- Every cue sits at step `60d` and the track looks finished → run `exam`.
- The track just closed as `learned` → say there is no next step. tutorkit is largely terminal. Do not invent a follow-up.

Then offer a commit of the learning repo. Never run it without a yes.

**A `status` run closes differently, because its whole output is a hand-off.** The dashboard already names the crowned move, so do not print the move twice. State that nothing changed, or name the single router row you repaired. Do not offer a commit on a run that wrote nothing.

Two sibling routes exist, and both are narrow. Name a sibling skill only when it is installed, and otherwise describe the action plainly. Route to a research skill when the question turns out to be a tool decision rather than a knowledge gap. Route to a prototype skill when the only honest answer is to build the thing and find out.

## Notes

- **The context guard beats every other rule here.** A skill that opens thirty topic folders to teach one gets slower as the user learns more. Resolve one slug, open one folder. `status` reports on all thirty and opens none of them, which is the guard working rather than an exception to it.
- **`status` reports; it never grades.** Printing a due count is a fact read. Judging whether the user knows a topic is [`exam`](modes/exam.md), and it needs an answer from the user before it can say anything. A dashboard that inferred mastery from a `min step` column would manufacture the exact signal it claims to report.
- **Predict before you explain, every time.** The temptation is to skip it on an easy topic. The prediction is the diagnosis, and teaching without it is teaching blind.
- **Never assert an unsourced claim as fact.** A confident wrong explanation is worse than no lesson, because the user will build on it.
- **No writable filesystem** (a browser-based agent)? Say so plainly, print the lesson as a code block for the user to save, and note that spacing cannot persist without state. Do not pretend to schedule a cue you cannot write. `status` still runs when the filesystem is readable, because it writes nothing but a repair; say that the repair was skipped.
