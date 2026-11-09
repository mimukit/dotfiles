## Mode `close [<n>]`: merge or fix

The reviewer has formed an opinion. Which fork you take depends entirely on which one they state.

### Merge path

1. **Resolve the PR.** With a number, use that PR. With no number, take the PR of the current branch in the current worktree:

   ```sh
   git branch --show-current
   gh pr list --head <branch> --state open --json number,title,headRefOid,baseRefName
   git status --porcelain && git rev-parse HEAD
   ```

   Use that PR without a question when exactly one open PR has this branch as its head. Stop and ask when any of these is true:

   - HEAD is detached, or the branch is the base branch.
   - The branch has no open PR, or more than one.
   - The local HEAD differs from the PR's `headRefOid`, or the worktree has uncommitted changes. The reviewer may expect work to land that is not on the PR.

   Name what you found in the question, and offer the PR you would pick. Ends when one open PR is resolved, or on the reviewer's answer.
2. **Confirm only on a doubt**, per [Never merge automatically](../SKILL.md#never-merge-automatically). A direct instruction to merge or close this PR is the confirmation, so do not ask again. Bind it to a head SHA: the reviewed head that [`start`](./start.md#1-resolve-the-head) recorded, or else the `headRefOid` you read now. Ask, naming the PR number, title, and head SHA, only when one of these is true:

   - The instruction is not a direct merge ask, for example "looks fine?" or "what do you think".
   - The instruction covers more than one PR, for example "merge them all".
   - The head moved after `start` recorded it in this run.
   - The PR is a layer in a stack, and the merge lands layers the reviewer did not name.

   Ends when the head SHA is bound, or on the reviewer's answer for that SHA.

   **First establish whether this PR is a layer in a stack**, because that changes what "merge this" means. Ask gitkit, or read the base ref: a PR whose base is another feature branch is a layer. If the merge lands layers below it, list the whole cascade in the prompt and wait on that:

   > Merging #53 also merges #52 and #51 below it, bottom-up:
   > 1. #51 `feat(auth): oidc provider`
   > 2. #52 `feat(auth): session + token refresh`
   > 3. #53 `feat(auth): login ui`
   > All three land on `main`, at heads `a1b2c3d`, `e4f5a6b`, `c7d8e9f`. Proceed?

   **Merge from the layer the reviewer approved, never from the top for convenience.** Merging a lower layer is legal and leaves the layers above it open, rebased onto the base automatically. That partial landing is a feature: a reviewer who is happy with the bottom two and not the third should land two.
3. **Approve, when it's possible.** GitHub does not permit approving your own pull request, so on a self-authored PR (the common case when an agent opens PRs under your account) skip the approval, say once that it was skipped and why, and merge directly. When the author is someone else (or a machine identity), post `gh pr review <n> --approve` first. The merge instruction covers the approval, so it needs no separate prompt. Ends when the approval is posted or its skip is stated.
4. **Wait for CI to pass.** This is the default, so a merge never lands on a red or still-running head. Watch the PR's checks until they finish:

   ```sh
   gh pr checks <n> --watch --fail-fast
   ```

   Read the result by exit code and output:

   - Exit 0: every check passed or was skipped. Continue to the merge.
   - "no checks reported": the repo has no CI for this PR. Continue, and say so in the hand-off.
   - Any other failure: stop. Name each failing or cancelled check with its link, and merge nothing. On your own PR, route to `fix <n>`; otherwise route to the [Fix path](#fix-path).

   The watch can outlast a host's command timeout, so run it in the background where the host caps command time. Skip the wait only when the reviewer says so in the instruction, for example "merge now, don't wait for CI", and report the skip. After a cascade, wait on every layer before the stack merge. Ends when every check passed or the PR has none, or on a reported stop.
5. **Recheck the target, then merge.** Read the PR again immediately before the merge:

   ```sh
   gh pr view <n> --json state,headRefOid,baseRefName,isDraft,mergeable
   ```

   Stop and report when the PR is no longer open, is a draft, cannot merge, or has a base that differs from the one you resolved. Stop when `headRefOid` differs from the bound SHA too: someone pushed after the review, and the new commits need a fresh review and a fresh confirmation. Then merge with a merge commit, a fixed subject, and the bound SHA passed to the call:

   ```sh
   gh pr merge <n> --merge --match-head-commit <sha> --subject "chore(repo): merge pull request #<n>"
   ```

   `--match-head-commit` makes GitHub refuse the merge when the head moved between the recheck and the call. Ends when GitHub reports the PR merged, or on a reported stop.
   No squash, no rebase-merge. If your repo's merge-commit convention differs, that subject is the one line to change.

   **A cascade merges through the stack tool, not one PR at a time:**

   ```sh
   gh stack merge --merge
   ```

   This is the one `gh stack` command mergekit owns, and it owns it because merging is mergekit's alone; gitkit takes the stack plumbing and deliberately leaves this out. Run it only after the enumerated confirmation above, and only after the recheck finds every layer's `headRefOid` equal to its confirmed SHA. Without the stack extension, merge each PR by hand in bottom-up order with `--match-head-commit`, waiting for each to land before the next, since every merge re-targets the layer above it.
6. **Hand the landing off to the tracker with issuekit's `close`, then `sync`.** A merge is a tracker event as much as a git one, and both halves belong to an issue-lifecycle skill rather than to mergekit. Invoke **issuekit** for each, in this order, rather than doing any of it here:

   - **issuekit `close <n>`, for the issue this PR closes.** Closing the issue, ticking a parent checklist, unblocking dependents, and reclaiming the issue's worktree are one action, and that mode gates on the merged PR you just produced, previews the whole consequence, and tears the worktree down through gitkit. Skip it only when the PR genuinely references no issue. **After a cascade, run it once per merged layer**, bottom-up, because the cascade landed several PRs and each one retires its own issue and its own worktree. Closing only the top layer's issue leaves the rest looking unfinished while their code is already on trunk.
   - **issuekit `sync`, immediately after, including when there was no issue to close.** `close` lands the one issue you named; `sync` sweeps for what the merge shook loose *around* it: a second issue the PR body closed, a link the PR never carried, a parent checklist still un-ticked, a dependent left `blocked` on a prerequisite that just landed. That drift is invisible from here, because mergekit sees one PR where `sync` reads the whole tracker, and it is cheapest to repair now, while the merge that caused it is the thing everyone is looking at.

   This step ends when both issuekit modes have reported, or the fallback calls have run. issuekit `close` prints its preview and runs it without a wait, because the merge instruction is its approval. `sync` still previews its own edits. **Their lifecycle label writes run without a prompt**, per [the label exemption](../SKILL.md#never-merge-automatically). Without issuekit installed, fall back to plain `gh issue close` / `gh issue edit` calls: preview the close, then strip the stale status label and unblock the dependents in the same pass, and say that the tracker-wide sweep did not happen, rather than implying the tracker is now clean.
7. **Remove the PR's worktree and local branch.** This is the default after a merge, and it needs no prompt. The merge instruction is the confirmation, per gitkit's [merged-PR exception](../../gitkit/SKILL.md#remove). Pass gitkit the PR number and the head branch. This covers an adopted worktree, a branch that gitkit did not create, and the fork-PR `pr-<n>-<slug>` branch. When issuekit `close` already removed them, report "already gone".

   Keep an item only in these cases, and name each kept item with its reason:

   - The reviewer said to keep the worktree or the branch.
   - The worktree is dirty. Show what the removal would lose.
   - The local branch tip is not the merged head, so it holds commits the merge never saw.
   - An open PR uses the branch as its base.
   - The worktree's declared teardown failed. gitkit runs it before the removal, with no prompt, and keeps the worktree when it fails.

   When the worktree is this session's working directory, run the commands from the main checkout. Without gitkit, run the `teardown:` block of the repo's `## Worktree setup` section from inside the worktree first, then `git -C <repo> worktree remove <path>` and `git -C <repo> branch -d <branch>`, with the same keep cases. A failed teardown keeps the worktree. Use `-D` only when the branch tip equals the merged `headRefOid`. After a cascade, do this for each merged layer. Ends when each merged PR's worktree and local branch are gone, or are kept with a named reason.

8. **Check the merged diff for database migrations.** Merged code is deployed code, and a migration that never runs against production leaves the schema behind the application. List the PR's files and look for the repo's migration path — `drizzle/`, `migrations/`, `db/migrate/`, `prisma/migrations/`, `alembic/versions/`, `supabase/migrations/`, or whatever this repo uses:

   ```sh
   gh pr diff <n> --name-only
   ```

   After a cascade, check every merged layer. Record the migration files you found, with their paths. When there are none, record that and say nothing about migrations in the hand-off. Ends when every merged PR's file list is checked.

9. **Hand off.**

   **What changed.** Report the PR merged (number, title, merge commit, and the head SHA it was bound to), whether the approval was skipped and why, the CI result (passed, no checks, or a wait the reviewer skipped), and what each half of the issue-lifecycle handoff did: the issue `close` closed, parent ticked, dependents unblocked, and then what `sync` reconciled beyond it. A sweep that found nothing is a result worth stating in a line; it's the difference between a clean tracker and one nobody looked at. **After a cascade, list every PR that landed and every issue that closed**, not just the one the reviewer named, and say which layers are still open above it.

   **Where it landed.** Name each worktree and local branch that was removed, and each one that was kept, with its path and reason. When the removed worktree was this session's working directory, say so, and name the main checkout as the place to continue.

   **Next.** A merge frees capacity, so point at what fills it, naming a kit only when it's installed: an issue this merge unblocked, from either the issuekit `close` or the issuekit `sync` pass, is the strongest candidate (**issuekit `start <n>`**), otherwise the next PR waiting on you (`list`), otherwise **statuskit** to re-orient. If a dependent was unblocked *and* another PR is waiting, the PR wins, because finishing outranks starting. A merged `hotfix-*` PR whose repository declares `backport:` branches outranks both: the next move is **gitkit** `hotfix` backport for this PR, otherwise a `git cherry-pick -x` onto each branch through its own PR.

   **Migrations.** When the merge carried migration files, close the hand-off with this reminder, as the last thing the reviewer reads:

   > This merge adds 2 migration files:
   > - `drizzle/0007_flaky_moon_knight.sql`
   > - `drizzle/0008_smooth_silver_sable.sql`
   >
   > Run the migration against the production database. Then confirm that every new table and column exists in production.

   Name each file. Do not run the migration, and do not offer to run it. When the merge carried no migration file, write nothing here.

### Fix path

The reviewer wants changes. They already have the code checked out and running, so fix it right there, and do not hand the work back to whatever opened the PR.

1. Turn the reviewer's findings into a concrete spec and implement them **in the live worktree**, preferring an installed implementation skill. Ends when every finding maps to a change or to a stated reason it was not made.
2. Run the repo's test and build gate. Ends with a pass, or a stop that reports the failure.
3. Commit in the repo's own style, preferring an installed commit skill. Ends when no change from this round is left uncommitted.
4. Push. The PR updates in place; the reviewer stays in the same worktree with the app still running. Ends when `origin` holds the new head.
5. **Hand off.** Return to the review, re-printing only what changed (the commits you added, the gate result, the pushed branch), name the worktree still standing with the app still running, and give the next move: re-test the fixed behavior, then `close <n>` again for the merge decision. Do not merge; that is a fresh decision, and it needs a fresh confirmation.
