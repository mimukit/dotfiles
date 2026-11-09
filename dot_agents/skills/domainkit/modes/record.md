## Mode: `record`

The default mode: the scribe loop that runs inside design work. A model-fired run always lands here. Every step follows [the consent rule](../SKILL.md#consent-every-mode).

### 1. Detect the moment
A term is being used loosely or inconsistently, or a settled decision clears the three-part ADR bar. In flow, this surfaces mid-grill, mid-plan, or mid-implementation; you don't wait to be called. Done when you can name the one term or the one decision to record, and for a decision, which of the three bar conditions each part of it meets.

### 2. Locate the existing artifacts
Read the repo-root `CONTEXT.md` if it exists (or `CONTEXT-MAP.md` → the right context file for a multi-context project). If neither exists, create `CONTEXT.md` at the repo root when the first glossary term is accepted. For an ADR, scan `docs/adr/` in this checkout and in every other worktree of the repo, and take the highest existing decision number, whether the file is `NNNN-adr-*.md` or the older `adr-NNNN-*.md`. This mode runs no shell command, so find the worktrees with Read and Glob: in a linked worktree, `.git` is a file that names `<main>/.git/worktrees/<name>`; `<main>` is the main checkout, and each `<main>/.git/worktrees/*/gitdir` holds another worktree's path. Scan them all, because parallel worktrees otherwise take the same decision number. Then name every existing ADR the new decision replaces, and read each one's `Status`. Done when you hold the next free number and the list of superseded records (often empty).

### 3. Offer
Show the proposed glossary entry or ADR and ask before writing. When the ADR supersedes older records, show each old record's `Status` change in the same offer, because the new record and its back-links are one update and one yes covers both. Keep the proposal tight enough to accept or redirect at a glance. Done when the user has accepted, redirected, or declined.

### 4. Write on consent
- **Glossary.** Add or adjust the term in place. Keep `CONTEXT.md` to [the content rule](../SKILL.md#the-contextmd-format): overview and glossary only. Be opinionated, so when several words compete, pick one canonical term and list the rest under `_Avoid_`.
- **ADR.** Create `docs/adr/NNNN-adr-<slug>-YYYY-MM-DD.md` at the next number, using a short lowercase kebab-case slug and the decision's ISO creation date (for example, `0007-adr-use-postgres-2026-07-23.md`). Minimal by default; add optional sections only when they carry real value. ADR content is **immutable** once shipped; the `Status` section is the one mutable part, so a later ADR may mark the old record `deprecated` or `superseded by ADR-NNNN`. An older record with no `Status` section gets one added for the flip; that addition is the same permitted edit.
- **Check the ADR before you finish.** Re-list `docs/adr/` just before writing; if another file now holds your number, take the next free one and say so. Write the new ADR, then the `Status` flip on every record it supersedes. Done when no two files share a number, the new ADR's `Status` names each record it supersedes, and each of those records names the new one back.

### 5. Defer when unsettled
If the term or decision isn't actually resolved, don't manufacture certainty. Use grillkit to settle it first when installed, or ask the user to settle it directly, then record the result. Done when the user has settled it or chosen to drop the record.

### 6. Hand off

_Write this section in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

Keep this short. domainkit usually fires *inside* someone else's work, so a long report is an interruption on top of an interruption.

**What changed.** One line: the term added or adjusted, or the ADR written with its number and title, plus each older record whose `Status` flipped.

**Where it landed.** Give the exact path (`CONTEXT.md`, or `docs/adr/NNNN-adr-<slug>-YYYY-MM-DD.md`).

**Next.** Normally, *return to what was interrupted*: name the grill, plan, or implementation this fired inside and pick it straight back up. Only when something genuinely follows from the write does it outrank that: a supersession the user declined to flip leaves the old record's `Status` stale, so name that record; a term that turned out to be contested isn't settled at all, so route to grillkit (when installed) or ask the user to settle it rather than leaving a guess on disk. Invoked directly with nothing to return to? Say what was written and stop, because there is no next step to invent.
