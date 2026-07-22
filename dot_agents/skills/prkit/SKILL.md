---
name: prkit
description: >-
  Draft and open a GitHub pull request from your branch — title, summary, and test plan written from the actual commits and diff, then created with the gh CLI, embedding verifykit proof artifacts inline when a bundle is present. Use when the user asks to open a PR, says "create a pull request", "raise a PR", "submit this for review", or "gh pr create" — even if they don't spell out the title or body.
license: MIT
allowed-tools: Bash, Read
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
- If the current branch is the default branch (`main`/`master`), stop: a PR needs a feature branch. Offer to create one (`git switch -c <name>`) before continuing.

### 2. Gather context
Find the base branch and read what the branch actually changes — this is the raw material for the title and body. Fetch first so every ref below is the real remote state, not a stale local copy:

```sh
git fetch origin                                                   # refresh remote-tracking refs before anything else
gh repo view --json defaultBranchRef --jq .defaultBranchRef.name   # the base branch (structured field, not scraped output)
git log origin/<base>..HEAD --oneline --no-decorate      # commits in this PR
git diff origin/<base>...HEAD --stat                     # files touched
git diff origin/<base>...HEAD                            # the actual changes
```

Read the base branch from `gh`'s structured JSON rather than parsing the display text of `git remote show origin` — the JSON field is a stable contract, the human-readable output isn't. If `gh` can't answer, fall back to `git symbolic-ref --short refs/remotes/origin/HEAD`. Diff against `origin/<base>` (the just-fetched remote tip), not a local `<base>` that may be behind — otherwise the title, body, and file list are computed against commits that are no longer the merge target.

Use the commits, branch name (e.g. `fix/login-123`), and diff to determine the scope, the type of change, and any issue reference (`#123`, `fixes #123`). If a linked issue clearly matters and you can't find it, ask — don't invent one.

### 3. Sync with the base branch
Before pushing, make sure the branch is up to date with the base tip you just fetched — a PR opened from a stale branch either merges outdated code or lands with GitHub's "This branch has conflicts" banner:

```sh
git rev-list --left-right --count origin/<base>...HEAD   # "<behind>\t<ahead>"; left > 0 means behind
```

- **Behind by zero**: nothing to do — go to step 4.
- **Behind**: the branch needs `origin/<base>` merged (or rebased) in. This rewrites/advances the branch, so **offer it and confirm before running** — never sync silently (mirrors the "never force-push without an ask" rule). Default to a merge (`git merge origin/<base>`) unless the repo's history is visibly linear/rebase-style or the user prefers rebasing (`git rebase origin/<base>`).
- **Merge conflicts**: if the merge/rebase stops on a conflict, **stop and surface it** — list the conflicted files (`git diff --name-only --diff-filter=U`) and resolve them (or hand them back to the user), then complete the merge/rebase. Do not push, and do not open the PR, until the working tree is clean and the sync is finished. If the user declines the sync, say the PR may show conflicts and proceed only if they confirm.

After a successful sync, re-read the diff (`git diff origin/<base>...HEAD`) so the title and body reflect the merged result.

### 4. Push the branch
The remote branch must exist before a PR can point at it:

```sh
git push -u origin HEAD
```

If the branch was rebased (step 3) and the remote rejects a normal push, use `git push --force-with-lease` (never bare `--force`), and only after confirming the rewrite was intended.

### 5. Write the title and body
- **Title**: one line, imperative, in the repo's commit style (match `git log` — often Conventional Commits like `feat(auth): add SSO login`). No trailing period.
- **Body**: if `.github/pull_request_template.md` (or `PULL_REQUEST_TEMPLATE.md`) exists, read it and fill it in *exactly* — match its sections and checkboxes. Otherwise use: a one-paragraph **Summary** of what changed and why, a **Changes** bullet list, and a **Test plan** (how it was verified, or checkboxes for what to run). Reference the issue in the body (`Closes #123`) when there is one.

### 6. Embed proof artifacts (if present)
Optional — only when a verifykit proof bundle exists. verifykit leaves a bundle at `docs/verify/<slug>/` (slug = the linked issue number, else the feature-slug) with a ready-to-embed `proof.md`. If one matching this branch or issue is present, splice its contents into the body under a **Proof** section — the images are already published to a hidden `refs/verify-assets/*` ref with SHA-pinned raw URLs that render inline, so there's no upload work here; just embed the fragment as-is. If no bundle exists, skip this entirely and open the PR exactly as before. If a bundle exists but its `proof.md` points at local paths (verifykit couldn't publish — e.g. a private repo), don't embed dead links: add a short note listing the local artifact paths for manual attachment instead.

### 7. Create or update the PR
First check for an existing PR on this branch so you update instead of duplicating:

```sh
gh pr view --json url,state 2>/dev/null
```

- **If one exists**: update it — `gh pr edit --title "…" --body-file <file>` — rather than opening a second.
- **If not**: write the body to a temp file and create from it. Passing multi-line markdown with checkboxes through `--body` is flaky; `--body-file` is reliable.

```sh
gh pr create --base <base> --title "…" --body-file <bodyfile>
# add --draft when the user wants a draft, or the work is incomplete
```

Use a path in the system temp dir for the body file and remove it afterward.

### 8. After creating
Print the PR URL. Mention that CI will run if configured. Offer, don't auto-run, the common follow-ups: `gh pr edit --add-reviewer <user>`, `--add-label <label>`, or marking ready with `gh pr ready` if it was a draft.

## Notes

- **Never** merge, close, or force-push without an explicit ask. Creating or editing a PR is fine; `gh pr merge` is not, unless requested.
- Uncommitted changes are not in a PR. If `git status` shows staged or unstaged work the user seems to want included, point it out and offer to commit first — don't silently leave it behind or commit it without asking.
- If the branch is not ahead of the base (no commits), stop and say there's nothing to open a PR for.
- **Proof embedding is optional and self-contained** — prkit only *reads* verifykit's `proof.md` and embeds it; it never runs the publish itself (that's verifykit's job, with its own bundled script). No verifykit bundle → no Proof section, and prkit works exactly as it always has.
- No shell or `gh` available (e.g. a browser-based agent)? Then you can't push or call `gh`. Instead read the diff the user provides and print the finished PR **title** and **body** as codeblocks for them to paste into the GitHub "New pull request" form.
