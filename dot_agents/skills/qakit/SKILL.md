---
name: qakit
description: >-
  Generate a step-by-step manual QA and test plan for a feature just implemented, grounded in the actual code changes, and save it to ./docs/qa for a human to run. Use when a coding session wraps and you want to hand-test the result, or the user says "write a QA plan", "make a manual test plan", "how do I test this", "generate a testing plan for this feature", or runs /qakit.
license: MIT
metadata:
  internal: false
---

# qakit

Turn a feature an AI agent just implemented into a **manual QA plan a human can actually run** — concrete steps, expected results, and pass/fail boxes, grounded in what the code actually changed rather than a generic checklist. The plan is written to `./docs/qa/` so a person can walk it top to bottom and sign off on the feature by hand.

This is **manual** QA — steps that genuinely need a human to perform and judge (click through a flow, read a screen, feel out the UX), not checks a machine can do on its own. The value is a disciplined, diff-grounded plan: what to test, in what order, with what setup, and how to know it passed — focused on the things that *can't* be verified without a human eye.

Anything an AI agent or script can confirm on its own — running a terminal command and reading its output, hitting an endpoint, asserting a return value — does **not** belong in the human's checklist. The agent runs those itself and reports the results in an **Automated verification** section at the end of the plan, so the human sees them confirmed without re-running them by hand.

## When this fires

The user finishes building something and wants to verify it by hand: "write a QA plan", "manual test plan", "how do I test this feature", "give me a testing checklist", "/qakit", or a bare "QA this" after a coding session. qakit produces a plan a **human** runs — it never writes or runs test code. If the user wants *automated* tests (unit, integration, E2E), that's a separate concern for a testkit-style skill; say so and don't produce a manual plan for it.

## Procedure

### 1. Scope the feature
Ground the plan in what was actually built — a generic plan is worthless. Gather, in order of preference:

- **The diff**, when a repo is present: `git diff`, `git diff --staged`, and `git log --oneline -10` for recent work. Read it to learn exactly which behaviors, endpoints, screens, flags, or commands changed.
- **The session context** — what the user asked for and what you implemented this session.
- **The user**, only if intent is still unclear. Ask what the feature is *supposed* to do and how they normally exercise it (URL, command, screen, credentials) — one focused question, not an interview.

Write down, for yourself: the feature's intended behavior, its entry points, and its dependencies (services, data, auth, config). Everything downstream hangs off this.

### 2. Derive the test dimensions
Walk every dimension below and generate cases for each one that applies to the feature — skip a dimension only when it's genuinely irrelevant, and say so in the plan so the tester knows it was considered, not forgotten:

- **Happy path** — the feature used exactly as intended, the primary flow end to end.
- **Edge & boundary** — empty input, max/min values, off-by-one boundaries, unusual-but-valid states, duplicates, unicode/large payloads.
- **Negative / error handling** — bad input, missing/expired auth, unavailable dependencies, network failures; assert it fails *gracefully* with a clear message and no corruption.
- **Regression** — nearby behavior the change could have broken (shared components, the prior flow, adjacent features).
- **Security & permissions** — role/ownership checks, access to another user's data, injection-style input, secrets not leaked in logs or responses.
- **Data & state** — persistence after reload/restart, idempotency, correct create/update/delete, no orphaned or stale state.
- **Concurrency & timing** — simultaneous actions, double-submit, race conditions, retries, slow responses.
- **Compatibility** — where there's a UI: target browsers/OS/devices, responsive/mobile layout, dark mode.
- **Accessibility** — keyboard navigation, focus order, screen-reader labels, contrast — where there's a UI.
- **Performance** — responsiveness under realistic or large data volumes; no obvious slowdown or leak.
- **Usability / UX** — the feel a human must judge: clear copy, sensible defaults, discoverable actions, helpful empty/loading states.

Prioritize: tag each case with one of three tiers, each carrying an emoji so the tester reads urgency at a glance:

- 🔴 **Critical** — must pass to ship; a failure blocks release.
- 🟡 **Normal** — should pass; a failure is a real bug but not a blocker.
- 🟢 **Low** — nice-to-have, polish, or edge cases with minor impact.

Don't pad — one clear case per behavior beats ten redundant ones. Scale the count to the feature's surface area and risk.

**Split human-only from agent-verifiable.** As you generate cases, sort each one: does confirming it *require a human* (visual judgment, real interaction, UX feel), or can an agent/script confirm it by running a command and reading output? Keep only the human-only cases as numbered test cases in the plan. Run the agent-verifiable checks yourself and record their outcomes in the **Automated verification** section — never list a command-and-check-output step as a manual case for the human to run by hand.

### 3. Write the plan file
Write to `./docs/qa/<feature-slug>-qa.md` (slug = short kebab-case name of the feature, e.g. `login-throttle-qa.md`). Create `./docs/qa/` if it doesn't exist. If a plan for this feature already exists, ask before overwriting.

Structure the file like this (the outer fence below is shown with four backticks only so the inner ```sh blocks display — the real file uses normal triple-backtick fences):

````markdown
# QA Plan: <Feature name>

_Generated <date> · covers <commit range or brief scope>_

## Summary
One or two sentences: what the feature does and what "working" means.

## Preconditions
- Environment / branch / build to test on
- Setup, seed data, credentials, feature flags, config
- How to launch — run:

```sh
<launch command>
```

## Test cases at a glance

Priority legend: 🔴 Critical · 🟡 Normal · 🟢 Low

| # | Test case | Priority |
|------|-----------|----------|
| TC-1 | <short title> | 🔴 Critical |
| TC-2 | <short title> | 🟡 Normal |
| TC-3 | <short title> | 🟢 Low |

## Test cases

### TC-1 — <short title>  ·  🔴 Critical
**Steps**
1. <concrete action a human takes>
2. <next action — if it's a command to run, put it in its own block:>

```sh
<command to run>
```

**Expected:** <observable result>
**Actual:** _(tester fills in)_

- [ ] Pass
- [ ] Fail

### TC-2 — <short title>  ·  🟡 Normal
...

## Regression checks
- [ ] <nearby behavior that must still work>

## Automated verification (by AI agent)
_Checks the agent ran itself — no action needed from the tester; listed here for context and sign-off._

Commands run (grouped where related):

```sh
<command 1>
<command 2>
```

- ✅ <command 1> → <what the output confirmed>
- ✅ <endpoint / assertion checked> → <result>
- ❌ <anything that failed, with the actual output> _(if any)_

## Not covered / needs human judgment
- <anything that can't be scripted: visual polish, UX feel, external integrations, timing>
````

Rules for good cases:
- **Concrete and reproducible** — real values and exact steps, not "test the login" but "enter `bad@example.com` / blank password, click Sign in".
- **One behavior per case** — a failure should point at exactly one thing.
- **Observable expected result** — what the tester sees or measures, not internal state they can't check.
- **Honest about gaps** — list what the plan can't verify under *Not covered* rather than pretending coverage.
- **Commands go in ```sh code blocks on their own line** — never inline a terminal command in prose or a table cell, so the tester can copy-paste it as-is. Group related commands that run together into a single block; keep unrelated ones in separate blocks.

### 4. Run the automated checks yourself
Before handing off, actually run the agent-verifiable checks you split out in step 2 — terminal commands, endpoint hits, return-value assertions — and record each outcome in the plan's **Automated verification** section (✅ passed with what the output confirmed, ❌ failed with the actual output). This is the one part of the plan the agent completes, not the human. If there's no shell/filesystem, say so and leave the section for the human to fill.

### 5. Hand off
Tell the user the file path and give a one-line summary: how many manual cases (and how many 🔴 critical), plus the automated-verification result (e.g. "6 checks ran, all green"). Suggest they run the manual plan in a fresh checkout/build. Don't mark any *manual* case as passed yourself — those are the human's to execute; the agent only fills the Automated verification section.

## Notes
- **Manual only.** qakit's sole output is a manual QA plan for a human to execute — it never writes or runs unit/integration/E2E tests. Automated testing belongs to a separate testkit-style skill; if that's what the user wants, hand off to it rather than producing a plan here.
- **No filesystem or shell?** You can't write the file or read a diff — instead ask the user to paste the change or describe the feature, then print the finished plan as a codeblock for them to save under `docs/tests/` themselves.
- Keep the plan proportional to the change: a one-line fix needs a few cases, not thirty. Scale the plan to the risk and surface area of what changed.
