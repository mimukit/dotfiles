---
name: handoffkit
description: >-
  Compact the current conversation into a handoff document another agent or session can pick up cold: goal, state, next steps, key artifacts by reference, and constraints. Use when you deliberately run "/handoffkit" (optionally with a focus argument) to hand off work, write a handoff doc, or summarize the session for the next agent.
license: MIT
disable-model-invocation: true
allowed-tools: Read, Write, Glob, Bash
metadata:
  internal: false
---

# handoffkit

Turn everything learned in this conversation into a single **handoff document** a fresh agent, with none of this context, can read and continue from. The point is transfer, not archival: capture the *state and reasoning* that only lives in this session, and **point** at the artifacts that already exist (specs, PRs, commits, diffs, issues) rather than copying them. By default, save it as a Markdown file under `docs/handoffs/`; print it as a copy-pastable block only when the user explicitly asks for inline or terminal output, or when no writable filesystem is available.

## When this fires

The user wants continuity across a context boundary: "write a handoff", "hand this off", "summarize for the next session", "pass this to another agent", "compact this before we run out of context". If they give an argument (e.g. "handoff for finishing the migration"), treat it as the **focus of the next session** and slant the whole document toward it. Lead with what that goal needs and prune what it doesn't.

## What goes in, and what stays out

A handoff earns its keep by carrying what a new agent *can't reconstruct*:

- **Include**: the goal and why it matters; what's done vs. still open; the immediate next action; decisions made and the reasoning behind them; dead ends already ruled out; gotchas, constraints, and how to run/verify.
- **Exclude** (reference instead): anything already written down, meaning specs, ADRs, plans, issues, commit messages, diffs, PR descriptions. Link them by **path or URL**; don't paste their contents. A handoff that restates the diff is noise.
- **Redact**: API keys, tokens, passwords, and personally identifiable information. Never carry secrets into the document. Refer to them by name ("the staging DB password in `.env`"), not value.

## Document shape

Write these sections; drop any that are genuinely empty rather than padding them.

**Two registers, split by section.** **Current state**, **Next steps** and **How to run / verify** are read by someone who is *doing* the work, so write them in ASD-STE100 Simplified Technical English: one instruction per sentence, procedural sentences 20 words or fewer, active voice, present tense, name the actor, no metaphor or idiom, and one term per thing for the whole document. If the top calls it the *worker*, the bottom does not call it the *job runner*. **Goal** and **Decisions & constraints** are read by someone forming a judgment before they touch anything, so they keep ordinary prose with the reasoning intact; flattening a rejected approach into clipped steps strips the *why* that stops the next agent repeating it.

```markdown
# Handoff: <one-line title of the work>

## Goal
What we're trying to achieve and why. If the user gave a focus argument, frame this around it.

## Workspace
Required when the task involves code. The repository root and the worktree path, the branch, the HEAD SHA, the upstream and the count of unpushed commits, the dirty state (each modified, staged, or untracked path, or "clean"), and any stash the session made.

## Current state
What's done and working, what's half-done, what's untouched. Be concrete. Name each check that has not run or is failing, with the command that shows it.

## Next steps
The ordered actions the next agent should take. Start with the very first one.

## Key files & artifacts
Paths and URLs that matter (source files, the spec, the open PR, the failing test). Reference, don't reproduce.

## Decisions & constraints
Choices made and *why*; approaches already ruled out; hard limits and things not to break.

## Open questions / blockers
Unknowns, pending answers, or anything waiting on the user.

## How to run / verify
Commands to build, run, or test, enough to reproduce the current state.

## Suggested skills
Capabilities the next session should reach for, e.g. a commit skill to land the work, a PR skill to open the pull request, a test-plan skill to verify. Name them by function, not by a specific tool that may not be installed. Recommend by relevance to the goal.
```

## Procedure

1. **Reread the session.** Scan the conversation for the goal, the current state, decisions, and loose ends. That is the raw material. The step is done when each section of the shape has its material, or is known to be empty.
2. **Read the workspace** when the task involves code. Read it from git, never from memory of the session, because the session may predate the last commit:

   ```sh
   git rev-parse --show-toplevel; git worktree list
   git branch --show-current; git rev-parse HEAD
   git rev-parse --abbrev-ref @{upstream}; git rev-list --count @{upstream}..HEAD
   git status --short; git stash list
   ```

   `Bash` is declared for these read-only queries only. A failed upstream query means "no upstream", and the document says so. The step is done when every **Workspace** field has a value read in this run.
3. **Separate carry-over from reference.** For each thing worth mentioning, decide: does it live only in this chat (carry it) or is it already an artifact (link it)? The step is done when every item has one of the two labels.
4. **Draft the document** in the shape above, slanted toward the focus argument if one was given. The draft is done when every sentence carries something no linked artifact holds, every empty section is dropped, and **Next steps** opens with one action the next agent can run without reading further.
5. **Redact** any secrets or PII before output. The step is done when no key, token, password, or personal datum appears by value.
6. **Save or print it** according to the output rules below, then close per [Hand off](#hand-off).

## Output

**Default: save a Markdown file.** Write the finished handoff into `docs/handoffs/` in the workspace, creating that directory if it doesn't exist. Name it `NNNN-handoff-<slug>-YYYY-MM-DD.md`, using the next serial, a short lowercase kebab-case subject slug, and the handoff's ISO creation date at the end (for example, `0005-handoff-auth-migration-2026-07-13.md`). To get the serial `NNNN`, list `docs/handoffs/` with `Glob` (`docs/handoffs/*.md`), take the highest leading four-digit serial, and add one; start at `0001` when there is none. The serial is per directory and never reused. Keep the whole name stable if the same handoff is edited, and update the existing file in place. Tell the user the exact path.

**On explicit request: print inline.** When the user explicitly asks for terminal, inline, chat-only, or copy-pastable output, emit the finished handoff as a single Markdown codeblock and do not write a file.

**No writable filesystem: degrade gracefully.** If the environment cannot write files, emit the finished handoff as a single Markdown codeblock and say that no file was created.

## Hand off

_Write this section in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

**What changed.** Nothing in the project itself; the handoff is a new (or updated) document, and say which.

**Where it landed.** Give the exact path (`docs/handoffs/NNNN-handoff-<slug>-YYYY-MM-DD.md`), or "printed inline, no file written" when that's what happened.

**Next.** One move. Start a fresh session pointed at this document, beginning with the handoff's own first next-step. Name that step here so the user doesn't have to open the file to learn it. Nothing else follows in *this* session; the whole point of the handoff is that this context can now end.
