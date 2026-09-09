---
name: verifykit
description: >-
  Show a frontend change in a real browser, or prove it for a PR: drive the feature, capture screenshots (plus a short GIF for proof), and publish proof so a pull request can embed it inline; or set up the browser driver and the publish path on a machine. Use when a frontend change is built and you want to see it or want visual evidence it works before opening the PR: "show me what it looks like", "screenshot this", "verify this feature", "record the flow working", "prove the UI change", "/verifykit", when a PR needs proof artifacts to attach, "set up verifykit", or "install the browser driver".
license: MIT
allowed-tools: Bash, Read, Write, AskUserQuestion
metadata:
  internal: false
---

# verifykit

Drive a just-built frontend feature the way a user would and capture what happens. In `show` mode the capture is a screenshot handed to the operator in the session, cheap enough to answer "did the button move". In `proof` mode it is screenshots plus one short animated GIF, published so a pull request can embed them inline. `setup` readies a machine and a repo for both. verifykit is the step between reviewing the code and opening the PR: reviewing reads the source, this **exercises the running feature**.

It is a **driver and recorder, nothing more**. It does not write tests (that's a test-suite skill, **testkit** when it's installed), does not produce a human checklist (that's a manual-QA skill), and does not provision environments beyond its own driver. It drives the UI it's given and records what it sees.

## When this fires

After a frontend feature is built and you want to look at it or prove it works. It captures a running feature with a visual surface. If the change is backend/CLI-only with nothing to drive, say so and stop rather than inventing a flow.

- **`show`.** "Show me what it looks like", "screenshot this", "what does the page look like now", "did the button move". Screenshots to a local path, nothing published.
- **`proof`.** "Verify this feature", "record the flow working", "prove the UI change", "capture proof for the PR", or a PR step that needs proof artifacts. Screenshots plus a GIF, bundled and published for the PR body.
- **`setup`.** "Set up verifykit", "install the browser driver", "get this machine ready to capture". Installs what is missing and reports what is present.

**When the verb is ambiguous, run `show`.** An invocation that names a PR, proof, a record, or proving is `proof`. Everything else is `show`, because it is cheap and reversible, and escalating to `proof` costs one sentence.

Distinct from a manual-QA plan (which a *human* runs) and from a code review (which reads source). verifykit is the *automated* drive-and-record; if the user actually wants a hand-test checklist or a source review, point them at the right skill instead of capturing.

## Shared procedure

Every capture mode (`show` and `proof`) runs these steps first. `setup` skips them and starts in its own file.

### 1. Scope the feature and find the entry point

Ground the run in what actually changed. Read `git diff` (and the linked issue/plan when there is one) to learn which screens, routes, components, or flows the change touches. Determine how to launch the app and reach the feature: the dev-server command and URL. If the project already documents how it runs, follow that; otherwise infer it and confirm the entry URL before driving.

Pick a **slug** for this run: the linked **issue number** when there is one, else a short lowercase kebab-case **feature slug** from the branch/diff (e.g. `login-throttle`). Each mode forms its run directory from the slug and the run's ISO creation date.

### 2. Choose the flows to drive

Derive candidate flows from the diff as distinct **user entry points**: a changed route/page, a form or dialog, a component tied to a user action. Then:

- **Explicit instruction wins.** If the invocation names a flow ("verify the checkout flow", "show me the settings page"), drive that.
- **One flow** touched → drive it, no question.
- **Multiple flows** touched → list the candidates with short labels and **ask the user which to capture** (allow selecting several). Drive each chosen flow and label its captures as a separate section. Never silently guess a "primary" flow.

### 3. Pick the capture backend (by precedence)

Detect what's available and use the best, in order:

1. a **CLI browser driver on `PATH`** that takes a URL and writes a screenshot to disk, for example `playwright-cli`. Probe each listed binary with `command -v`. Preferred, because it runs from `Bash` and keeps the accessibility tree out of context;
2. a **browser-automation MCP** (drives a real browser, takes screenshots);
3. **computer use** / desktop screen capture;
4. **none of them** → degrade: don't fake it. Print a short manual capture recipe (what to click, what to screenshot), name verifykit `setup` as the next move to install the driver, and stop. Never run `setup` from inside a capture.

Record which backend was used in the hand-off.

### 4. Handle auth and required state

verifykit reuses state; it never manufactures it. In order: **reuse** an already-authenticated session, a stored browser state file, or test credentials the project already exposes. If the flow is gated and none is available, **ask once** for the entry URL and credentials (or a seed command to run). If the user can't or won't provide them, **degrade gracefully**: capture up to the auth boundary and note where it stopped. Run a seed command you're *handed*, but never invent one, seed a database, or run migrations yourself.

## Modes

The mode bodies live in one file each under `modes/`. Route with [When this fires](#when-this-fires), read that one file, and follow it. Everything above this line applies to every mode and is not restated in the mode files.

- Mode `show` → read [modes/show.md](modes/show.md), then follow it.
- Mode `proof` → read [modes/proof.md](modes/proof.md), then follow it.
- Mode `setup` → read [modes/setup.md](modes/setup.md), then follow it.

## Notes

- **`allowed-tools` covers the primary path.** `Bash` runs the CLI browser driver, git, `gh`, `ffmpeg`, `npm`, and the bundled `verify-assets.sh`; `Read` reads the diff and the linked issue; `Write` writes the `proof` bundle; `AskUserQuestion` asks the flow choice, the one auth ask, and `setup`'s install confirm. The **browser MCP fallback is not in that list and cannot be**, because it arrives as MCP tools whose names the server chooses (commonly `mcp__<server>__*`). On a host that enforces `allowed-tools` strictly with no CLI driver installed, grant the browser MCP alongside these four, or verifykit takes its documented degradation: print the manual capture recipe and stop. That degradation is the honest failure, and it never fakes proof.
- **Driver + recorder, not a provisioner.** It reuses or asks for auth and runs a seed command it's handed; it never creates fixtures, seeds databases, or runs migrations. `setup` installs the driver and nothing about the project. This keeps it safe (it can't mutate real data) and portable across projects.
- **`show` is never published.** No GIF, no bundle, no `.gitignore` edit, no hidden ref. The image goes to the operator and nowhere else.
- **No mp4.** A hosted mp4 does not embed inline in a PR body, because GitHub only renders video uploaded through its web composer, so the proof format is screenshots + GIF. Video is a deliberate later add.
- **Private repos.** Inline rendering needs a public repo. On a private one, `verify-assets.sh check` fails, so `proof` skips publishing and hands off the local bundle path for manual attachment rather than embedding dead links.
- **No shell, no browser, or nothing to drive?** If there's no way to run the app or capture it (e.g. a browser-only agent with no automation surface), don't fake proof. Say what's missing and print the manual capture recipe for the user to run themselves.
