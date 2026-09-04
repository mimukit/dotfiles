---
name: mergekit
description: >-
  Take an open GitHub PR and make it merge-ready on your machine (worktree, base-branch sync, project running, review pack), then merge it once you say so, or service review feedback on a PR you authored. Use when you say "pull PR #34 down so I can test it", "merge PR #34", "address the review comments on my PR", or "my PR is red, fix the CI".
license: MIT
allowed-tools: Bash, Read, Write, Skill
metadata:
  internal: false
---

# mergekit

The other half of a pull request's life. Something else opened it, whether you, an agent, or a teammate; mergekit is what you run when it is your turn to *judge* it, and what you run when your own PR comes back needing changes. It gets the PR into a [git worktree](https://git-scm.com/docs/git-worktree), reusing the one the branch already lives in when there is one, syncs it with the base branch, gets the project running, and prints a **review pack** of everything you need to form an opinion. Then it waits. When you say merge, it merges; when it needs changes, it fixes them in the worktree you already have open.

mergekit is the **one skill permitted to merge a pull request**, a deliberate exception to the "never merge without an explicit ask" rule the rest of a PR toolchain holds. That permission is earned by a single hard precondition, stated in [Never merge automatically](#never-merge-automatically): a human confirms *that specific PR*, every time. Without the confirmation, mergekit has no more authority than any other skill.

It forms **no opinion about the code**. Judging the source is a code-review job; mergekit sets the review up and executes the decision you reach.

## When this fires

The PR already exists, and you are either reviewing it, or you authored it and it has come back needing changes:

- **list.** "What PRs are waiting on me", "show me the ready-for-review PRs", "mergekit list".
- **start `<n>`.** "Pull PR #34 down so I can test it", "set up #34 for review", "check out this PR for QA", "get #34 merge-ready".
- **close `<n>`.** "Merge #34", "this one's good, land it", "#34 needs changes: <findings>".
- **fix `<n>`.** The author's side: "my PR is red, fix the CI", "address the review comments on #34", "respond to the feedback on my PR". It triages the feedback before acting on it; it does not apply every comment on sight.

If a PR is named but the action isn't, assume `start`, because setting a PR up is safe and reversible while merging is not.

**Not this skill:** opening a PR from your branch, or judging whether the code is any good. Those belong to a PR-authoring skill and a code-review skill respectively. mergekit begins at an open PR and ends at a merged or updated one.

## Never merge automatically

Every merge requires an explicit, per-PR confirmation from a human who has just reviewed *that* PR. Concretely:

- **Never a batch.** "Merge them all" is not a confirmation for any individual PR. Ask once per PR, naming the number and title.
- **A stack cascade is one action, so it takes one confirmation that names every PR in it.** Merging a PR in a stack merges every unmerged PR *below* it, bottom-up, so the reviewer who says yes to the top is saying yes to all of them. That is not an exception to the rule above; it is the rule applied honestly. The prompt lists each PR the cascade will land, in merge order, with number and title, so nothing merges that the human did not see named. A cascade nobody enumerated is exactly the batch this rule bans.
- **Never inferred.** Green CI, an approving review, zero unresolved threads, and a passing local gate are *inputs to the human's decision*, and none of them is the decision. A perfectly green PR still waits.
- **Never default-yes.** Don't phrase the prompt so silence merges. No answer means no merge.
- **Never as a side effect.** `start` never merges. A fix round never merges. Only `close` merges, and only after the confirmation.

The same preview-and-confirm rule covers every other outward-facing mutation: pushing a sync, commenting, closing an issue. Show what will happen, wait for the OK.

**Label writes are exempt, in every mode.** Adding or removing a label on an issue or a PR runs straight through, with no prompt: strip a merged PR's status label, strip a closed issue's `in-review` or `in-progress`, flip its dependents `blocked → ready`, set a priority. A label is cheap, visible, and reversible with one command, and a declined write leaves the tracker lying about merged work. Report every label move in the hand-off. The exemption reaches the labels and nothing else.

## Preflight

Every mode starts here:

```sh
gh --version && gh auth status              # GitHub CLI installed + authenticated
gh repo view --json nameWithOwner           # inside a repo
```

- If `gh` is missing or unauthenticated, say so and point to `https://cli.github.com` / `gh auth login`. Don't work around it.
- **Get the base branch from gitkit.** Never assume `main`, and don't re-derive it here; repos that default to `develop` or `trunk` are real. Everything below written as `origin/<base>` means whatever gitkit returns.
- For `start` and `close`, confirm the PR exists and is open before touching the filesystem.

## What gitkit owns

mergekit does not implement worktrees, base-ref detection, or the rebase-versus-merge rule, because **gitkit** does, and mergekit calls it for all three. What mergekit owns is the *policy about when*: that a PR is worth pulling down, that a sync should happen before a human reads the diff, that a merge needs a confirmation. If you find a worktree path convention, a base-ref ladder, or a sync rule restated below as mergekit's own, that is a bug.

When gitkit isn't installed, fall back to the plain git commands named inline, but keep the same convention, and don't invent a different one.

## The modes

The mode bodies live in one file each under `modes/`. Route with [When this fires](#when-this-fires), read that one file, and follow it. Everything above this line applies to every mode and is not restated in the mode files.

- Mode `list` → read [modes/list.md](modes/list.md), then follow it.
- Mode `start <n>` → read [modes/start.md](modes/start.md), then follow it.
- Mode `close <n>` → read [modes/close.md](modes/close.md), then follow it.
- Mode `fix <n>` → read [modes/fix.md](modes/fix.md), then follow it.

## Notes

- **The merge exception is narrow.** mergekit may merge because a human is sitting in front of it. It must therefore never be dispatched as a subagent inside an unattended pipeline, because the confirmation would have nobody to come from, and "the orchestrator said yes" is not a human review.
- **No polling, no queue, no auto-merge.** mergekit runs when you invoke it. It does not watch for PRs, does not enable GitHub's auto-merge, and does not act on a schedule.
- **`fix` is interactive too.** Reading review feedback and judging whether each comment is right *for this project* is judgment work, so mergekit does not do it unattended, and `fix` never runs inside an automated pipeline. Its [triage step](modes/fix.md#2-triage-the-punch-list-and-decide-what-is-actually-worth-fixing) exists to be overruled by a human, which needs one present. It is the author-side counterpart to `start`: it services the PR but, like every mode here, never merges it.
- **Force-push only with a lease, and only behind the gate.** gitkit's sync rule rebases by default, so a PR branch does get rewritten, but always `--force-with-lease`, never bare `--force`, and never without the preview that names how many review threads it outdates. Never force-push to tidy history; the only force-push mergekit performs is the one the human just OK'd as part of a sync.
- **Read-only on fork PRs.** You can review and merge them; you cannot push fixes to them. Say so at setup, not at failure.
- **Bot review feedback is reported, not resolved, on the reviewer's side.** `list` and `start` surface unresolved threads and stop there; judging and answering them is the *author's* job, and `fix` is where it happens. A bot's finding carries no more authority than a human's: both are triaged against the project's own conventions before anything is changed.
- **No shell or `gh` available** (e.g. a browser-based agent)? Then you can't create a worktree or call `gh`. Print the review pack from what the user provides, and print the setup and merge commands as codeblocks for them to run, and never claim a merge happened that you could not perform.
