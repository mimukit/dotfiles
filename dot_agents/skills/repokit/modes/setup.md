# Mode: `setup`

Bring an already-created GitHub repo up to convention in one span: the repo settings, the baseline files, then the `about` and `labels` modes on top. **`setup` runs on defaults and asks nothing.** Every decision below has a default, and the run applies it and reports it in the hand-off; the user changes a value afterwards with `gh repo edit` or by editing the file. The only stops are the root's guardrails: an archived repo, or a fork or template the user does not confirm. `setup` **configures, never creates** — the root's preflight already stopped if there is no GitHub remote, and `gh repo create` stays with the user. It also never commits: every file it writes is left unstaged for a commit skill to group. The root's [Preflight](../SKILL.md#preflight-every-mode) and [Detect](../SKILL.md#detect-every-mode) have already run; this file assumes their state.

## 1. Report the repo's shape
Read the state Detect fetched, plus the commit count (`git rev-list --count HEAD`, which fails harmlessly on an empty repo) and the top-level file list. State what you found in one line: empty repo, fresh repo with a first commit, or a repo with real history. Every shape runs the identical flow below; history only shrinks the diffs, because the scaffold step writes only missing files and everything else reconciles. This step is done when the shape is stated.

## 2. Settings
Fetch the current settings and diff them against the canonical map, which is the user's default for every repo:

```sh
gh repo view --json visibility,squashMergeAllowed,mergeCommitAllowed,rebaseMergeAllowed,deleteBranchOnMerge,autoMergeAllowed,hasIssuesEnabled,hasWikiEnabled,hasProjectsEnabled,defaultBranchRef
gh api repos/{owner}/{repo} --jq '{allow_update_branch, security_and_analysis}'
```

`gh repo view` carries no field for the update-branch button or for secret scanning, so the API call above supplies both current values.

| Setting | Value | Why |
|---------|-------|-----|
| `--enable-merge-commit` | true | mergekit closes a PR with `gh pr merge --merge`. |
| `--enable-squash-merge` | false | A squash breaks branch ancestry, the case gitkit's `clean` needs three detections to catch. |
| `--enable-rebase-merge` | false | One merge method means one shape of history. |
| `--delete-branch-on-merge` | true | The remote branch dies with the PR, so a branch sweep only handles local leftovers. |
| `--enable-wiki` | false | wikikit `publish` is opt-in, and enabling later is one click. |
| `--enable-projects` | false | Nothing in this collection reads a project board. |
| `--enable-issues` | true | The issue tracker is the workflow's substrate. |
| `--allow-update-branch` | false | The button merges the base into the PR branch by default, and gitkit syncs a branch by rebase. No skill here uses it. |
| `--enable-auto-merge` | false | A person reviews the code before every merge. mergekit merges on your word and afkkit stops at an open PR. |
| `--enable-secret-scanning` | true | GitHub reports a credential committed to the repo. |
| `--enable-secret-scanning-push-protection` | true | GitHub blocks the push that carries a credential, so nothing to revoke. |

Apply every differing row without a question. A matching row needs no flag. Keep the current and new value of each changed row for the hand-off.

The default branch is report-only: state it when it isn't `main` and change nothing, because renaming a default branch breaks open PRs and clones.

**Both secret-scanning rows are free on a public repo and need GitHub Advanced Security on a private one.** Apply them on either visibility; on a private repo the plan may reject them, and the cost of a rejected flag is one error message.

Apply the differing rows in one echoed command built from their flags. The full form, when every row differs:

```sh
gh repo edit --enable-merge-commit --enable-squash-merge=false --enable-rebase-merge=false --delete-branch-on-merge --enable-issues --enable-wiki=false --enable-projects=false --allow-update-branch=false --enable-auto-merge=false --enable-secret-scanning --enable-secret-scanning-push-protection
```

When the command fails, re-run it without the rejected flag rather than dropping the whole batch, and report which row GitHub refused. This step is done when every row in the map is applied, already matching, or refused by GitHub with that refusal reported.

## 3. Scaffold
List which baseline files exist and which are missing. Write every missing one without a preview; the files stay unstaged, so `git diff` is the review. An existing file is never overwritten. The one patch `setup` makes to an existing file is the naming section in `AGENTS.md`, described below.

| File | Content | Skipped when |
|------|---------|--------------|
| `LICENSE` | The default license for the repo's visibility, below. | Present. |
| `README.md` | Title, the one-line About text, an install or run section matched to the stack. | Present. |
| `.gitignore` | Matched to the detected stack; no file when the stack is unknown. | Present, or stack undetected. |
| `AGENTS.md` | A repo-conventions skeleton: what the project is, how to build and test it, what an agent must not do, and the [docs artifact naming](#docs-artifact-naming) section. | Present; then append only the naming section, when it is missing. |
| `.claude/CLAUDE.md` | One line pointing at `AGENTS.md` (`@../AGENTS.md` under a header), so both agent families read one source. | Present. |

**The license follows the repo's visibility (fetched in the settings step), with no question.**

- **Public repo → MIT.** Fetch the text from `gh api /licenses/mit --jq .body` rather than writing it from memory, then substitute the year and holder name.
- **Private repo → a proprietary all-rights-reserved file.** A private repo holds proprietary code, and the file says so where a reader will find it. Write this text with the holder and the year:

  ```text
  Copyright (c) <year> <holder>. All rights reserved.

  This software and its source code are proprietary. No license is granted to
  use, copy, modify, merge, publish, distribute, sublicense, or sell copies of
  this software, in whole or in part, without prior written permission from
  the copyright holder.
  ```

A private repo that goes public later needs a new `LICENSE`; name that in the hand-off for a private repo.

### Docs artifact naming

Every `AGENTS.md` this mode writes carries the section below. When `AGENTS.md` is already present, check it for an artifact-naming rule. When none exists, append the section. A repo scaffolded by another tool, such as a project generator, arrives with an `AGENTS.md` but no naming rule, and that is the case this row exists for.

```markdown
## Docs artifact naming

- An artifact under `docs/<type>/` (a plan, a QA plan, a review, research) is named `NNNN-<type>-<slug>-YYYY-MM-DD.md`.
- `NNNN` is a four-digit serial, per directory, assigned in creation order and never reused. To get it, take the highest serial in that directory across this worktree, every other worktree that `git worktree list` names, and `origin/HEAD` (`git ls-tree --name-only origin/HEAD <dir>` after `git fetch origin`), and add one. Scan all three, because parallel worktrees otherwise take the same serial. Skip a source that fails, such as no remote, and without git list the directory only. An empty directory starts at `0001`.
- `YYYY-MM-DD` is the creation date. The whole name stays fixed after edits.
- An ADR uses its decision number as the serial: `docs/adr/NNNN-adr-<slug>-YYYY-MM-DD.md`.
- Reader-facing pages (`docs/wiki/`, how-to guides, runbooks) stay unnumbered.
```

The holder name comes from `gh api user --jq .name`, falling back to `git config user.name` when that is empty, This step is done when every row is written or skipped for its stated reason.

## 4. Run `about`
Read [about.md](about.md) and run it against the now-scaffolded repo, so the README it reads is the one this run just wrote. Run it on defaults: skip the per-field question and apply the defaults that file states for a `setup` run. Skip its hand-off; this file's [Hand off](#6-hand-off) closes for the whole span.

## 5. Run `labels`
Read [labels.md](labels.md) and run it on defaults: skip every approval question and apply the defaults that file states for a `setup` run. Skip its hand-off for the same reason.

## 6. Hand off
**What changed.** Report four things in order: each setting changed as `current → new`, the files written and the ones skipped with their reasons, the About fields applied and the fields kept, and the label sets provisioned or skipped. Name the license written. Give the `gh repo edit` flag that reverts any setting the user may want back.

**Where it landed.** Give the repo URL, the file paths written, and say the files are unstaged.

**Next.** Crown one move. The scaffold files are uncommitted, so the move is to commit them, with **commitkit** when installed and `git add` + `git commit` otherwise. After the commit, **issuekit** `create` starts filing work against the vocabulary this run provisioned. When `ai-review` was created and nothing listens for it, name that gap in one line, per the `labels` hand-off rule.
