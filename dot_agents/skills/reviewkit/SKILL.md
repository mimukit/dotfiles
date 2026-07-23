---
name: reviewkit
description: >-
  Review AI-agent-implemented code specifically — four ordered passes for convention-fit, agent-slop signatures, requirement-completeness, then correctness — against the working tree or the branch diff, findings ranked by severity and backed by quoted evidence. Use when the user says "review this code", "review my changes", "review this diff", "check the agent's work", "/reviewkit", or wants a self-review of AI-written changes before commit or PR — even if they don't name the passes.
license: MIT
allowed-tools: Read, Bash, Grep, Glob, Write
metadata:
  internal: false
---

# reviewkit

Review code an AI agent just wrote, for the failure modes that are specific to AI-generated changes. A generic "find bugs" pass misses the three things agents get wrong most: writing code that is *correct in a vacuum but wrong for this repo*, padding a change with *plausible-looking cruft nobody asked for*, and quietly *leaving part of the job undone*. reviewkit runs those checks first, then a correctness pass, and reports findings ranked by severity — it does not fix anything. Fixing is the human's call, or a handoff to an implement-style skill.

This is a **reviewer, not an editor.** It reads the change and judges it; it never edits source. Its one optional artifact is a review report the user can save to feed a PR description.

## When this fires

After an agent (or the user) finishes a chunk of work and wants it judged before it ships: "review this", "review my changes", "review the diff", "check this code", "self-review before I commit", "/reviewkit", or a bare "does this look right" after a coding session. It reviews **uncommitted work or a branch's diff** — it is not a line-by-line audit of the whole codebase.

It is distinct from a generic correctness linter: reviewkit leads with **convention-fit** and **agent-slop** passes that a bug-focused review skips. If the user only wants correctness bugs, say so and run just that pass — don't pad the report with the other two.

## Procedure

### 1. Pick the review target

Ground the review in an actual diff — reviewing from memory is worthless. Detect the target from git state, then state your pick and let the user override:

- **Uncommitted changes present** (`git status --porcelain` is non-empty) → review the working tree: `git diff HEAD` (include staged with `git diff --staged`). This is the default after a fresh coding session.
- **Clean tree, branch ahead of its base** → review the branch diff. Find the base from `git symbolic-ref --short refs/remotes/origin/HEAD` first; if that local ref is unavailable and network access exists, confirm with `git remote show origin`, then fall back to whichever of `main` or `master` exists. Run `git diff <base>...HEAD` and `git log <base>..HEAD --oneline` for intent.
- **If the invocation names a target** ("review the branch", "review my staged changes") → honor it directly, skip detection.

Say which target you chose and why in one line, then proceed. If neither applies (clean tree, no branch ahead), ask what to review rather than guessing.

**Validate before reviewing.** Confirm the target resolves (`git rev-parse <ref>` for a named base) and the diff is actually non-empty. If the ref doesn't resolve or the diff is empty, stop and say so — reviewing a bad or empty range produces fabricated findings, not a review.

Read the diff in full before judging anything. Note the change's *stated intent* — from the commit messages, the branch name, the plan or issue it references, or the user's own words — because half the review is asking "did it do what was asked, all of it, and *only* that?" Capture that intent concretely: it's the spec both [Requirement-completeness](#4-pass-3--requirement-completeness) and the scope-creep check in [Agent-slop signatures](#3-pass-2--agent-slop-signatures) measure against.

**Ground rules for every pass** — apply these throughout, they are what separate a real review from noise:

- **Skip what tooling already enforces.** Don't report formatting, import order, or lint rules a formatter/linter/CI catches on its own — the whole value of this review is what machines *miss*. Spend it there.
- **Every finding needs evidence.** Quote the offending hunk and name what it violates — a specific line of a repo convention doc, the stated intent, a real API signature, or the concrete failing input. A finding you can't back with a quote is a guess; drop it. This is the primary guard against inventing findings.

### 2. Pass 1 — Convention-fit

Does the change look like the rest of *this* repository wrote it? Agents default to generically-correct code that ignores local idiom. For each changed file, compare against its neighbors — the surrounding code is the spec:

- **Naming & structure** — do new names, file layout, and module boundaries match sibling files? An agent that names a helper `getUserData` in a repo full of `fetch_user` stands out.
- **Established patterns** — does the repo already have a way to do this (an HTTP client, an error type, a logging helper, a test factory) that the change reinvents instead of reusing? Grep for prior art before accepting a new abstraction.
- **Idiom & style** — error handling, async style, imports, formatting conventions the linter doesn't catch. Match what's there, not what's "best practice" in the abstract.
- **Dependencies** — did it add a library for something the repo already solves, or that the project's conventions forbid? Check the manifest and existing imports.
- **Stated conventions** — if the repo documents its conventions (a `CLAUDE.md`, an agent-guide file, a `CONTRIBUTING.md`, or a style guide), read it and hold the change to it. A documented repo rule always overrides a general "best practice."

Named smells that show up here (Fowler's vocabulary — use the label when it fits, it's sharper than a paragraph): *Mysterious Name* (unclear naming), *Shotgun Surgery* (one logical change smeared across many files), *Divergent Change* (one module edited for several unrelated reasons).

### 3. Pass 2 — Agent-slop signatures

Hunt the tells of machine-generated code — the padding that looks productive but earns its keep nowhere:

- **Over-engineering** — abstraction for a single caller, config knobs nothing sets, layers of indirection a direct call would replace, "future-proofing" for requirements that don't exist.
- **Dead & unreachable code** — helpers never called, branches that can't execute, exports nothing imports, variables assigned and never read.
- **Hallucinated or wrong APIs** — calls to methods, flags, or fields that don't exist on the real type; a plausible-sounding function from the wrong library version. Verify against the actual dependency, not the model's guess.
- **Redundant comments** — narration that restates the code (`// increment i`), docstrings that add nothing, commented-out code left behind.
- **Scope creep** — changes outside what was asked: unrelated refactors, reformatting untouched lines, drive-by renames, version bumps nobody requested. Flag anything the stated intent doesn't justify.
- **Fake robustness** — try/catch that swallows errors, defaults that hide failures, tests that assert nothing or are tautological, `TODO`s standing in for real handling.

Named smells that show up here: *Speculative Generality* (abstraction for needs that don't exist — delete it, inline until a real second caller appears), *Duplicated Code* (the same logic pasted across hunks instead of shared), *Primitive Obsession* (a bare string/int standing in for a domain concept), *Middle Man* / *Message Chains* (layers that only delegate, or `a.b().c().d()` navigation). Speculative Generality especially is the signature agent smell.

### 4. Pass 3 — Requirement-completeness

Agents under-deliver as often as they over-deliver: they stub a branch, skip an edge of the ask, or solve the easy 80% and leave the rest silently unfinished. Measure the change against the intent captured in [Pick the review target](#1-pick-the-review-target) — the plan, issue, or user's words — and report the gaps:

- **Missing requirements** — something the ask called for that the diff doesn't do at all.
- **Partial implementation** — a requirement handled for the happy path only, one case of several, or the interface without the behavior.
- **Stubs & placeholders left in** — `TODO`/`FIXME`/`throw new Error("not implemented")`/`pass`/empty handlers presented as if the work were done.
- **Wrong interpretation** — the change does *something*, but not the thing that was asked; it solved a nearby, easier problem.

If there's no captured intent to measure against (no plan, issue, or clear request), say so and skip this pass rather than inventing a spec — don't guess at requirements the user never stated.

### 5. Pass 4 — Correctness

Now the classic review, on what survives the earlier passes:

- **Logic errors** — off-by-one, inverted conditions, wrong operator, mishandled return values.
- **Edge cases** — empty/null/missing input, boundary values, unicode, large payloads, the error path as well as the happy path.
- **State & concurrency** — race conditions, mutation of shared state, ordering assumptions, idempotency, resource cleanup (files, connections, locks).
- **Security** — injection, missing authz/ownership checks, secrets in code or logs, unsafe deserialization, unvalidated input crossing a trust boundary.
- **Tests** — do the changed tests actually exercise the change, and do they pass? Run the repo's test command if one is obvious and cheap; report what you ran and what happened.

### 6. Report the findings

Print the review inline, findings ranked by severity so the reader triages at a glance. Tag each:

- 🔴 **Blocker** — must fix before this ships; a real bug, security hole, missing requirement, or broken convention that will bite.
- 🟡 **Should-fix** — a genuine problem worth addressing, not release-blocking.
- 🟢 **Nit** — polish, style, minor slop; take it or leave it.

For each finding give, in this order: the location as `file:line` (clickable), which pass caught it (convention / slop / completeness / correctness), **a quote of the offending hunk and what it violates** (the convention doc line, the stated requirement, the real API, or the failing input — per the evidence ground rules in [Pick the review target](#1-pick-the-review-target)), what's wrong in one sentence, and the concrete fix. Lead with a one-line verdict — ready, ready-with-fixes, or needs-work — then the findings, most severe first. If a pass found nothing, say so; a clean pass is a real result. **Never invent findings to look thorough** — if you can't quote the evidence, it's not a finding. An empty report on a clean diff is the honest outcome.

Do not edit source or apply fixes. If the user wants the fixes made, hand off: they run an implement-style skill, or fix by hand and re-run reviewkit.

### 7. Optional — save the report

After showing the review, offer to save it (don't save unprompted). If the user wants a durable copy — e.g. to paste into a PR description — write it to `docs/reviews/review-<branch-or-feature-slug>-YYYY-MM-DD.md`, using a short lowercase kebab-case slug and the review's ISO creation date (for example, `review-auth-refactor-2026-07-23.md`). Keep that date stable if the same report is edited. For a genuine same-day collision between distinct reviews, make the slug more specific; only as a last resort insert a sequence immediately before the date (`review-auth-refactor-02-2026-07-23.md`). Create `docs/reviews/` if needed. Keep the saved file identical to what you printed, with a one-line header noting the date and the reviewed range. If there's no filesystem, skip this step and leave the inline report as the deliverable.

## Notes

- **Read-only by contract.** reviewkit runs git and read/search commands to understand the change, and at most the repo's own test command to check correctness. It never edits source, never commits, never pushes. Its only write is the optional report file in [Optional — save the report](#7-optional--save-the-report), and only when the user asks for it.
- **Scale to the diff.** A one-line fix gets a quick pass-through and a one-line verdict; a large feature branch gets the full treatment. Don't pad a small change with ceremony.
- **Not a substitute for tests or CI.** It's a judgment pass on top of them, tuned for how agent-written code fails. Report what the automated gates already cover as covered; spend the review on what they miss — this is the same reason the [review-target ground rules](#1-pick-the-review-target) skip tooling-enforced rules.
- **No shell or git?** Ask the user to paste the diff *and* the original ask, then run the four passes on what they provide and print the report as a codeblock for them to save themselves.
