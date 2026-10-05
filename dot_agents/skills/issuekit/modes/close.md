## Mode: `close`

The other bookend to [`start`](./start.md): the issue's PR has merged, so close it out and reclaim its workspace. Closing the issue and removing the worktree are destructive, so this mode **previews and waits for an OK** before it runs them. The label writes need no OK at all, per [the label exemption](../SKILL.md#preflight-every-mode); name them in the preview and run them.

### 1. Confirm the PR actually merged, a hard precondition

```sh
gh pr list --search "<n>" --state merged --json number,title,url,closingIssuesReferences
gh pr view <pr> --json state,mergedAt
```

**A merged PR is required, not assumed.** A search hit is not a link: keep only a PR whose `closingIssuesReferences` names `#<n>`, or whose body carries `Closes #<n>` when it targeted a non-default branch, or the one the user names. If none is found, whether no PR at all or one that's still open, `close` does **nothing**: no close, no label change, no worktree removal. Report exactly what's blocking (`PR #X still open`, `no PR found for #N`) and stop. A failed query is unknown, not "no PR": name the failed call and stop the same way.

This step is done when one merged PR is linked to `#<n>`, or the run has stopped with the reason named.

This precondition is the whole reason `close` is safe to run on a name you half-remember. Its two irreversible acts, closing the issue and deleting a worktree, are both gated behind evidence that the work actually landed. A forced teardown of unlanded work stays a deliberate thing the user does themselves, through gitkit directly.

### 2. Preview, then confirm

Show the full consequence in one line and wait:

> PR #10 (`feat(auth): add sso login`) merged → close #42 and strip its `in-review`, unblock #44 (`blocked → ready`), move #46 (`stacked → ready`), keep #45 `blocked` (still waits on #43), remove the worktree for `issue-42-add-sso-login`.

Compute the dependent moves for the preview with [the transition rule](../SKILL.md#promoting-a-dependent), so each one shows its real result. Name every effect, including the ones that feel routine. Name the label moves here too, because this is the only place the user sees them before they run. Unblocking a dependent changes what someone else picks up next; removing a worktree deletes a directory they may have a terminal sitting in.

This step is done when the user approves the previewed line or declines it. A decline stops the run before the close.

### 3. Reconcile the tracker

Close the issue and set each dependent with [the transition rule](../SKILL.md#promoting-a-dependent). **This is [`sync`](./sync.md)'s job and `close` reuses it rather than restating it**, so apply [Reconcile](./sync.md#1-reconcile-a-merged-pr-whose-issue-never-closed) and [Labels](./sync.md#3-labels-advance-lifecycle-state-unblock-whats-freed) to this one issue. Find the dependents through the native edge, not the body text, and recheck every open prerequisite of each one before it moves:

```sh
gh issue close <n> --comment "Closed by #<pr> (merged)."
gh issue edit <n> --remove-label in-review --remove-label in-progress
gh issue view <n> --json blocking -q '[.blocking[].number]'    # the dependents
# for each dependent labeled blocked or stacked, the label the rule computes:
gh issue edit <dep> --remove-label blocked --add-label ready
gh issue edit <dep> --remove-label stacked --add-label ready
```

Closing strips the active status label in the same action, because a closed issue must never carry a stale `in-review`.

**Run these label writes straight through, with no prompt**, per [the label exemption](../SKILL.md#preflight-every-mode). Report what the labels became in the hand-off.

This step is done when the issue is closed with no lifecycle label, and every `blocked` or `stacked` dependent carries the label the rule computes, or is named in the hand-off as unknown or as having incompatible parents.

### 4. Tear the worktree down through gitkit, keyed on the branch

Hand this to **gitkit**, which looks the worktree up by its branch (`issue-<n>-<slug>`) through `git worktree list --porcelain`. Lookup is by branch, never by guessing at a path, which is what lets it find a worktree that predates the current path convention, or one that was moved.

gitkit's own teardown rules apply and issuekit does not override them:

- **A dirty worktree stops the removal** and shows what would be lost. A merged PR does not guarantee an empty worktree: scratch files, a stashed experiment, or an un-pushed follow-up commit all live there, and none of them are in the PR.
- **Already gone → "already gone"**, not an error. `close` is idempotent in the same spirit as `start`'s adopt-and-stop; re-running it after a partial run is normal.
- **gitkit owns the removal rule, and it resolves to `-d`**, with `-D` only for a squash merge whose merged PR `headRefOid` equals the branch tip. Without gitkit, delete with `-d` and keep the branch when it refuses.
- **gitkit removes only what it created.** It marks the worktrees and branches it creates, and it reports an unmarked one as adopted and keeps it.
- **A branch another layer is stacked on stays.** When this issue's branch is the base of a layer above it, removing the branch strips that layer of its base and its open PR of its target. Before the teardown, check for open PRs that target this branch (`gh pr list --state open --base issue-<n>-<slug>`), and when there are any, remove the worktree but keep the branch, naming the layers that still need it. Read the PRs, not the labels: a layer already in work is `in-progress` or `in-review`, not `stacked`. GitHub re-targets a layer automatically once the branch below it *merges*; it cannot recover one that was deleted underneath it.

If no worktree matches the branch, say so and carry on, because the tracker half of `close` still succeeded. This step is done when the worktree is removed, kept dirty with what would be lost, kept as adopted, or reported as already gone, and the branch is deleted or kept with its reason.

### 5. Hand off

**What changed.** Report the issue closed and by which PR, and each dependent move (`blocked → ready`, `stacked → ready`, `blocked → stacked`). Name each dependent left alone, with its reason: open prerequisites remain, an unknown PR query, or incompatible stack parents.

**Where it landed.** Say whether the worktree was removed, left dirty, kept as adopted, or already gone. If it survived, name the path and why, so it doesn't quietly linger. A worktree made before gitkit marked its creations is reported as adopted and kept; remove it through gitkit directly when it is no longer needed.

**Next.** Closing an issue is the moment a slot opens up, so point at what fills it, naming a kit only when it's installed:

- **this close unblocked something** → that dependent is the strongest candidate; name it and offer `start <n>`. When several moved, offer the highest-priority one.
- **nothing was unblocked, but `ready` issues exist** → offer `start` on the highest-priority one, breaking a tie on the most recently updated.
- **nothing is `ready`** → the workable queue is empty, so the move is back up the funnel: **statuskit** to re-orient, or `triage` if the tracker looks like it's hiding work.
- **the worktree survived dirty** → that outranks everything above. Say it first; unlanded work in a stale worktree is what gets lost.

