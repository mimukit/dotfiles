## Mode: `task`

A `task` prompt targets **an agent with filesystem access in this repo**: a fresh session, a subagent, an unattended run, an issue body. Every rule below is only correct for that receiver.

### 1. Ground in the repo

The differentiator, and the one thing a browser-based prompt optimizer structurally cannot do. Before writing anything:

- **Resolve every vague reference to a real path or symbol.** *"the auth file"* becomes `src/lib/session.ts`. *"the old flow"* becomes the function that actually implements it, or it stays named as unresolved.
- **Discover commands rather than guessing them.** *"make sure tests pass"* becomes the repo's real test command, found in `package.json`, a `Makefile`, `pyproject.toml`, a `justfile`, or the CI config.
- **Read the repo's agent instruction file** (`CLAUDE.md`, an `AGENTS`-style guide, `.cursorrules`, whatever it uses) to learn what the prompt can **leave out**, not what to copy in. A prompt that re-specifies conventions the agent already reads burns tokens and invites contradiction with the file itself.

Look facts up yourself; reserve questions for genuine decisions.

**Omit with a pointer, never silently.** One line, *"follow the conventions in the repo's agent instruction file"*, costs nothing and holds across tools that each auto-load a different file. Where the prompt must **override** an instruction file, say so explicitly rather than restating the rule and hoping the later text wins.

**Keep the resolution ledger as you go.** Grounding with no gate is a claim, not a mechanism: an agent that reads two files and declares itself grounded emits the same generic prompt every web optimizer emits, while reporting that it didn't. The ledger is what makes it checkable, with every vague reference paired with what it became, and every one that didn't resolve named as unresolved. An empty ledger on an obviously vague input is visibly wrong on the page.

Done when every vague reference and every unnamed command in the input has a ledger row, resolved or named as unresolved.

### 2. Ask at most three, and never block

Three scoping questions, maximum. The cap is affordable *because the repo answers most of them*. Where an answer doesn't arrive, **bake the assumption into the prompt visibly and name it in the ledger**, because a stated wrong assumption is correctable and a silent one isn't. An unresolved reference is not a blocker; it stays in the prompt as a visible stated assumption.

**Ask them answerable.** Every question is a short closed list of labeled options, so the reply is `1b, 2a` rather than a paragraph, and every list carries an option that hands the call back (*"you pick"*). `AskUserQuestion` renders this natively; without it, write the options out as a numbered list. An open question costs more to answer than the answer is usually worth, and a question with no escape hatch is a block wearing a different hat.

A prompt that can't be sharpened because the *work* is unsettled routes upstream through [the routing note](../SKILL.md#the-routing-note), not by blocking.

Done when every question is answered or its assumption is in the ledger.

### 3. Write to the five-part contract

Every `task` prompt carries all five:

| Part | What it is |
|---|---|
| **Goal** | the outcome, stated once, in the receiver's terms |
| **File scope** | the paths in, and the paths deliberately out |
| **Constraints** | what must hold: conventions to follow, things not to touch, decisions already made |
| **Done signal** | a concrete check, meaning a command, a test, or an observable state. Never "when it works" |
| **Stop condition** | where to stop, so the agent doesn't keep going past the ask |

Bake real content in. Long context on top, the ask at the bottom. `task` **assumes a reasoning-native receiver**, and every current coding agent is one, so spending a question on it buys nothing.

On a review-only run, skip this step and check the input against the five parts instead. Done when each of the five parts is present in the prompt, or, on a review-only run, named as present or missing.

### 4. Strip the slop, then scan for brackets

Run [the catalog](../SKILL.md#the-prompt-slop-catalog) filtered to `task`. Then scan the output literally for `[`, `<`, `{{`, and `TODO`, and sort every hit into one of two kinds:

- **Literal.** Text the receiver uses exactly as written: code, a type such as `Array<T>`, a Markdown link, a glob, an HTML tag, a command or path. It stays.
- **Placeholder.** Text standing in for a value nobody has filled in: `[FILE]`, `<your goal here>`, `{{name}}`, a `TODO`. **A surviving placeholder means the prompt isn't finished.**

The test for a doubtful hit: would the receiver act on these exact characters, or would it have to guess what goes there? Output is copy-paste-ready or it isn't done. Done when every hit is classed and no placeholder remains.

### 5. Dry-run

Read the prompt back **as the receiving agent** and state the first thing you would actually do. Fix what that exposes. This is the only step that simulates the reader, which is why it catches the ambiguity every static checklist misses. Done when the first action you state matches the goal and stays inside the file scope.

### 6. Deliver

**The prompt in a fenced block first.** You scroll past nothing to reach the thing you came for. Then a compact **What changed**, meaning the ledger, two to four lines:

```
resolved "the auth file" → src/lib/session.ts
resolved "make sure tests pass" → pnpm test && pnpm typecheck
assumed the change is server-side only; stated in the prompt
could not resolve "the old flow"; left named as unresolved
```

The diagnosis exists so you learn to write the prompt yourself rather than needing this forever.

**The no-rewrite verdict.** promptkit may return *"this is fine, send it"* with the input unchanged, a first-class outcome, because the alternative is the failure every rewrite skill has: changing something to justify having been invoked. It's gated on the three mechanical checks the run already performed, not on a feeling: **every contract part present · no placeholder surviving the scan · no catalog entry firing.** Pass all three and the ledger prints what the prompt already had instead of what changed.

On a review-only run, deliver the diagnosis alone: the ledger, the missing contract parts, the catalog entries that fired, and the placeholders the scan found.

### 7. Hand off

**What changed.** Nothing on disk. `task` writes no files, ever; the artifact is a prompt you're about to paste into the session you're already in, and a file would be a detour on the way to the clipboard. Say the mode you ran and whether it was a rewrite, a review, or a no-rewrite verdict.

**Where it landed.** The fenced block above, ready to paste. On a review-only run, the diagnosis above.

**Next.** Send it. If [the routing note](../SKILL.md#the-routing-note) fired, the crowned move is the upstream one it named instead. If the prompt is meant to drive a build, the receiver is an implementation pass, meaning **implementkit** when installed, otherwise paste it into a fresh agent session. promptkit does not launch it. After a review-only run, fix the listed gaps yourself, or re-run promptkit without "just tell me" for a rewrite.

## A worked `task` run

The example lives in [worked-example.md](../worked-example.md). Read that file before writing a `task` prompt when the five-part contract needs an example; it is one run of the default mode, end to end.
