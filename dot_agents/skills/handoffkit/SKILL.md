---
name: handoffkit
description: >-
  Compact the current conversation into a handoff document another agent or session can pick up cold — goal, state, next steps, key artifacts by reference, and constraints. Use when the user wants to hand off work, says "write a handoff", "create a handoff doc", "summarize this for the next session", or "pass this to another agent".
license: MIT
disable-model-invocation: true
allowed-tools: Read, Write
metadata:
  internal: false
---

# handoffkit

Turn everything learned in this conversation into a single **handoff document** a fresh agent — with none of this context — can read and continue from. The point is transfer, not archival: capture the *state and reasoning* that only lives in this session, and **point** at the artifacts that already exist (specs, PRs, commits, diffs, issues) rather than copying them. By default, save it as a Markdown file under `docs/handoffs/`; print it as a copy-pastable block only when the user explicitly asks for inline or terminal output, or when no writable filesystem is available.

## When this fires

The user wants continuity across a context boundary: "write a handoff", "hand this off", "summarize for the next session", "pass this to another agent", "compact this before we run out of context". If they give an argument (e.g. "handoff for finishing the migration"), treat it as the **focus of the next session** and slant the whole document toward it — lead with what that goal needs and prune what it doesn't.

## What goes in — and what stays out

A handoff earns its keep by carrying what a new agent *can't reconstruct*:

- **Include**: the goal and why it matters; what's done vs. still open; the immediate next action; decisions made and the reasoning behind them; dead ends already ruled out; gotchas, constraints, and how to run/verify.
- **Exclude** (reference instead): anything already written down — specs, ADRs, plans, issues, commit messages, diffs, PR descriptions. Link them by **path or URL**; don't paste their contents. A handoff that restates the diff is noise.
- **Redact**: API keys, tokens, passwords, and personally identifiable information — never carry secrets into the document. Refer to them by name ("the staging DB password in `.env`"), not value.

## Document shape

Write these sections; drop any that are genuinely empty rather than padding them:

```markdown
# Handoff: <one-line title of the work>

## Goal
What we're trying to achieve and why. If the user gave a focus argument, frame this around it.

## Current state
What's done and working, what's half-done, what's untouched. Be concrete.

## Next steps
The ordered actions the next agent should take — start with the very first one.

## Key files & artifacts
Paths and URLs that matter (source files, the spec, the open PR, the failing test). Reference, don't reproduce.

## Decisions & constraints
Choices made and *why*; approaches already ruled out; hard limits and things not to break.

## Open questions / blockers
Unknowns, pending answers, or anything waiting on the user.

## How to run / verify
Commands to build, run, or test — enough to reproduce the current state.

## Suggested skills
Capabilities the next session should reach for — e.g. a commit skill to land the work, a PR skill to open the pull request, a test-plan skill to verify. Name them by function, not by a specific tool that may not be installed. Recommend by relevance to the goal.
```

## Procedure

1. **Reread the session.** Scan the conversation for the goal, the current state, decisions, and loose ends — this is the raw material.
2. **Separate carry-over from reference.** For each thing worth mentioning, decide: does it live only in this chat (carry it) or is it already an artifact (link it)?
3. **Draft the document** in the shape above, slanted toward the focus argument if one was given. Keep it tight — a new agent should be able to read it in a minute and act.
4. **Redact** any secrets or PII before output.
5. **Save or print it** according to the output rules below, then give a one-line summary of what the next session should do first.

## Output

**Default — save a Markdown file.** Write the finished handoff into `docs/handoffs/` in the workspace, creating that directory if it doesn't exist. Name it `handoff-<slug>-YYYY-MM-DD.md`, using a short lowercase kebab-case subject slug and the handoff's ISO creation date at the end (for example, `handoff-auth-migration-2026-07-13.md`). Keep that date stable if the same handoff is edited, and update the existing file in place. If a genuinely distinct handoff would collide on the same day, make the slug more specific; only as a last resort insert the next available sequence immediately before the date (`handoff-auth-migration-02-2026-07-13.md`). Tell the user the exact path.

**On explicit request — print inline.** When the user explicitly asks for terminal, inline, chat-only, or copy-pastable output, emit the finished handoff as a single Markdown codeblock and do not write a file.

**No writable filesystem — degrade gracefully.** If the environment cannot write files, emit the finished handoff as a single Markdown codeblock and say that no file was created.
