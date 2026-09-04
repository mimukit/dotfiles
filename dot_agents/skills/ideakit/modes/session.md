## Mode: `session`

The mode that thinks.

### 1. Route to exactly one idea

Read `INDEX.md` and resolve one slug. On an unknown slug, run [`capture`](./capture.md) first, then continue here.

**With no idea named, ask.** Offer the ideas by last touched, plus "a new idea". Use `AskUserQuestion` when four or fewer candidates fit, and a numbered list otherwise. Never guess the idea, and never fall through to `status`.

### 2. Read only that folder

Read `IDEA.md`, then `NOTES.md`, then only the artifacts those two name. Open nothing else.

### 3. Open with the status report

Print the single-idea report from [`status`](./status.md) as the first thing the user sees. The session then starts from where the last one stopped rather than from a cold restatement.

### 4. Discuss

**The posture: state the strongest version of the idea, then name what would kill it.** Build the case first, because an idea argued down before it is stated properly never gets a fair test. Then say the one condition that would end it.

**When the user says they are thinking out loud, build only and skip the stress pass.** Record the kill condition as the open question either way, so an expansive night still costs the log nothing.

### 5. Close the session

Compose three writes, then offer them as one save:

1. The dated `NOTES.md` entry, three to six lines minimum, naming a decision, a rejection, or an open question. That entry is the spine the next session reads.
2. A refreshed `## Open` block for `IDEA.md`, plus a rewritten head when the idea itself changed.
3. The router row, including `Last touched`.

Print all three under their paths and ask save, edit, or drop, as [Saving is a demand, not a default](../SKILL.md#saving-is-a-demand-not-a-default) sets out. On a yes, write them in the order above. On a no, write nothing, and say so in the hand-off.

A full session record goes to `topics/<slug>/docs/sessions/` **only when the user asks for one**. Do not offer it.

A `parked` or `closed` idea that gets a saved session returns to `active` under a new dated entry.

**Done when** the user has seen the composed entry and answered. On a save, the entry names a decision, a rejection, or an open question, the `## Open` block matches that entry, and the router row matches both. On a drop, nothing in the folder changed. Then go to [Hand off](../SKILL.md#hand-off).
