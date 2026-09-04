## Mode: `status`

Reports, and writes nothing at all.

### Cross-idea scope, no idea named

Read `INDEX.md` and list `topics/`. **Open no topic folder.** Print one table sorted by last touched, grouped by status, with each row's age in days (`untouched 94 days`). Name any folder the router does not list, and say to run `session` on it to register it.

Read `jotpad/INDEX.md` and report the pad in one line below the table: the count of `live` jots, and every jot with three or more entries named as a promotion candidate. **Open no dated file.** The `Entries` cell already carries the count, which is what that column is for.

There is no stale marker. A tag most rows would wear inside a year is a verdict on a repo whose whole point is that ideas sit, and the crown below already promotes the cold ones.

Then crown one move:

| # | State | Move → |
|---|-------|--------|
| 1 | an `active` idea carries a recorded open question | `session` on the **coldest** such idea, naming its age |
| 2 | a `live` jot carries three or more entries | `promote` on that jot |
| 3 | an `active` idea carries no open question | `session` on it, to find one |
| 4 | a `building` idea carries an open question | `session` on it |
| 5 | every idea is `parked` or `closed`, and no `live` jot exists | say there is no next move, and offer `capture` |

**Within rule 1 the crown goes to the coldest idea, not the warmest.** Cold plus an open question means the user stopped mid-thought, which is the recoverable case, and it is the row a table sorted by recency buries. Ranking on recency would make the crown restate row one.

**No ideas repo, or an empty one?** Say so in one line, offer `capture` or `jot`, and print no empty table.

### Single-idea scope, one idea named

Read `IDEA.md`, the last two or three `NOTES.md` entries, and a **listing** of `docs/` without reading the artifacts. Print what the idea is, where it stands, and the open questions. Then crown one move:

| # | State | Move → |
|---|-------|--------|
| 1 | an open question blocks the others | `session` on that question |
| 2 | the idea rests on an unresearched external fact | `research` |
| 3 | the idea is a business and has no verdict | `validate` |
| 4 | the idea is settled enough to shape work | plan it in the project repo |
| 5 | nothing is open and no next question exists | `close`, naming which verdict fits |

**Done when** the printed state matches the files read and exactly one move is crowned. Then go to [Hand off](../SKILL.md#hand-off).
