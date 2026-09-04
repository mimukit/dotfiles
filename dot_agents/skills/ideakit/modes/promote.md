## Mode: `promote`

Turn a jot into an idea. This is [`capture`](./capture.md) with a source, and it is the one mode that reads the pad and writes a topic folder.

### 1. Route to exactly one jot

Read `jotpad/INDEX.md` and resolve one id. **With no jot named, ask.** Offer the `live` jots, the ones with three or more entries first, and use `AskUserQuestion` when four or fewer fit. Then read only the dated files that jot's row names.

### 2. Match against the idea router

Read `INDEX.md`. Match the jot against every slug, every alias, and every summary, as `capture` does. **When anything is close, show the candidate row and ask** whether this appends to that idea or starts a new one.

### 3. Confirm the slug, then create

On a new idea, propose a slug and **confirm it before writing anything**, because it is permanent. Then create `topics/<slug>/`, write `IDEA.md` from the jot's own blocks, and write the first dated `NOTES.md` entry. **That entry names the jot id and the date the thought first arrived**, so the folder carries its own origin.

On an append, add a dated `NOTES.md` entry carrying the jot's blocks, refresh the `## Open` block, and rewrite the router row.

### 4. Flip the jot row and leave the blocks alone

Set the jot's state to `` `promoted` · `<slug>` ``. **Cut nothing out of any dated file.** The pad records when the thought arrived and how it read at the time, and moving the text destroys that record for no gain.

**Done when** `topics/<slug>/` holds `IDEA.md` and a first `NOTES.md` entry naming the jot id, the idea router carries its row, and the jot row reads `promoted`. Then go to [Hand off](../SKILL.md#hand-off).
