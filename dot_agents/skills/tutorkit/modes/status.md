## Mode: `status`

The front door. One screen showing every track, what is due, and the one move worth making next. It never teaches, never asks a question, and never grades an answer.

### 1. Read the two routers, and nothing else

Read `INDEX.md` and `REVIEW.md`. List `topics/` to check for a folder neither file names. Open no topic folder, no `CUES.md`, no `PROGRESS.md`, no lesson.

Count each topic's due cues from the dates in its `REVIEW.md` row: the dates on or before today. A stored count, if an old row carries one, is not read as current.

Listing a directory is not reading it, so drift still surfaces here. **`status` is the only mode that sees both routers whole, which makes it the one place drift reliably surfaces.** It reports drift and repairs none of it, per the cache rules in [The router](../SKILL.md#the-router): name each folder the routers miss and each row in an old format, and print `run lesson on <slug>` beside it.

Done when every router row has a derived due count, and every folder under `topics/` is matched to a row or named as missing.

**No learning repo, or an empty one?** Say so in one line and stop. Offer to open a first track. Do not print an empty dashboard.

### 2. Rank, and retrieve before you add

One rule produces the crowned move: **finish the retrieval you owe before you take on new material.** A cue that is due decays while it waits, and a lesson does not. Adding a sixth track to five stalled ones feels like progress and is the most common way a learning habit fails.

| # | State | Move → |
|---|-------|--------|
| 1 | any cue is due today or earlier | `drill` |
| 2 | an `active` track has nothing due and `min step` below `60d` | the next `lesson` on that track |
| 3 | an `active` track has nothing due and `min step` at `60d` | `exam`, the transfer test |
| 4 | no row above matches (every track is `learned`, or no track exists) | say there is no next step, and offer a new track |

Take the first row that matches. Row 4 also catches every state the rows above miss, so exactly one move is always crowned.

**Ties break on the most recently touched track.** The user's mental model is warmest where they worked last, so that track costs the least to re-enter. This is the same reason a track untouched for months is *not* promoted: crowning the coldest track asks for the most expensive re-entry at the moment the user is only orienting.

Two findings are printed and never crowned, because acting on either is the user's judgement rather than a move the skill can defend:

- **A stale track**, meaning `active` and untouched for more than 30 days. Name it and say what closes it: one `lesson` to restart it, or `exam` to close it out.
- **More than five `active` tracks.** Attention is the scarce resource here, and a sixth track does not add capacity; it divides the same capacity further. Say the count and say that finishing one beats starting one.

### 3. Print the dashboard

One screen. One line per panel, tables under the panel they belong to, and an empty panel does not print.

```
# Learning status: YYYY-MM-DD

## Tracks    active N · learned N · stale N

Active (N), most due first
| Topic | Due | Min step | Last touched |
|---|---|---|---|
| postgres-mvcc | 4 | 3d | 2026-08-11 |
| rust-lifetimes | 0 | 21d | 2026-08-16 |
| raft-consensus | 0 | 60d | 2026-06-02 |

## Review    N cues due across M topics          (omit when nothing is due)

## Learned   <slug>, <slug>                      (omit when none)

## Next move
**→ <the move>.** <How to ask for it.>

Then:
- <runner-up>
- <runner-up>
```

**Sort the table by due count descending, then by last touched descending.** The row you act on first belongs on the first line. Say `most due first` on the count line, so the reader can check the order against the columns rather than infer it.

**Print every active track.** Past 10 rows, cap the table and close with a `+N more` line. Never truncate silently.

Add a `Needs repair` line under the table when [Read the two routers, and nothing else](#1-read-the-two-routers-and-nothing-else) found drift, one slug per item with its move. Done when every active track is a row or inside the `+N more` count, and the crowned move appears exactly once.

**Write every move line in the procedural register.** One instruction per line, active voice, present tense, no metaphor. Say "run `drill`", not "get back on the horse".

### 4. Write nothing

`status` produces no file and edits none. statuskit saves a snapshot because a repo dashboard is a ranked to-do list that exists nowhere else; here every fact on the screen is already durable in `INDEX.md`, `REVIEW.md`, and `PROGRESS.md`. A snapshot would be a third cache to keep honest, and it would go stale the moment the next `drill` run moves a due date.

A router row it found broken is reported, not rewritten: rewriting it needs the topic's `CUES.md`, and that would open a folder. Then go to [Hand off](../SKILL.md#hand-off).
