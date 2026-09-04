## Mode `close <n>`: merge or fix

The reviewer has formed an opinion. Which fork you take depends entirely on which one they state.

### Merge path

1. **Confirm**, per [Never merge automatically](../SKILL.md#never-merge-automatically). Name the PR number and title, state what you are about to do, and wait.

   **First establish whether this PR is a layer in a stack**, because that changes what "merge this" means. Ask gitkit, or read the base ref: a PR whose base is another feature branch is a layer. If it is, list the whole cascade in the prompt and wait on that:

   > Merging #53 also merges #52 and #51 below it, bottom-up:
   > 1. #51 `feat(auth): oidc provider`
   > 2. #52 `feat(auth): session + token refresh`
   > 3. #53 `feat(auth): login ui`
   > All three land on `main`. Proceed?

   **Merge from the layer the reviewer approved, never from the top for convenience.** Merging a lower layer is legal and leaves the layers above it open, rebased onto the base automatically. That partial landing is a feature: a reviewer who is happy with the bottom two and not the third should land two.
2. **Approve, when it's possible.** GitHub does not permit approving your own pull request, so on a self-authored PR (the common case when an agent opens PRs under your account) skip the approval, say once that it was skipped and why, and merge directly. When the author is someone else (or a machine identity), offer `gh pr review <n> --approve` first.
3. **Merge** with a merge commit and a fixed subject:

   ```sh
   gh pr merge <n> --merge --subject "chore(repo): merge pull request #<n>"
   ```

   No squash, no rebase-merge. If your repo's merge-commit convention differs, that subject is the one line to change.

   **A cascade merges through the stack tool, not one PR at a time:**

   ```sh
   gh stack merge --merge
   ```

   This is the one `gh stack` command mergekit owns, and it owns it because merging is mergekit's alone; gitkit takes the stack plumbing and deliberately leaves this out. Run it only after the enumerated confirmation above. Without the stack extension, merge each PR by hand in bottom-up order, waiting for each to land before the next, since every merge re-targets the layer above it.
4. **Hand the landing off to the tracker with issuekit's `close`, then `sync`.** A merge is a tracker event as much as a git one, and both halves belong to an issue-lifecycle skill rather than to mergekit. Invoke **issuekit** for each, in this order, rather than doing any of it here:

   - **issuekit `close <n>`, for the issue this PR closes.** Closing the issue, ticking a parent checklist, unblocking dependents, and reclaiming the issue's worktree are one action, and that mode gates on the merged PR you just produced, previews the whole consequence, and tears the worktree down through gitkit. Skip it only when the PR genuinely references no issue. **After a cascade, run it once per merged layer**, bottom-up, because the cascade landed several PRs and each one retires its own issue and its own worktree. Closing only the top layer's issue leaves the rest looking unfinished while their code is already on trunk.
   - **issuekit `sync`, immediately after, including when there was no issue to close.** `close` lands the one issue you named; `sync` sweeps for what the merge shook loose *around* it: a second issue the PR body closed, a link the PR never carried, a parent checklist still un-ticked, a dependent left `blocked` on a prerequisite that just landed. That drift is invisible from here, because mergekit sees one PR where `sync` reads the whole tracker, and it is cheapest to repair now, while the merge that caused it is the thing everyone is looking at.

   Both modes preview the close and the worktree teardown, so the pair costs a confirmation, not a surprise. **Their lifecycle label writes run without a prompt**, per [the label exemption](../SKILL.md#never-merge-automatically). Without issuekit installed, fall back to plain `gh issue close` / `gh issue edit` calls: preview the close, then strip the stale status label and unblock the dependents in the same pass, and say that the tracker-wide sweep did not happen, rather than implying the tracker is now clean.
5. **Clean up only what *you* created.** After the handoff, one thing may be left that no issue-lifecycle skill knows about: the **fork-PR case**, where mergekit invented both the `pr-<n>-<slug>` branch and its worktree. Remove that through gitkit.

   Everything else stays. [Get a worktree](./start.md#2-get-a-worktree-adopting-first-and-creating-only-if-needed) may have *adopted* an existing worktree, and an adopted worktree is someone else's context: the workspace the feature was implemented in, possibly with an editor and a dev server pointed at it. **Never remove a worktree you adopted on your own initiative, and never delete a branch you did not create.** Say what you are leaving behind instead.

   Teardown is **idempotent**: a worktree that is already gone reports "already gone" rather than erroring. A dirty worktree stops teardown, so show what would be lost instead of forcing the removal.

6. **Hand off.**

   **What changed.** Report the PR merged (number, title, merge commit), whether the approval was skipped and why, and what each half of the issue-lifecycle handoff did: the issue `close` closed, parent ticked, dependents unblocked, and then what `sync` reconciled beyond it. A sweep that found nothing is a result worth stating in a line; it's the difference between a clean tracker and one nobody looked at. **After a cascade, list every PR that landed and every issue that closed**, not just the one the reviewer named, and say which layers are still open above it.

   **Where it landed.** Say which worktrees were removed and which were deliberately left standing, with paths. An adopted worktree that survives is someone's live workspace; naming it is how they know it's still theirs.

   **Next.** A merge frees capacity, so point at what fills it, naming a kit only when it's installed: an issue this merge unblocked, from either the issuekit `close` or the issuekit `sync` pass, is the strongest candidate (**issuekit `start <n>`**), otherwise the next PR waiting on you (`list`), otherwise **statuskit** to re-orient. If a dependent was unblocked *and* another PR is waiting, the PR wins, because finishing outranks starting.

### Fix path

The reviewer wants changes. They already have the code checked out and running, so fix it right there, and do not hand the work back to whatever opened the PR.

1. Turn the reviewer's findings into a concrete spec and implement them **in the live worktree**, preferring an installed implementation skill.
2. Run the repo's test and build gate.
3. Commit in the repo's own style, preferring an installed commit skill.
4. Push. The PR updates in place; the reviewer stays in the same worktree with the app still running.
5. **Hand off.** Return to the review, re-printing only what changed (the commits you added, the gate result, the pushed branch), name the worktree still standing with the app still running, and give the next move: re-test the fixed behavior, then `close <n>` again for the merge decision. Do not merge; that is a fresh decision, and it needs a fresh confirmation.
