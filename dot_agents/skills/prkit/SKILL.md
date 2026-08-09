---
name: prkit
description: >-
  Draft and open a GitHub pull request from your branch — title, summary, and test plan written from the actual commits and diff, then created with the gh CLI, embedding verifykit proof artifacts inline when a bundle is present. Use when the user asks to open a PR, says "create a pull request", "raise a PR", "submit this for review", or "gh pr create" — even if they don't spell out the title or body.
license: MIT
allowed-tools: Bash, Read, Write, Skill
metadata:
  internal: false
---

# prkit

Turn the commits on the current branch into a clean GitHub pull request: a title in the repo's commit style, a body that explains *what changed and why*, and a test plan — all inferred from the real diff, not guessed. Creation goes through the [`gh` CLI](https://cli.github.com), reusing the repo's PR template when one exists.

## When this fires

The user wants to open a pull request: "open a PR", "create a pull request", "raise a PR", "submit this for review", "gh pr create". If they only want the PR title and body *drafted* (not opened), do everything except the final `gh pr create` and print the result instead.

## Procedure

### 1. Preflight
Confirm the tooling and branch are ready before writing anything:

```sh
gh --version        # gh installed?
gh auth status      # authenticated?
git branch --show-current
```

- If `gh` is missing or unauthenticated, say so and point to `https://cli.github.com` / `gh auth login` — don't try to work around it.
- If `git branch --show-current` is empty, stop: detached HEAD needs a branch before a PR can be opened. Offer to create or switch to one.
- If the current branch is the default branch, stop: a PR needs a feature branch. Offer to create one (`git switch -c <name>`) before continuing — and **get the name from gitkit**, which owns branch naming, rather than inventing a shape here. Work that traces to an issue gets `issue-<n>-<slug>`; anything else keeps whatever name the repo's convention or the human supplies.

### 2. Gather context
Get the base branch from **gitkit**, then read what the branch actually changes — that diff is the raw material for the title and body. Fetch first so every ref below is the real remote state, not a stale local copy:

```sh
git fetch origin                                         # refresh remote-tracking refs before anything else
git log origin/<base>..HEAD --format='%s%n%b'            # commits in this PR, with their bodies
git diff origin/<base>...HEAD --stat                     # files touched
```

**Read the full diff (`git diff origin/<base>...HEAD`) only when the commits don't already explain the change.** On a branch built through this workflow they usually do — commitkit wrote each message from the change itself, so the log is a summary of exactly the material a PR body needs, and re-deriving it from the raw diff produces a worse description at many times the cost. Reach for the full diff when the commit messages are thin or generic (a branch of `wip` and `fix typo` commits, or work that came from outside this workflow), when the stat shows files no commit message accounts for, or when you need a specific detail for the test plan. Skip lockfiles, build output, and vendored directories either way.

**gitkit owns base-ref resolution** — ask it for the base rather than re-deriving the ladder here; repos whose default is `develop` or `trunk` are real, and getting this wrong silently produces an empty or enormous diff. Without gitkit, `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` is the authoritative fallback — and ask rather than guess when it can't answer. Re-check the current branch against the base gitkit returns and stop if they match.

Diff against `origin/<base>` (the just-fetched remote tip), not a local `<base>` that may be behind — otherwise the title, body, and file list are computed against commits that are no longer the merge target.

Use the commits, branch name (e.g. `fix/login-123`), and diff to determine the scope, the type of change, and any issue reference (`#123`, `fixes #123`). If a linked issue clearly matters and you can't find it, ask — don't invent one.

### 3. Sync with the base branch
Before pushing, make sure the branch is up to date with the base tip you just fetched — a PR opened from a stale branch either merges outdated code or lands with GitHub's "This branch has conflicts" banner:

```sh
git rev-list --left-right --count origin/<base>...HEAD   # "<behind>\t<ahead>"; left > 0 means behind
```

- **Behind by zero**: nothing to do — go to [Push the branch](#4-push-the-branch).
- **Behind**: the branch needs `origin/<base>` brought in. **gitkit owns the sync rule**, and it resolves to **rebase** (`git rebase origin/<base>`), giving the PR a clean diff. Whether that needs an OK first turns on one thing gitkit states in full: an **unpublished** branch rebases straight through, because nothing outside this machine points at the commits being rewritten; a branch already pushed previews the rebase and its `--force-with-lease` together and waits. At PR-open time the branch is usually the former, which is why this step normally runs without a prompt.
- **Rebase conflicts**: if the rebase stops on a conflict, **stop and surface it** — list the conflicted files (`git diff --name-only --diff-filter=U`) and resolve them (or hand them back to the user), then complete the rebase (`git rebase --continue`). Do not push, and do not open the PR, until the working tree is clean and the sync is finished. If the user declines the sync, say the PR may show conflicts and proceed only if they confirm.

**Don't re-read the diff after a clean rebase.** A rebase replays your commits onto a new base; it doesn't change what they say or do, so the title and body you derived above still describe the branch correctly. The one exception is a rebase you resolved **conflicts** in — there you made real edits during the replay, and the resolved result is genuinely different from what you read. Re-read just the files you touched resolving them (`git diff origin/<base>...HEAD -- <paths>`), not the whole branch.

### 4. Push the branch

**First, commit any handed-in path.** When a caller hands prkit a file that must travel with the branch — most often a QA plan at `docs/qa/qa-<slug>-YYYY-MM-DD.md` — and that file is still uncommitted, commit it here rather than leaving it behind or spawning something else to do it. prkit is already the step that touches git, and it was given the path, so there is nothing to rediscover:

```sh
git add <handed-in path> && git commit -m "docs(qa): add manual QA plan for <feature>"
```

Only a path the caller **named**. This is not a licence to sweep the working tree — uncommitted work nobody mentioned is still covered by the rule in [Notes](#notes): point it out and offer, don't commit it silently.

The remote branch must exist before a PR can point at it:

```sh
git push -u origin HEAD
```

If the branch was rebased ([Sync with the base branch](#3-sync-with-the-base-branch)) and the remote rejects a normal push, use `git push --force-with-lease` (never bare `--force`). Don't ask again here: a rejected push means the branch was already published, and gitkit's rule covers the rebase and its lease push under a **single** confirmation taken during the sync. If that OK wasn't given — because the branch looked unpublished and the rejection is the first sign it wasn't — stop and ask then.

### 5. Write the title and body
- **Title**: one line, imperative, in the repo's commit style (match `git log` — often Conventional Commits like `feat(auth): add SSO login`). No trailing period.
- **Body**: if `.github/pull_request_template.md` (or `PULL_REQUEST_TEMPLATE.md`) exists, read it and fill it in *exactly* — match its sections and checkboxes. Otherwise use: a one-paragraph **Summary** of what changed and why, a **Changes** bullet list, and a **Test plan** (how it was verified, or checkboxes for what to run). Reference the issue in the body (`Closes #123`) when there is one.

### 6. Embed proof artifacts (if present)
Optional — only when a verifykit proof bundle exists. verifykit leaves a dated bundle at `docs/verify/verify-<slug>-YYYY-MM-DD/` (slug = the linked issue number, else the feature slug) with a ready-to-embed `proof.md`. If more than one matches, use the newest creation date; if multiple bundles share that date, ask which run to use. Splice the selected proof into the body under a **Proof** section — the images are already published to a hidden `refs/verify-assets/*` ref with SHA-pinned raw URLs that render inline, so there's no upload work here; just embed the fragment as-is. If no bundle exists, skip this entirely and open the PR exactly as before. If a bundle exists but its `proof.md` points at local paths (verifykit couldn't publish — e.g. a private repo), don't embed dead links: add a short note listing the local artifact paths for manual attachment instead.

### 7. Create or update the PR
First check for an existing PR on this branch so you update instead of duplicating:

```sh
gh pr view --json url,state 2>/dev/null
```

- **If the command returns a PR with `state` equal to `OPEN`**: update it — `gh pr edit --title "…" --body-file <file>` — rather than opening a second.
- **If no PR exists, or the returned PR is merged/closed**: write the body to a temp file and create a new one. Passing multi-line markdown with checkboxes through `--body` is flaky; `--body-file` is reliable.

```sh
gh pr create --base <base> --title "…" --body-file <bodyfile>
# add --draft when the user wants a draft, or the work is incomplete
```

Use a path in the system temp dir for the body file and remove it afterward.

### 8. Advance the linked issue
Opening the PR is the moment the linked issue moves from being worked to awaiting review, so flip its lifecycle label `in-progress` → `in-review` (the same transition issuekit's `sync` mode performs when a PR opens). Only when the PR references an issue — the `#123` / `Closes #123` found in [Gather context](#2-gather-context); skip this step entirely if there is none.

- **Prefer issuekit when it's installed** — invoke it to reconcile the label so the tracker logic lives in one place. Otherwise fall back to the equivalent `gh` call yourself:

```sh
gh issue edit <n> --remove-label in-progress --add-label in-review
```

- **Preview the mutation and get an OK before it runs** — relabeling an issue is an outward-facing change, so name the issue and the flip and wait for confirmation; never relabel silently.
- If the issue doesn't currently carry `in-progress` (e.g. it was `ready` or already `in-review`), just add `in-review` and say what you found rather than forcing the removal. If the `in-review` label is missing from the repo, point the user at repokit or give `gh label create in-review --color 5319E7 --description "a PR is open, awaiting review or merge"` — don't mutate around the gap.

### 9. Hand off
**What changed** — the PR created or updated (title and number), whether a sync rebase ran, whether a handed-in path was committed, whether a proof section was embedded, and whether the linked issue was flipped to `in-review`.

**Where it landed** — the PR URL and the branch it points at. Mention that CI will run if configured.

**Next** — the PR now waits on review, so the move is on the reviewer's side: **mergekit** `start <n>` when it's installed pulls it down into a worktree for local review and QA; otherwise review it on GitHub. First offer, don't auto-run, the small follow-ups when they apply: `gh pr edit --add-reviewer <user>`, `--add-label <label>`, or `gh pr ready` for a draft. prkit's job ends here.

## Notes

- **Never** merge, close, or force-push without an explicit ask. Creating or editing a PR is fine; `gh pr merge` is not, unless requested.
- Uncommitted changes are not in a PR. If `git status` shows staged or unstaged work the user seems to want included, point it out and offer to commit first — don't silently leave it behind or commit it without asking.
- If the branch is not ahead of the base (no commits), stop and say there's nothing to open a PR for.
- **Proof embedding is optional and self-contained** — prkit only *reads* verifykit's `proof.md` and embeds it; it never runs the publish itself (that's verifykit's job, with its own bundled script). No verifykit bundle → no Proof section, and prkit works exactly as it always has.
- **Advancing the linked issue is optional and previewed** — the `in-progress → in-review` flip only happens when the PR references an issue, prefers issuekit when installed but falls back to a plain `gh issue edit`, and never runs without an OK. No linked issue → prkit opens the PR exactly as before.
- No shell or `gh` available (e.g. a browser-based agent)? Then you can't push or call `gh`. Instead read the diff the user provides and print the finished PR **title** and **body** as codeblocks for them to paste into the GitHub "New pull request" form.
