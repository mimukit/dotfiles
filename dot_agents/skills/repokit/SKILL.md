---
name: repokit
description: >-
  Set up a GitHub repo's metadata and configuration through the gh CLI: an inferred one-line About description + topics from the repo's own contents, the workflow labels (issuekit's lifecycle and priority sets, plus an `ai-review` trigger label for AI PR review tools), and a full new-repo setup that also applies the house repo settings (merge-commit-only, delete-branch-on-merge) and scaffolds the baseline files (LICENSE, README, .gitignore, AGENTS.md). Use when the user says "repokit", "set the repo description", "add topics/tags", "write an About blurb for this repo", "provision the workflow labels", "set up this repo's labels", "add priority labels", "configure this repo's metadata", "set up this new repo", or "make this repo match my conventions", meaning anything about a repo's About panel, its label vocabulary, or bringing a fresh repo up to convention.
license: MIT
disable-model-invocation: true
allowed-tools: Bash, Read, Write
metadata:
  internal: false
---

# repokit

Configure a GitHub repository through the [`gh` CLI](https://cli.github.com), in three explicit **modes**:

- **`about`.** Infer a one-line *About* description and a focused set of topics from the repo's own contents (README, manifest, code), show them against whatever is already set, and apply what you approve.
- **`labels`.** Provision the workflow labels: the **lifecycle and priority** sets issuekit uses to track work and rank it, and the **automation** label that asks a repo's AI review tooling to look at a PR. Create what's missing, reconcile what drifted.
- **`setup`.** Bring an already-created repo up to convention in one span: apply the house repo settings (merge-commit-only, delete-branch-on-merge), scaffold the baseline files (LICENSE by an asked question, README, `.gitignore`, `AGENTS.md`), then run `about` and `labels` on top. It configures; `gh repo create` stays with the user.

Three jobs, one skill, because all three answer "make this repo's GitHub configuration right": the outward-facing blurb people read, the label vocabulary the issue workflow runs on, and the settings-and-files baseline a new repo starts from.

## When this fires

The user wants to configure a repo on GitHub. Route to a mode from what they ask:

- **about.** "Set the repo description", "add topics", "write an About blurb", "tag this repo", "update the repo's About".
- **labels.** "Provision the workflow labels", "set up this repo's labels", "add the issuekit labels", "add priority labels", "add an `ai-review` label", "the `blocked` label is missing".
- **setup.** "Set up this new repo", "configure this repo", "make this repo match my conventions", or a vague "set up this repo" / "configure repo metadata" — `setup` is the umbrella, and it subsumes the old "offer `about` then `labels`" answer.

**If no mode is clear, ask first.** Present the three modes and let the user pick before touching anything.

The mode bodies live in one file each under `modes/`. Route with the list above, read that one file, and follow it. Everything in this root applies to every mode and is not restated in the mode files.

- Mode `about` → read [modes/about.md](modes/about.md), then follow it.
- Mode `labels` → read [modes/labels.md](modes/labels.md), then follow it.
- Mode `setup` → read [modes/setup.md](modes/setup.md), then follow it.

## Preflight (every mode)

Before any GitHub call, confirm the tooling and target:

```sh
gh --version                                          # gh installed?
gh auth status                                        # authenticated?
gh repo view --json nameWithOwner -q .nameWithOwner   # which repo? (the current dir's remote)
```

- If `gh` is missing or unauthenticated, say so and point to `https://cli.github.com` / `gh auth login`. Don't work around it.
- If there's no GitHub remote (the `repo view` call fails), stop and say so, because repokit acts on a repo that exists on GitHub. That covers `setup` too: creating the repo is the user's move (`gh repo create`), and repokit begins after it exists.
- **No shell or `gh` at all** (e.g. a browser-based agent)? You can't call `gh`. Do the reasoning from what the user provides and **print the exact `gh` commands** for them to run, whether the description/topics lines, the `gh label create` block, or the `gh repo edit` settings line, as a codeblock to paste. `setup`'s scaffold files degrade the same way: print each file as a fenced block with its path.

**Safety stance, for the whole skill.** A repo's description, topics, labels, and settings are outward-facing state. **Preview every mutation and get an OK before it runs, so nothing changes on GitHub unprompted.** Always echo the exact command(s) you run, so the change is auditable and replayable.

**Re-run safe.** Every mode reconciles against what's already there, so running repokit a second time on an unchanged repo proposes nothing and mutates nothing. It's always safe to re-run.

## Detect (every mode)

Read the repo's current state once before proposing anything. It's the raw material every mode reconciles against, and it surfaces guardrails early. Fetch what the chosen mode needs plus the guardrail flags:

```sh
# guardrail flags + about state
gh repo view --json isArchived,isFork,isTemplate,description,homepageUrl
gh api repos/{owner}/{repo}/topics --jq '.names'    # current topics (about mode)
gh label list --json name,color,description          # current labels (labels mode)
```

`setup` additionally fetches the settings it diffs; its mode file names the exact fields.

Check the guardrail flags **before** any mutation:

- **Archived** (`isArchived: true`). GitHub rejects metadata edits on an archived repo, so **stop** and tell the user to unarchive first.
- **Fork or template** (`isFork` / `isTemplate`). Its metadata is often inherited or throwaway, so **confirm the user means to edit *this* repo** before continuing.

## Notes

- **Never** delete a repo's topics wholesale or its labels outside the canonical sets without an explicit ask; the default is additive and reconciling, not destructive.
- The lifecycle and priority maps are a **shared contract with issuekit**: the same names across both namespaces, with the same colors and meanings, and repokit's descriptions canonical. The automation set is repokit's alone, because issuekit runs the tracker and `ai-review` acts on a pull request.
- **repokit provisions the vocabulary; it never applies it.** No mode here ever puts a label on an issue or a PR. Deciding that #42 is `high` is a judgment about the work, which is issuekit `create` and `triage`'s job; asking for an AI review is a call the author makes on their own PR. repokit only guarantees the word exists to say it with. Keeping that line is what makes the label mode safe to re-run on a repo with a live tracker.
- **repokit never commits.** `setup` writes scaffold files and leaves them unstaged; grouping and committing them is a commit skill's job, or the user's.
- **Labels can't enforce one-per-namespace, so the writer has to.** GitHub will happily let an issue carry `critical` and `low` at once, and nothing here can prevent it. Provisioning is the only half repokit owns; the mutual exclusion is enforced at write time by whoever applies the label, which is why that rule lives in issuekit rather than in this map.
- Defer to what the repo already curates: an existing scheme in any namespace is handled in `labels`' existing-scheme check, a curated About/topics is reconciled per-field (never blind-overwritten) in `about`, and `setup` never overwrites an existing file. Offer the canonical sets as an addition, not a replacement.
- Prefer `gh`'s structured JSON (`--json`/`--jq`, the topics API) over scraping human-readable output, because the JSON fields are a stable contract and the display text isn't.
