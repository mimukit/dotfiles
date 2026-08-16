---
name: repokit
description: >-
  Set up a GitHub repo's metadata through the gh CLI — an inferred one-line About description + topics from the repo's own contents, and the issuekit lifecycle and priority labels. Use when the user says "repokit", "set the repo description", "add topics/tags", "write an About blurb for this repo", "provision the workflow labels", "set up this repo's labels", "add priority labels", or "configure this repo's metadata" — anything about a repo's About panel or its label vocabulary.
license: MIT
allowed-tools: Bash, Read
metadata:
  internal: false
---

# repokit

Configure a GitHub repository's metadata through the [`gh` CLI](https://cli.github.com), in two explicit **modes**:

- **`about`** — infer a one-line *About* description and a focused set of topics from the repo's own contents (README, manifest, code), show them against whatever is already set, and apply what you approve.
- **`labels`** — provision the issue-workflow **lifecycle and priority labels** (the sets issuekit uses to track work and rank it), creating what's missing and reconciling what drifted.

Two jobs, one skill, because both answer "make this repo's GitHub metadata right" — the outward-facing blurb people read, and the label vocabulary the issue workflow runs on.

## When this fires

The user wants to set a repo's GitHub metadata. Route to a mode from what they ask:

- **about** — "set the repo description", "add topics", "write an About blurb", "tag this repo", "update the repo's About".
- **labels** — "provision the workflow labels", "set up this repo's labels", "add the issuekit labels", "add priority labels", "the `blocked` label is missing".
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

To *replace the whole topic set* in one call instead of add/remove reconciliation, the topics API is cleaner: `gh api --method PUT repos/{owner}/{repo}/topics -f 'names[]=a' -f 'names[]=b'`. Either is fine — pick whichever expresses the change more simply.

### 6. Hand off

_Write every hand-off in this skill in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

**What changed** — the description and topics as they now stand, and anything the user chose to keep current rather than replace. A field you proposed and they rejected is worth one line; it's the part most likely to come up again.

**Where it landed** — the repo's About panel, with its URL, so they can eyeball the result.

**Next** — name one move and stop. If `labels` hasn't run in this repo, that's it: the lifecycle and priority labels are what an issue workflow needs and the About panel isn't. If both modes are done, repokit is finished with this repo — point at what the metadata unblocks (**issuekit** to start filing work, when installed) rather than manufacturing more configuration.

---

## Mode: `labels`

Provision the issue-workflow **lifecycle and priority labels** so issuekit (and any workflow that reads them) has the vocabulary it expects. repokit *creates and reconciles* these labels; issuekit only *uses* them, and repokit never applies one to an issue. This mode **stands alone** — both sets are useful for any issue workflow, so it never checks whether issuekit is installed before provisioning them.

### Two sets, two independent namespaces

The map below is really two, and keeping them apart is what makes both usable:

- **Lifecycle** answers *can this be worked?* — where the issue sits in the workflow.
- **Priority** answers *should this be worked next?* — how much it matters relative to everything else workable.

They are **orthogonal**: an issue carries at most one label from each, and neither implies the other. `ready` + `low` is a perfectly coherent issue (workable, not urgent), and so is `blocked` + `critical` (urgent, and that's exactly why its blocker matters). Downstream skills read them as two separate signals, so never collapse them into one ordered set.

### The canonical lifecycle set
Provision exactly this map. The `description` column here is canonical; issuekit mirrors the same names, colors, and meanings in execution-oriented wording.

| name | color | description |
|------|-------|-------------|
| `triage` | `FBCA04` | filed, not yet assessed or broken down |
| `needs-planning` | `F1C40F` | needs a human plan/grill session before it is workable |
| `ready` | `0E8A16` | specified and independent — safe to take into its own worktree now |
| `blocked` | `D93F0B` | has an unmet prerequisite (see 'Blocked by #N' in the body) |
| `in-progress` | `1D76DB` | actively being worked in a worktree |
| `in-review` | `5319E7` | a PR is open, awaiting review or merge |
| `needs-info` | `D4C5F9` | stalled pending more detail before it can proceed |
| `wontfix` | `FFFFFF` | will not be actioned |
| `duplicate` | `CFD3D7` | superseded by another issue |

### The canonical priority set
Four levels, and the colors run a deliberate hot-to-cold ramp so the family reads as one scale at a glance rather than as four unrelated labels:

| name | color | description |
|------|-------|-------------|
| `critical` | `B60205` | drop everything — preempts work already in progress |
| `high` | `E99695` | do this before other workable issues |
| `medium` | `FEF2C0` | normal priority — the default once assessed |
| `low` | `C5DEF5` | worth doing eventually — never preempts anything |

Colors are 6-hex, no leading `#`.

**No priority label means *unassessed*, not *medium*.** The absence is a real state and downstream skills read it as one — it's how `triage` finds issues nobody has ranked yet. Never provision a default, and never treat a missing label as an implied middle.

**Four levels is the ceiling, and it's already generous.** The point of a priority scale is a backlog someone can order in their head; every level past the fourth is one more place for the same issue to plausibly sit, which is how a scale turns into a coin flip. If the user asks for a fifth, say what it costs before adding it.

### 1. Check for an existing scheme first — both namespaces
You read the repo's labels in [Detect](#detect-every-mode). Before diffing, look for a **different-but-equivalent scheme** the repo already runs, in either namespace:

- **Lifecycle** — `status: blocked`, `S-ready`, `blocked ⛔`, or a `needs-*` family that already covers this ground.
- **Priority** — `P0`/`P1`/`P2`, `priority: high`, `pri-1`, `urgent`, or a `severity:` family being used as a de facto priority.

If one exists, **don't silently add a parallel set** (two ways to say "blocked" is worse than none, and two ways to say "urgent" is worse still, because the two will disagree). Surface it and ask which way to go:

- **Map onto theirs** — treat the repo's labels as canonical; skip provisioning and (optionally) note the name mapping so issuekit-style workflows can be pointed at the existing names.
- **Add the canonical set** — the repo's scheme is incidental or abandoned; provision ours alongside it, and offer to retire the old labels only if the user explicitly asks.

Handle the namespaces **independently** — a repo very often has a mature lifecycle scheme and no priority scheme at all, and the answer there is "map onto theirs for lifecycle, provision ours for priority." Asking one question about both forces a wrong answer to half of it.

**Priority names collide harder than lifecycle names, so check meaning and not just spelling.** `ready` and `in-review` are workflow-shaped words that mostly mean this one thing; `critical`, `high`, and `low` are generic English and a repo may already be using them for something else entirely — bug **severity** (how badly it breaks), effort or T-shirt **size**, risk, or a customer tier. A name match is not a meaning match. When the repo already has a `critical` or `high`, read its description and a couple of the issues carrying it before assuming it's the same axis, and if it turns out to be severity, say so plainly: severity and priority are genuinely different things (a critical crash nobody hits can be `low`), so the honest fix is to name the collision and let the user decide whether to rename theirs, rename ours, or map onto it.

Absent any existing scheme in a namespace, go straight to the diff for that one.

### 2. Diff against the canonical sets and preview
Sort each canonical label — from **both** sets — into one of three buckets and show the plan before touching anything, grouped by namespace so the user can approve one and decline the other:

- **Missing** — not in the repo → will be **created**.
- **Drifted** — present but wrong color or description → offer to **update** (this rewrites the label; get an explicit OK per label or for the batch).
- **Matches** — present and correct → leave alone.

Labels **outside** the canonical sets (GitHub's defaults like `bug`/`enhancement`, or the repo's own) are **left untouched** — never delete a label unless the user explicitly asks.

### 3. Apply, echoing the commands
On approval:

```sh
# create a missing label
gh label create ready --color 0E8A16 --description "specified and independent — safe to take into its own worktree now"
gh label create critical --color B60205 --description "drop everything — preempts work already in progress"

# update a drifted label (rewrites color/description in place)
gh label edit blocked --color D93F0B --description "has an unmet prerequisite (see 'Blocked by #N' in the body)"
```

`gh label create --force` also upserts (create-or-overwrite) if you'd rather not branch on existence — but prefer the explicit create/edit split so the preview in [Diff against the canonical sets and preview](#2-diff-against-the-canonical-sets-and-preview) stays honest about what's new vs changed.

### 4. Hand off
**What changed** — what was created, updated, and left as-is, per namespace, and confirm which of the two sets the repo now carries in full. Provisioning one and skipping the other is a normal outcome, not a partial failure — say which, so nobody goes looking for the missing half later.

**Where it landed** — the repo's label list. If you mapped onto an existing scheme instead of provisioning ours in either namespace, say which names won, because everything downstream now has to use those.

**Next** — name one move and stop. The labels are a vocabulary, not an outcome: what they unblock is the issue workflow, so the move is to start using it — **issuekit** `create` to file work from a plan, or `triage` to classify and rank issues that were sitting unlabeled while the vocabulary was missing. When the repo already had open issues and priority is the set you just provisioned, `triage` is the stronger of the two: every one of those issues is now formally unassessed, and nothing downstream can rank them until somebody says what matters. Absent issuekit, say the labels are now available to whatever issue workflow the repo runs. If `about` hasn't run yet and the repo's About panel is empty, offer that as the smaller follow-up.

---

## Notes

- **Never** delete a repo's topics wholesale or its labels outside the canonical sets without an explicit ask; the default is additive/reconciling, not destructive.
- The `labels` maps are a **shared contract with issuekit** — the same thirteen names across two namespaces, with the same colors and meanings, and repokit's descriptions canonical.
- **repokit provisions the vocabulary; it never applies it.** No mode here ever puts a label on an issue — not a lifecycle one, not a priority one. Deciding that #42 is `high` is a judgment about the work, which is issuekit `create` and `triage`'s job; repokit only guarantees the word exists to say it with. Keeping that line is what makes this mode safe to re-run on a repo with a live tracker.
- **Labels can't enforce one-per-namespace, so the writer has to.** GitHub will happily let an issue carry `critical` and `low` at once — nothing here can prevent it. Provisioning is the only half repokit owns; the mutual exclusion is enforced at write time by whoever applies the label, which is why that rule lives in issuekit rather than in this map.
- Defer to what the repo already curates: an existing scheme in either namespace is handled in [Check for an existing scheme first — both namespaces](#1-check-for-an-existing-scheme-first--both-namespaces), and a curated About/topics is reconciled per-field (never blind-overwritten) in `about`. Offer the canonical sets as an addition, not a replacement.
- Prefer `gh`'s structured JSON (`--json`/`--jq`, the topics API) over scraping human-readable output — the JSON fields are a stable contract, the display text isn't.
