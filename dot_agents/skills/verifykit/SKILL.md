---
name: verifykit
description: >-
  Prove a frontend feature actually works by driving it in a real browser and capturing screenshots + a short GIF as PR-ready proof, published so a pull request can embed it inline. Use when a frontend change is built and you want visual evidence it works before opening the PR — "verify this feature", "capture proof it works", "record the flow working", "prove the UI change", "/verifykit", or when a PR needs proof artifacts to attach.
license: MIT
metadata:
  internal: false
---

# verifykit

Drive a just-built frontend feature the way a user would, capture what happens — screenshots at each meaningful state plus one short animated GIF of the flow — and publish that proof so a pull request can embed it inline. verifykit is the step between reviewing the code and opening the PR: reviewing reads the source, this **exercises the running feature** and produces visual evidence it works.

It is a **driver and recorder, nothing more**. It does not write tests (that's a test-suite skill), does not produce a human checklist (that's a manual-QA skill), and does not provision environments — it drives the UI it's given and records what it sees.

## When this fires

After a frontend feature is built and you want proof it works before the PR: "verify this", "capture the feature working", "record the flow", "prove the UI change", "/verifykit", or a PR step that needs proof artifacts. It captures a running feature with a visual surface — if the change is backend/CLI-only with nothing to drive, say so and stop rather than inventing a flow.

Distinct from a manual-QA plan (which a *human* runs) and from a code review (which reads source). verifykit is the *automated* drive-and-record; if the user actually wants a hand-test checklist or a source review, point them at the right skill instead of capturing.

## Procedure

### 1. Scope the feature and find the entry point

Ground the run in what actually changed — read `git diff` (and the linked issue/plan when there is one) to learn which screens, routes, components, or flows the change touches. Determine how to launch the app and reach the feature: the dev-server command and URL. If the project already documents how it runs, follow that; otherwise infer it and confirm the entry URL before driving.

Pick a **slug** for this run — the linked **issue number** when there is one, else a short lowercase kebab-case **feature slug** from the branch/diff (e.g. `login-throttle`). Form the bundle name as `verify-<slug>-YYYY-MM-DD`, using the run's ISO creation date at the end. Everything for the run is grouped under it.

### 2. Choose the flows to drive

Derive candidate flows from the diff as distinct **user entry points** — a changed route/page, a form or dialog, a component tied to a user action. Then:

- **Explicit instruction wins** — if the invocation names a flow ("verify the checkout flow"), drive that.
- **One flow** touched → drive it, no question.
- **Multiple flows** touched → list the candidates with short labels and **ask the user which to verify** (allow selecting several). Drive each chosen flow and label its captures as a separate section. Never silently guess a "primary" flow.

### 3. Pick the capture backend (by precedence)

Detect what's available and use the best, in order:

1. a **browser-automation MCP** (drives a real browser, takes screenshots) — preferred;
2. **computer use** / desktop screen capture — fallback;
3. **neither** → degrade: don't fake it. Print a short manual capture recipe (what to click, what to screenshot) and stop.

Record which backend was used in the run notes.

### 4. Handle auth and required state

verifykit reuses state; it never manufactures it. In order: **reuse** an already-authenticated session, a stored browser state file, or test credentials the project already exposes. If the flow is gated and none is available, **ask once** for the entry URL and credentials (or a seed command to run). If the user can't or won't provide them, **degrade gracefully** — capture up to the auth boundary and note where it stopped. Run a seed command you're *handed*, but never invent one, seed a database, or run migrations yourself.

### 5. Drive and capture

Walk each selected flow along its primary happy path as a user would. Capture a **screenshot at every meaningful state** (initial, mid-flow, error/empty states the change introduces, success), and a **short animated GIF** of the whole flow. Keep the GIF proof-grade, not cinema — a few frames per second, modest width, a short clip. When stitching frames into a GIF, `ffmpeg` works well if present:

```sh
ffmpeg -y -framerate 2 -i frame-%02d.png -vf "scale=800:-1" flow.gif
```

Cap the frame rate and width so the GIF stays small (a proof GIF is typically a few hundred KB; screenshots ~100 KB).

### 6. Write the bundle

Save the captures to `docs/verify/verify-<slug>-YYYY-MM-DD/` (for example, `docs/verify/verify-login-throttle-2026-07-23/`) — the screenshots, the GIF, and a fixed `notes.md` recording: the flows driven, the capture backend used, per-step pass/fail, the environment, and any auth boundary the run stopped at. Keep the creation date stable when updating the same bundle. For a genuine same-day collision between distinct runs, make the slug more specific; only as a last resort insert a sequence immediately before the date (`verify-login-throttle-02-2026-07-23`). This directory is **ephemeral** — the assets get published to a hidden git ref (below), not committed to the branch — so add `docs/verify/` to `.gitignore`.

### 7. Publish so a PR can embed the proof

GitHub can't inline media from `gh`, and committing proof GIFs to the branch bloats the repo's history for every clone forever. Instead, publish to a **hidden git ref** (`refs/verify-assets/<slug>`) — the assets live in the repo but a normal `git clone` never fetches that namespace, so there's zero clone bloat, and they render inline in a PR body via SHA-pinned `raw.githubusercontent.com` URLs. This needs a **public** repo (GitHub's image proxy can't authenticate into a private one).

The fragile git plumbing lives in the bundled **`verify-assets.sh`** next to this file — resolve the installed skill directory and call the script there; the current working directory is the target project, not the skill directory. Don't hand-run the plumbing:

```sh
VERIFY_ASSETS="<path-to-this-skill>/verify-assets.sh"

if bash "$VERIFY_ASSETS" check; then
  # publish the bundle; prints the commit SHA to embed
  SHA=$(bash "$VERIFY_ASSETS" publish <slug> docs/verify/verify-<slug>-YYYY-MM-DD/*)

  # resolve the inline-rendering URL for each file
  bash "$VERIFY_ASSETS" url <slug> "$SHA" flow.gif
else
  # private repo: skip publishing and write proof.md with local paths
  echo "private repo — link the local bundle in proof.md for manual attachment"
fi
```

The script also offers `list` (show all `refs/verify-assets/*`) and `delete <slug>` (remove a ref after its PR merges).

Then write the ready-to-embed proof into the bundle's fixed **`proof.md`** (`docs/verify/verify-<slug>-YYYY-MM-DD/proof.md`) — a Markdown fragment embedding the GIF and screenshots by their SHA-pinned raw URLs, captioned per flow. This file is the hand-off contract: the PR step reads it and splices it straight into the pull request body, so it never re-runs the publish. On a private repo (publish skipped), write `proof.md` with the local file paths and a note that they need manual attachment, so the PR step can still surface them.

### 8. Hand off

Report the bundle path, the flows verified (with pass/fail), the capture backend used, and — when published — the commit SHA and the ready-to-embed raw URLs. Offer the PR step next: the artifacts are ready for a pull request's **Proof** section. Don't open the PR from here.

## Notes

- **Driver + recorder, not a provisioner.** It reuses or asks for auth and runs a seed command it's handed; it never creates fixtures, seeds databases, or runs migrations. This keeps it safe (it can't mutate real data) and portable across projects.
- **No mp4.** A hosted mp4 does not embed inline in a PR body — GitHub only renders video uploaded through its web composer — so the proof format is screenshots + GIF. Video is a deliberate later add.
- **Private repos.** Inline rendering needs a public repo. On a private one, `verify-assets.sh check` fails — skip publishing and hand off the local bundle path for manual attachment rather than embedding dead links.
- **Zero clone bloat is the point.** Proof is never committed to the branch; it lives on `refs/verify-assets/*`, which default clones skip. Old refs accumulate on the remote but never in anyone's clone — prune them with `verify-assets.sh delete <slug>` once a PR merges.
- **No shell, no browser, or nothing to drive?** If there's no way to run the app or capture it (e.g. a browser-only agent with no automation surface), don't fake proof — say what's missing and print the manual capture recipe for the user to run themselves.
