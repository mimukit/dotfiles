---
name: repokit
description: >-
  Set up a GitHub repo's metadata through the gh CLI — an inferred one-line About description + topics from the repo's own contents, and the issuekit lifecycle labels. Use when the user says "repokit", "set the repo description", "add topics/tags", "write an About blurb for this repo", "provision the workflow labels", "set up this repo's labels", or "configure this repo's metadata" — anything about a repo's About panel or its label vocabulary.
license: MIT
allowed-tools: Bash, Read
metadata:
  internal: false
---

# repokit

Configure a GitHub repository's metadata through the [`gh` CLI](https://cli.github.com), in two explicit **modes**:

- **`about`** — infer a one-line *About* description and a focused set of topics from the repo's own contents (README, manifest, code), show them against whatever is already set, and apply what you approve.
- **`labels`** — provision the issue-workflow **lifecycle labels** (the set [issuekit](https://www.skills.sh) uses to track work), creating what's missing and reconciling what drifted.

Two jobs, one skill, because both answer "make this repo's GitHub metadata right" — the outward-facing blurb people read, and the label vocabulary the issue workflow runs on.

## When this fires

The user wants to set a repo's GitHub metadata. Route to a mode from what they ask:

- **about** — "set the repo description", "add topics", "write an About blurb", "tag this repo", "update the repo's About".
- **labels** — "provision the workflow labels", "set up this repo's labels", "add the issuekit labels", "the `blocked` label is missing".
- **both** — a vague "set up this repo" / "configure repo metadata" → offer to run `about` then `labels`.

**If no mode is clear, ask first** — present the two modes and let the user pick before touching anything.

## Preflight (every mode)

Before any GitHub call, confirm the tooling and target:

```sh
gh --version                                          # gh installed?
gh auth status                                        # authenticated?
gh repo view --json nameWithOwner -q .nameWithOwner   # which repo? (the current dir's remote)
```

- If `gh` is missing or unauthenticated, say so and point to `https://cli.github.com` / `gh auth login` — don't work around it.
- If there's no GitHub remote (the `repo view` call fails), stop and say so — repokit acts on a repo that exists on GitHub.
- **No shell or `gh` at all** (e.g. a browser-based agent)? You can't call `gh`. Do the reasoning from what the user provides and **print the exact `gh` commands** for them to run — the description/topics lines, or the `gh label create` block — as a codeblock to paste.

**Safety stance — the whole skill.** A repo's description, topics, and labels are outward-facing state. **Preview every mutation and get an OK before it runs — nothing changes on GitHub unprompted.** Always echo the exact command(s) you run, so the change is auditable and replayable.

**Re-run safe.** Every mode reconciles against what's already there — running repokit a second time on an unchanged repo proposes nothing and mutates nothing. It's always safe to re-run.

## Detect (every mode)

Read the repo's current state once before proposing anything — it's the raw material every mode reconciles against, and it surfaces guardrails early. Fetch what the chosen mode needs plus the guardrail flags:

```sh
# guardrail flags + about state
gh repo view --json isArchived,isFork,isTemplate,description
gh api repos/{owner}/{repo}/topics --jq '.names'    # current topics (about mode)
gh label list --json name,color,description          # current labels (labels mode)
```

Check the guardrail flags **before** any mutation:

- **Archived** (`isArchived: true`) — GitHub rejects metadata edits on an archived repo; **stop** and tell the user to unarchive first.
- **Fork or template** (`isFork` / `isTemplate`) — its metadata is often inherited or throwaway; **confirm the user means to edit *this* repo** before continuing.

---

## Mode: `about`

Infer the description and topics, reconcile against what's there, apply on approval.

### 1. Start from what's already set
You read the current description and topics in [Detect](#detect-every-mode) — carry them in so you reconcile against curated metadata instead of clobbering it.

### 2. Gather signal from the repo
Read the cheap, high-signal sources first; only dig deeper when they're thin:

- **Primary** — the `README` and the project manifest (`package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `composer.json`, `Gemfile`, …): name, existing description/keywords, dependencies, scripts.
- **Fallback** — only when the above are missing or uninformative: scan the file tree and language mix (`gh repo view --json languages`, a shallow `ls`/`git ls-files`) to infer what the repo *is*.

### 3. Generate the description and topics
- **Description** — one line, plain, specific about what the repo *is/does*, no trailing period, short enough for GitHub's About panel. Say what it is, not how great it is.
- **Topics** — a focused, high-signal set (language, framework, domain, purpose), not keyword-stuffed. Enforce GitHub's format so they'll be accepted: lowercase, digits and single hyphens only, must start with a letter or number, ≤50 chars each, ≤20 topics total. Prefer widely-used topic slugs (e.g. `typescript`, `cli`, `github-actions`) so the repo surfaces under real topic pages.

### 4. Show current vs proposed, let the user decide per field
Present a side-by-side so nothing is a surprise, and let the user accept, edit, or keep-current **each field independently**:

| Field | Current | Proposed |
|-------|---------|----------|
| Description | `old blurb` | `new blurb` |
| Topics | `a, b` | `a, c, d` (+`c`,`d`; −`b`) |

Don't apply anything until the user signs off on the final values.

### 5. Apply, echoing the commands
On approval, write the approved values and print each command you run:

```sh
gh repo edit --description "the approved one-liner"
# reconcile topics to the approved set:
gh repo edit --add-topic new-one --add-topic another --remove-topic dropped-one
```

To *replace the whole topic set* in one call instead of add/remove reconciliation, the topics API is cleaner: `gh api --method PUT repos/{owner}/{repo}/topics -f 'names[]=a' -f 'names[]=b'`. Either is fine — pick whichever expresses the change more simply. If a `gh repo edit` flag is rejected, check `gh repo edit --help`.

---

## Mode: `labels`

Provision the issue-workflow **lifecycle labels** so [issuekit](https://www.skills.sh) (and any workflow that reads them) has the vocabulary it expects. repokit *creates and reconciles* these labels; issuekit only *uses* them. This mode **stands alone** — the lifecycle labels are useful for any issue workflow, so it never checks whether issuekit is installed before provisioning them.

### The canonical set
Provision exactly this map. **Keep it identical to issuekit's lifecycle-labels table** — the two skills mirror one label vocabulary; if you change one, change the other so they never drift.

| name | color | description |
|------|-------|-------------|
| `triage` | `FBCA04` | filed, not yet assessed or broken down |
| `ready` | `0E8A16` | specified and independent — safe to take into its own worktree now |
| `blocked` | `D93F0B` | has an unmet prerequisite (see 'Blocked by #N' in the body) |
| `in-progress` | `1D76DB` | actively being worked in a worktree |
| `in-review` | `5319E7` | a PR is open, awaiting review or merge |
| `needs-info` | `D4C5F9` | stalled pending more detail before it can proceed |
| `wontfix` | `FFFFFF` | will not be actioned |
| `duplicate` | `CFD3D7` | superseded by another issue |

Colors are 6-hex, no leading `#`.

### 1. Check for an existing status scheme first
You read the repo's labels in [Detect](#detect-every-mode). Before diffing, look for a **different-but-equivalent status scheme** the repo already runs — e.g. `status: blocked`, `S-ready`, `blocked ⛔`, or a `needs-*` family that already covers this ground. If one exists, **don't silently add a parallel set** (two ways to say "blocked" is worse than none). Surface it and ask which way to go:

- **Map onto theirs** — treat the repo's labels as canonical; skip provisioning and (optionally) note the name mapping so issuekit-style workflows can be pointed at the existing names.
- **Add the canonical set** — the repo's scheme is incidental or abandoned; provision ours alongside it, and offer to retire the old labels only if the user explicitly asks.

Absent any existing status scheme, go straight to the diff.

### 2. Diff against the canonical set and preview
Sort each canonical label into one of three buckets and show the plan before touching anything:

- **Missing** — not in the repo → will be **created**.
- **Drifted** — present but wrong color or description → offer to **update** (this rewrites the label; get an explicit OK per label or for the batch).
- **Matches** — present and correct → leave alone.

Labels **outside** the canonical set (GitHub's defaults like `bug`/`enhancement`, or the repo's own) are **left untouched** — never delete a label unless the user explicitly asks.

### 3. Apply, echoing the commands
On approval:

```sh
# create a missing label
gh label create ready --color 0E8A16 --description "specified and independent — safe to take into its own worktree now"

# update a drifted label (rewrites color/description in place)
gh label edit blocked --color D93F0B --description "has an unmet prerequisite (see 'Blocked by #N' in the body)"
```

`gh label create --force` also upserts (create-or-overwrite) if you'd rather not branch on existence — but prefer the explicit create/edit split so the preview in step 2 stays honest about what's new vs changed. If a flag is rejected, check `gh label create --help`.

### 4. Report
List what was created, updated, and left as-is, and confirm the repo now carries the full lifecycle set — issuekit's label references will now resolve.

---

## Notes

- **Never** delete a repo's topics wholesale or its labels outside the canonical set without an explicit ask; the default is additive/reconciling, not destructive.
- The `labels` map is a **shared contract with issuekit** — the same eight labels, colors, and meanings. Treat issuekit's lifecycle-labels table as the mirror image and keep them in lockstep.
- Defer to what the repo already curates: an existing status-label scheme is handled in [labels step 1](#mode-labels), and a curated About/topics is reconciled per-field (never blind-overwritten) in `about`. Offer the canonical set as an addition, not a replacement.
- Prefer `gh`'s structured JSON (`--json`/`--jq`, the topics API) over scraping human-readable output — the JSON fields are a stable contract, the display text isn't.
