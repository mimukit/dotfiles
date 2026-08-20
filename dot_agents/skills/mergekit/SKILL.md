---
name: mergekit
description: >-
  Take an open GitHub PR and make it merge-ready on your machine, with a worktree, a base-branch sync, the project running, and a review pack of everything you need to judge it, then merge it once you say so, or service review feedback on a PR you authored. Use when you review the PRs an agent opened overnight, say "pull PR #34 down so I can test it", "check out this PR for QA", "get this PR merge-ready", "merge PR #34", "address the review comments on my PR", "my PR is red, fix the CI", or run "/mergekit".
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
- **finish `<n>`.** "Merge #34", "this one's good, land it", "#34 needs changes: <findings>".
- **fix `<n>`.** The author's side: "my PR is red, fix the CI", "address the review comments on #34", "respond to the feedback on my PR". It triages the feedback before acting on it; it does not apply every comment on sight.

If a PR is named but the action isn't, assume `start`, because setting a PR up is safe and reversible while merging is not.

**Not this skill:** opening a PR from your branch, or judging whether the code is any good. Those belong to a PR-authoring skill and a code-review skill respectively. mergekit begins at an open PR and ends at a merged or updated one.

## Never merge automatically

Every merge requires an explicit, per-PR confirmation from a human who has just reviewed *that* PR. Concretely:

- **Never a batch.** "Merge them all" is not a confirmation for any individual PR. Ask once per PR, naming the number and title.
- **Never inferred.** Green CI, an approving review, zero unresolved threads, and a passing local gate are *inputs to the human's decision*, and none of them is the decision. A perfectly green PR still waits.
- **Never default-yes.** Don't phrase the prompt so silence merges. No answer means no merge.
- **Never as a side effect.** `start` never merges. A fix round never merges. Only `finish` merges, and only after the confirmation.

The same preview-and-confirm rule covers every other outward-facing mutation: pushing a sync, commenting, relabeling, closing an issue. Show what will happen, wait for the OK.

## Preflight

Every mode starts here:

```sh
gh --version && gh auth status              # GitHub CLI installed + authenticated
gh repo view --json nameWithOwner           # inside a repo
```

- If `gh` is missing or unauthenticated, say so and point to `https://cli.github.com` / `gh auth login`. Don't work around it.
- **Get the base branch from gitkit.** Never assume `main`, and don't re-derive it here; repos that default to `develop` or `trunk` are real. Everything below written as `origin/<base>` means whatever gitkit returns.
- For `start` and `finish`, confirm the PR exists and is open before touching the filesystem.

## What gitkit owns

mergekit does not implement worktrees, base-ref detection, or the rebase-versus-merge rule, because **gitkit** does, and mergekit calls it for all three. What mergekit owns is the *policy about when*: that a PR is worth pulling down, that a sync should happen before a human reads the diff, that a merge needs a confirmation. If you find a worktree path convention, a base-ref ladder, or a sync rule restated below as mergekit's own, that is a bug.

When gitkit isn't installed, fall back to the plain git commands named inline, but keep the same convention, and don't invent a different one.

## Mode `list`: the morning dashboard

What is actually waiting on you, in one table:

```sh
gh pr list --state open --json number,title,headRefName,isDraft,statusCheckRollup,reviewDecision,author,updatedAt
```

Three facts that command cannot give you matter more than the ones it can, so gather them per PR:

- **Unresolved review threads.** REST does not expose thread resolution state at all; only GraphQL does, via a `reviewThreads` connection carrying `isResolved` and `isOutdated`. Query it with `gh api graphql`; if the shape has moved, check the current [GraphQL API docs](https://docs.github.com/en/graphql) rather than guessing. A PR with a bot review sitting unanswered is not ready for your time.
- **Behind the base branch.** Run `git fetch origin` once, then compare each head against `origin/<base>`, because a PR that is behind is one you would be reviewing in a state that will never exist.
- **A QA plan and proof.** Look for the artifacts your repo's conventions produce (a QA plan doc, a proof bundle, whatever the PR body links). Absence is a fact worth printing, not a silence.

Print one table, most-ready first, with drafts and PRs authored by others clearly marked. **Do not crown a "next" PR**, because ranking work is a project-status job, and a reviewer's queue is theirs to order.

## Mode `start <n>`: make it merge-ready

### 1. Resolve the head

```sh
gh pr view <n> --json headRefName,headRepositoryOwner,isCrossRepository,author,title,body,url
```

A **cross-repository (fork) PR** is read-only from here: you can review and merge it, but you cannot push fixes to the contributor's branch. Say that plainly at setup time rather than letting it surface as a confusing push failure later.

### 2. Get a worktree, adopting first and creating only if needed

**Hand this to gitkit, keyed on the PR's head branch.** The key point, and the reason this step is not "create a worktree": a PR's branch very often *already has one*, because the branch was implemented in a worktree on this same machine, and that worktree is still sitting there. Git allows a branch to be checked out in exactly one worktree, so creating a second one for the review does not merely duplicate work, it hard-fails:

```
fatal: 'feature-x' is already used by worktree at '.../wt-a'
```

So: resolve the head branch, look it up, and **reuse the worktree that already holds it**. Create one only when the branch has none.

- **Same-repo PR.** Fetch the head branch (`git fetch origin <head>:<head>` or `git fetch origin` plus a local checkout), then ask gitkit for that branch's worktree. Pushes from it go back to the PR.
- **Fork PR.** There is no local branch yet, so one must be invented: `git fetch origin "pull/<n>/head:pr-<n>-<slug>"`, where `<slug>` is the head branch name kebab-cased and capped at roughly 40 characters. Then the worktree is created on *that* branch, and takes its name.
- **Already have one.** Adopt it and say so. Re-running `start` is a normal thing a reviewer does; it must never error, and must never blow away work in progress. If the adopted worktree is dirty, **report what's uncommitted before doing anything else** and let the reviewer decide whether to continue, because you are standing in someone's live workspace, possibly mid-change, not a scratch checkout.

The worktree lands wherever gitkit's convention puts it, outside the repository rather than in a `.worktrees/` directory inside it. An in-repo worktree gets swept into docker build contexts, bind mounts, and file watchers, and every one of those failures surfaces far from its cause. Nothing here needs a `.git/info/exclude` entry.

### 3. Sync with the base branch

Bring `origin/<base>` into the PR branch *before* the human reviews, so they review what will actually land:

```sh
git fetch origin
git rev-list --left-right --count origin/<base>...HEAD    # "<behind>\t<ahead>"; left > 0 means behind
```

If behind, **hand the sync to gitkit**, which owns the rebase-versus-merge rule in full. What mergekit owns is the *when*: that the sync happens before a human reads the diff, and that nothing leaves this machine without their OK.

Two things follow from gitkit's rule that matter specifically here. A PR branch is published, so the sync is in the **preview-and-confirm** class: one prompt covering the rebase and its `--force-with-lease` push, never a silent rewrite of a branch a reviewer may already be looking at. And this is the one place the merge exception's trigger actually fires: [the review pack](#5-print-the-review-pack) already queries unresolved review threads, so **feed that count into the preview**, because a rebase marks every one of them outdated, and the reviewer is about to spend their attention on exactly those threads. Name the number, still recommend the rebase, and let them take the merge if the threads are worth more than the history.

**On conflict:** stop and surface it. List the conflicted files (`git diff --name-only --diff-filter=U`), propose a resolution for each, and confirm before writing. Then, before pushing, **run the repo's own test and build gate**, because a conflict resolution is a code change, and it can break something CI passed on five minutes ago. Push the sync only after the gate is green and the human has OK'd it, so the PR itself becomes mergeable on GitHub. On a fork PR you cannot push; say so, and keep the sync local for review purposes only.

### 4. Set the project up

Detect the manifest (`package.json`, `pyproject.toml`, `go.mod`, `Gemfile`, `Cargo.toml`, …) and run the install the repo actually uses: the lockfile tells you which package manager, the scripts tell you the dev command. Prefer a project-local run or dev skill when one exists. **Never invent a command**: if you cannot determine how to start the app, say so and ask, rather than guessing at a `dev` script that doesn't exist. Copy `.env.example` to `.env` only if that is the repo's documented setup and the file is absent.

### 5. Print the review pack

Everything the reviewer needs, assembled once so they don't go hunting:

- PR title, number, author, URL, and the body's summary.
- The linked issue and its acceptance criteria, when the PR references one.
- The commits (`git log origin/<base>..HEAD --oneline`) and the file-level shape of the diff (`--stat`).
- The QA plan, if the repo has one for this change, and any proof artifacts.
- **Unresolved review threads with `file:line` and the comment text**, bot or human. This is the highest-value part of the pack: it is what the reviewer would otherwise re-derive by hand.
- Any follow-up nits the PR body itself records.
- CI status per check, and whether the branch is now in sync.

**Name what is missing.** "No QA plan in this repo's conventional location" is information; printing nothing where a QA plan would go is not.

### 6. Hand off

_Write every hand-off in this skill in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

**What changed.** Report whether the worktree was adopted or created, and whether a sync was pushed (and if so, whether it rebased or took the merge exception, and how many threads it outdated). Nothing else here mutates anything.

**Where it landed.** Two lines: the worktree path, and the single command that starts the app.

**Next.** The reviewer reads, runs, and forms an opinion; then `finish <n>` executes whichever verdict they reach, whether a merge or a fix round. Say both halves, so it's clear merging isn't the assumed outcome.

Then stop, because the human reviews and tests. mergekit does not judge the code, and does not proceed to `finish` on its own.

## Mode `finish <n>`: merge or fix

The reviewer has formed an opinion. Which fork you take depends entirely on which one they state.

### Merge path

1. **Confirm**, per [Never merge automatically](#never-merge-automatically). Name the PR number and title, state what you are about to do, and wait.
2. **Approve, when it's possible.** GitHub does not permit approving your own pull request, so on a self-authored PR (the common case when an agent opens PRs under your account) skip the approval, say once that it was skipped and why, and merge directly. When the author is someone else (or a machine identity), offer `gh pr review <n> --approve` first.
3. **Merge** with a merge commit and a fixed subject:

   ```sh
   gh pr merge <n> --merge --subject "chore(repo): merge pull request #<n>"
   ```

   No squash, no rebase-merge. If your repo's merge-commit convention differs, that subject is the one line to change.
4. **Hand the landing off to the tracker with `close`, then `sync`.** A merge is a tracker event as much as a git one, and both halves belong to an issue-lifecycle skill rather than to mergekit. Invoke **issuekit** for each, in this order, rather than doing any of it here:

   - **`close <n>`, for the issue this PR closes.** Closing the issue, ticking a parent checklist, unblocking dependents, and reclaiming the issue's worktree are one action, and `close` gates on the merged PR you just produced, previews the whole consequence, and tears the worktree down through gitkit. Skip it only when the PR genuinely references no issue.
   - **`sync`, immediately after, including when there was no issue to close.** `close` lands the one issue you named; `sync` sweeps for what the merge shook loose *around* it: a second issue the PR body closed, a link the PR never carried, a parent checklist still un-ticked, a dependent left `blocked` on a prerequisite that just landed. That drift is invisible from here, because mergekit sees one PR where `sync` reads the whole tracker, and it is cheapest to repair now, while the merge that caused it is the thing everyone is looking at.

   Both modes preview before they mutate, so the pair costs a confirmation, not a surprise. Without issuekit installed, fall back to plain `gh issue close` / `gh issue edit` calls, previewed and confirmed like any other mutation, and say that the tracker-wide sweep did not happen, rather than implying the tracker is now clean.
5. **Clean up only what *you* created.** After the handoff, one thing may be left that no issue-lifecycle skill knows about: the **fork-PR case**, where mergekit invented both the `pr-<n>-<slug>` branch and its worktree. Remove that through gitkit.

   Everything else stays. [Get a worktree](#2-get-a-worktree-adopting-first-and-creating-only-if-needed) may have *adopted* an existing worktree, and an adopted worktree is someone else's context: the workspace the feature was implemented in, possibly with an editor and a dev server pointed at it. **Never remove a worktree you adopted on your own initiative, and never delete a branch you did not create.** Say what you are leaving behind instead.

   Teardown is **idempotent**: a worktree that is already gone reports "already gone" rather than erroring. A dirty worktree stops teardown, so show what would be lost instead of forcing the removal.

6. **Hand off.**

   **What changed.** Report the PR merged (number, title, merge commit), whether the approval was skipped and why, and what each half of the issue-lifecycle handoff did: `close`'s issue closed, parent ticked, dependents unblocked, and then what `sync` reconciled beyond it. A sweep that found nothing is a result worth stating in a line; it's the difference between a clean tracker and one nobody looked at.

   **Where it landed.** Say which worktrees were removed and which were deliberately left standing, with paths. An adopted worktree that survives is someone's live workspace; naming it is how they know it's still theirs.

   **Next.** A merge frees capacity, so point at what fills it, naming a kit only when it's installed: an issue this merge unblocked, from either the `close` or the `sync` pass, is the strongest candidate (**issuekit `start <n>`**), otherwise the next PR waiting on you (`list`), otherwise **statuskit** to re-orient. If a dependent was unblocked *and* another PR is waiting, the PR wins, because finishing outranks starting.

### Fix path

The reviewer wants changes. They already have the code checked out and running, so fix it right there, and do not hand the work back to whatever opened the PR.

1. Turn the reviewer's findings into a concrete spec and implement them **in the live worktree**, preferring an installed implementation skill.
2. Run the repo's test and build gate.
3. Commit in the repo's own style, preferring an installed commit skill.
4. Push. The PR updates in place; the reviewer stays in the same worktree with the app still running.
5. **Hand off.** Return to the review, re-printing only what changed (the commits you added, the gate result, the pushed branch), name the worktree still standing with the app still running, and give the next move: re-test the fixed behavior, then `finish <n>` again for the merge decision. Do not merge; that is a fresh decision, and it needs a fresh confirmation.

## Mode `fix <n>`: service review feedback on your own PR

The mirror of `start`. `start` pulls down a PR for *you* to review; `fix` is for a PR *you authored* that has come back with review comments, a change request, or red CI, meaning the author's side of the same loop. It reads the feedback, **judges which of it is worth acting on**, drives those changes, pushes, and answers every thread. Like every mergekit mode, it stops short of merging.

It overlaps `finish`'s [Fix path](#fix-path) in mechanics but differs at both ends: that path implements a verdict *you* just reached while reviewing someone else's PR, whereas `fix` starts from feedback *someone else* left on yours, so it opens by gathering that feedback and closes by answering it.

### 1. Gather the feedback

Assemble the punch list before touching code:

- **Unresolved review threads** with `file:line` and comment text, bot or human, via the same GraphQL `reviewThreads` query [`list`](#mode-list-the-morning-dashboard) uses. These are the change requests.
- **Failing checks** from `gh pr checks <n>`, with each failing job's name and, where reachable, its log tail. Red CI is feedback too.
- **The review decision** from `gh pr view <n> --json reviewDecision`, so you know whether a re-request of review is warranted at the end.

If there is nothing to service, meaning no unresolved threads and green CI, say so and stop. There is nothing to fix.

### 2. Triage the punch list, and decide what is actually worth fixing

**Feedback is a claim, not an instruction.** A review comment, from a bot or a human, is someone's read of the code from outside the change, and a fair share of it is wrong for *this* project: a rule the repo has deliberately opted out of, a suggestion that contradicts the plan this PR implements, a real point that belongs in its own issue rather than this diff. Applying all of it because it was written down is how a PR grows a second unreviewed change and how a project's conventions get quietly overwritten by a linter's defaults. So every item gets a verdict *before* any code is touched.

Judge each item against what the project actually is, in this order: its **documented conventions** (the repo's agent-instructions file, its contributing guide, ADRs, lint and formatter config), the **surrounding code**, and the **stated scope** of this PR and the issue or plan it implements. Then assign one of three verdicts:

- **Fix.** Correct, in scope, and consistent with the above. This is the default for anything that is plainly a bug, a real failure, or a convention the repo does hold.
- **Decline**, with the reason named, because it goes in the reply. The recurring ones: it contradicts a documented convention or a settled decision; it is a bot false positive or a misreading of the code; it is already handled elsewhere in the diff; it is real but **out of scope**, meaning a separate change that deserves its own issue rather than a drive-by in a PR under review.
- **Ask.** You cannot tell from the repo alone. Genuine trade-offs, anything that conflicts with the implementation plan or a direction the user has stated, anything that widens the change's blast radius, and anything where your confidence is simply low.

Rules that keep this honest:

- **Ask in one round, not one at a time.** Batch every `ask` item into a single compact table (item, what it wants, your recommended verdict and why) and let the user rule on them together. Never grind through a thread-by-thread interrogation.
- **When in doubt, ask rather than decline.** Declining silently is the failure mode that costs the most: the reviewer believes it was considered, and nobody finds out otherwise.
- **A declined item is still answered.** It stays on the punch list through [Answer the feedback](#5-answer-the-feedback), where it gets a reply stating the reason and stays unresolved. Declining is a position you state, not a thread you drop.
- **Red CI is not triaged away.** A failing check is a fact about the branch, not an opinion about the code. If a job fails for a reason you consider illegitimate, surface it; don't file it under "declined" and push.
- **Print the triage before you start.** One line per item with its verdict, so the user sees the whole shape and can overrule any of it. If most of the list came back declined, say so plainly, because a PR whose feedback is mostly wrong usually means the reviewer and the PR disagree about the change itself, and that is worth a conversation, not a fix round.

### 3. Get the worktree and sync

Adopt the branch's existing worktree exactly as [`start` does](#2-get-a-worktree-adopting-first-and-creating-only-if-needed), because your own PR almost always still has the worktree it was built in, then sync exactly as [`start` syncs](#3-sync-with-the-base-branch), through gitkit. It is your branch, but it is *published*, so the sync previews and waits for an OK before anything is pushed. The thread count matters more here than anywhere else: you are about to *answer* those threads, and a rebase outdates the ones you have not replied to yet, so gather and triage the punch list first, and put the number in the preview. A PR you opened from a fork you don't control is the read-only case, where you cannot push; say so and stop.

### 4. Fix, gate, commit, push

For each item you decided to **fix**, in the live worktree:

1. Implement the change, preferring an installed implementation skill.
2. Run the repo's test and build gate.
3. Commit in the repo's own style, preferring an installed commit skill.

Then push with a plain `git push`, and the PR updates in place. This is **bounded**, like any fix round: if an item turns out to be ambiguous once you are inside the code, or you can't get the gate green, stop and surface it rather than guessing at what the reviewer meant. An item can still flip to **ask** here, because triage judged it from the outside, and the code sometimes disagrees.

### 5. Answer the feedback

Close the loop so the reviewer sees every item handled, fixed *and* declined, each mutation previewed and confirmed like any other:

- **Reply and resolve** each thread you actually fixed, pointing at the commit that did it. **Never resolve a thread you didn't fix.**
- **Reply to each declined thread with the reason, and leave it open.** A declined item is a position, not a silence: name what it conflicts with, whether the convention, the decision, or the PR's scope, and let the reviewer overrule you. Out-of-scope items are the exception worth going further on: offer to file the follow-up issue rather than leaving the point to evaporate.
- **Re-request review** when the decision was `CHANGES_REQUESTED` (`gh pr edit <n> --add-reviewer <login>`, or the `requested_reviewers` REST endpoint).
- **Do not merge.** Servicing feedback earns a fresh review, not a landing, because merging is `finish`'s job, behind its human gate.

### 6. Hand off

**What changed.** Report the punch-list items you fixed and the commits that did it, the gate result, and which threads you replied to, resolved, or left open. **Report the declines with their reasons**, not just the fixes; the reviewer needs to see what you chose not to do more than what you did.

**Where it landed.** Give the branch pushed and the PR updated in place, plus the worktree path you worked in.

**Next.** The ball is back in the reviewer's court, so the move is theirs, not yours: the re-requested review, or CI re-running on the push. Name first what you *couldn't* service and what you *declined*, because a rejected comment, an ambiguous one, or a gate you couldn't get green is the thing standing between this PR and a merge, and it needs the reviewer, not another fix round. Once they approve, `finish <n>` lands it.

## Notes

- **The merge exception is narrow.** mergekit may merge because a human is sitting in front of it. It must therefore never be dispatched as a subagent inside an unattended pipeline, because the confirmation would have nobody to come from, and "the orchestrator said yes" is not a human review.
- **No polling, no queue, no auto-merge.** mergekit runs when you invoke it. It does not watch for PRs, does not enable GitHub's auto-merge, and does not act on a schedule.
- **`fix` is interactive too.** Reading review feedback and judging whether each comment is right *for this project* is judgment work, so mergekit does not do it unattended, and `fix` never runs inside an automated pipeline. Its [triage step](#2-triage-the-punch-list-and-decide-what-is-actually-worth-fixing) exists to be overruled by a human, which needs one present. It is the author-side counterpart to `start`: it services the PR but, like every mode here, never merges it.
- **Force-push only with a lease, and only behind the gate.** gitkit's sync rule rebases by default, so a PR branch does get rewritten, but always `--force-with-lease`, never bare `--force`, and never without the preview that names how many review threads it outdates. Never force-push to tidy history; the only force-push mergekit performs is the one the human just OK'd as part of a sync.
- **Read-only on fork PRs.** You can review and merge them; you cannot push fixes to them. Say so at setup, not at failure.
- **Bot review feedback is reported, not resolved, on the reviewer's side.** `list` and `start` surface unresolved threads and stop there; judging and answering them is the *author's* job, and `fix` is where it happens. A bot's finding carries no more authority than a human's: both are triaged against the project's own conventions before anything is changed.
- **No shell or `gh` available** (e.g. a browser-based agent)? Then you can't create a worktree or call `gh`. Print the review pack from what the user provides, and print the setup and merge commands as codeblocks for them to run, and never claim a merge happened that you could not perform.
