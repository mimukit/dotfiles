# Mode: `setup`

Bring an already-created GitHub repo up to convention in one span: the repo settings, the baseline files, then the `about` and `labels` modes on top. `setup` **configures, never creates** — the root's preflight already stopped if there is no GitHub remote, and `gh repo create` stays with the user. It also never commits: every file it writes is left unstaged for a commit skill to group. The root's [Preflight](../SKILL.md#preflight-every-mode) and [Detect](../SKILL.md#detect-every-mode) have already run; this file assumes their state.

## 1. Report the repo's shape
Read the state Detect fetched, plus the commit count (`git rev-list --count HEAD`, which fails harmlessly on an empty repo) and the top-level file list. Say what you found before proposing anything: empty repo, fresh repo with a first commit, or a repo with real history. Every shape runs the identical flow below; history only shrinks the diffs, because the scaffold step proposes missing files and everything else reconciles. This step is done when you have stated the shape and the user has not objected to continuing.

## 2. Settings diff
Fetch the current settings and diff them against the canonical map:

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
| `--enable-wiki` | false | Proposed off; wikikit `publish` is opt-in and enabling later is one click. Flippable in this preview. |
| `--enable-projects` | false | Nothing in this collection reads a project board. |
| `--enable-issues` | true | The issue tracker is the workflow's substrate. |
| `--allow-update-branch` | true | Puts the "Update branch" button on a PR behind its base, the sync mergekit runs. |
| `--enable-auto-merge` | true | Lets `gh pr merge --auto` land a PR once checks pass, which is how afkkit finishes unattended. |
| `--enable-secret-scanning` | true | GitHub reports a credential committed to the repo. |
| `--enable-secret-scanning-push-protection` | true | GitHub blocks the push that carries a credential, so nothing to revoke. |

Show current vs proposed for every row in the map, the same side-by-side shape `about` uses. Mark each row as matching or differing; never drop a matching row, because the user may want to flip a setting the map already agrees with.

**Ask the settings as their own question, separate from every other decision in this mode.** Do not fold them into the scaffold or the license question, and do not ask for one blanket approval of the whole map. Put one option per row, in the map's order, worded as `current → proposed` (or `current, matches` for a row already at the proposed value) with the Why column as the option's explanation, and let the user select per row whether to enable or disable that setting. A selected matching row flips to its opposite value; an unselected row stays untouched. The wiki row is the one most often flipped, so never bundle it with another row. When the user selects nothing, change no setting and continue.

The default branch is report-only: state it when it isn't `main` and change nothing, because renaming a default branch breaks open PRs and clones.

**Both secret-scanning rows are free on a public repo and need GitHub Advanced Security on a private one.** Propose them on a public repo. On a private repo, say in one line that the plan may reject them, and offer them anyway — the cost of a rejected flag is one error message.

Apply only the selected rows, in one echoed command built from those flags:

```sh
gh repo edit --enable-merge-commit --enable-squash-merge=false --enable-rebase-merge=false --delete-branch-on-merge --enable-issues --enable-wiki=false --enable-projects=false --allow-update-branch --enable-auto-merge --enable-secret-scanning --enable-secret-scanning-push-protection
```

When the command fails, re-run it without the rejected flag rather than dropping the whole batch, and report which row GitHub refused. This step is done when every row in the map is either applied, deliberately left unselected by the user, refused by GitHub with that refusal reported, or already matching.

## 3. Scaffold diff
List which baseline files exist and which are missing. Propose only the missing ones; an existing file is never overwritten, and patching one happens only when the user asks. Preview every file's content before writing it.

| File | Content | Skipped when |
|------|---------|--------------|
| `LICENSE` | The license the user picks in the license question below. | Present, or the user declines a license. |
| `README.md` | Title, the one-line About text, an install or run section matched to the stack. | Present. |
| `.gitignore` | Matched to the detected stack; no file when the stack is unknown. | Present, or stack undetected. |
| `AGENTS.md` | A repo-conventions skeleton: what the project is, how to build and test it, what an agent must not do. | Present. |
| `.claude/CLAUDE.md` | One line pointing at `AGENTS.md` (`@../AGENTS.md` under a header), so both agent families read one source. | Present. |

**The license is a question, never an assumption, and a private repo gets the question too.** Ask which license the project takes before writing `LICENSE`. The recommendation follows the repo's visibility (fetched in the settings diff), and the option list changes with it:

- **Public repo → recommend MIT.** Offer MIT, Apache-2.0, and GPL-3.0, and accept any SPDX identifier the user names instead. Fetch the text from `gh api /licenses/<key> --jq .body` rather than writing a license from memory, then substitute the year and holder name.
- **Private repo → recommend a proprietary all-rights-reserved file.** A private repo holds proprietary code, and the point of the file is to say so where a reader will find it. Write a short `LICENSE` naming the holder, the year, and the reservation of all rights, with no grant to use, copy, modify, or distribute:

  ```text
  Copyright (c) <year> <holder>. All rights reserved.

  This software and its source code are proprietary. No license is granted to
  use, copy, modify, merge, publish, distribute, sublicense, or sell copies of
  this software, in whole or in part, without prior written permission from
  the copyright holder.
  ```

- **Offer an open license to a private repo as the runner-up**, because a private repo often goes public later and picking the license now is cheaper than relicensing after contributors arrive.
- **"No license" stays available in both.** Say what it means when picked: default copyright already reserves all rights, so the code is not open, but nobody reading the repo can tell that from the repo.
- Recommend, and let the user decide; say in one line that this is not legal advice.

The holder name comes from `gh api user --jq .name`, falling back to `git config user.name` when that is empty, and it is always visible in the file preview before the write. This step is done when every row is written, skipped for its stated reason, or declined by the user.

## 4. Run `about`
Read [about.md](about.md) and run it in full against the now-scaffolded repo, so the README it reads is the one this run just wrote. Skip its hand-off; this file's [Hand off](#6-hand-off) closes for the whole span.

## 5. Run `labels`
Read [labels.md](labels.md) and run it in full, unchanged. Skip its hand-off for the same reason.

## 6. Hand off
**What changed.** Report four things in order: the settings applied and the rows kept as-is, the files written and the ones skipped with their reasons, the About fields applied, and the label sets provisioned. Name the license picked, or say the user declined one.

**Where it landed.** Give the repo URL, the file paths written, and say the files are unstaged.

**Next.** Crown one move. The scaffold files are uncommitted, so the move is to commit them, with **commitkit** when installed and `git add` + `git commit` otherwise. After the commit, **issuekit** `create` starts filing work against the vocabulary this run provisioned. When `ai-review` was created and nothing listens for it, name that gap in one line, per the `labels` hand-off rule.
