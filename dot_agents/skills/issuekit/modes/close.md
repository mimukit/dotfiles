## Mode: `close`

The other bookend to [`start`](./start.md): the issue's PR has merged, so close it out and reclaim its workspace. Closing the issue and removing the worktree are destructive, so this mode **previews and waits for an OK** before it runs them. The label writes need no OK at all, per [the label exemption](../SKILL.md#preflight-every-mode); name them in the preview and run them.

### 1. Confirm the PR actually merged, a hard precondition

```sh
gh pr list --search "<n>" --state merged --json number,title,url,closingIssuesReferences
gh pr view <pr> --json state,mergedAt
```

**A merged PR is required, not assumed.** If none is found, whether no PR at all or one that's still open, `close` does **nothing**: no close, no label change, no worktree removal. Report exactly what's blocking (`PR #X still open`, `no PR found for #N`) and stop.

This precondition is the whole reason `close` is safe to run on a name you half-remember. Its two irreversible acts, closing the issue and deleting a worktree, are both gated behind evidence that the work actually landed. A forced teardown of unlanded work stays a deliberate thing the user does themselves, through gitkit directly.

### 2. Preview, then confirm

Show the full consequence in one line and wait:

> PR #10 (`feat(auth): add sso login`) merged → close #42 and strip its `in-review`, unblock #44 (`blocked → ready`), remove the worktree for `issue-42-add-sso-login`.

Name every effect, including the ones that feel routine. Name the label moves here too, because this is the only place the user sees them before they run. Unblocking a dependent changes what someone else picks up next; removing a worktree deletes a directory they may have a terminal sitting in.

### 3. Reconcile the tracker

Close the issue and flip any dependents `blocked → ready`. **This is [`sync`](./sync.md)'s job and `close` reuses it rather than restating it**, so apply [Reconcile](./sync.md#1-reconcile-a-merged-pr-whose-issue-never-closed) and [Labels](./sync.md#3-labels-advance-lifecycle-state-unblock-whats-freed) to this one issue:

```sh
gh issue close <n> --comment "Closed by #<pr> (merged)."
gh issue edit <n> --remove-label in-review --remove-label in-progress
# for each dependent whose body says "Blocked by #<n>":
gh issue edit <dep> --remove-label blocked --add-label ready
```

Closing strips the active status label in the same action, because a closed issue must never carry a stale `in-review`.

**Run these label writes straight through, with no prompt**, per [the label exemption](../SKILL.md#preflight-every-mode). Report what the labels became in the hand-off.

### 4. Tear the worktree down through gitkit, keyed on the branch

Hand this to **gitkit**, which looks the worktree up by its branch (`issue-<n>-<slug>`) through `git worktree list --porcelain`. Lookup is by branch, never by guessing at a path, which is what lets it find a worktree that predates the current path convention, or one that was moved.

gitkit's own teardown rules apply and issuekit does not override them:

- **A dirty worktree stops the removal** and shows what would be lost. A merged PR does not guarantee an empty worktree: scratch files, a stashed experiment, or an un-pushed follow-up commit all live there, and none of them are in the PR.
- **Already gone → "already gone"**, not an error. `close` is idempotent in the same spirit as `start`'s adopt-and-stop; re-running it after a partial run is normal.
- **The branch is deleted only if it's merged**, with `-d` rather than `-D`, so git itself refuses to drop unmerged work.
- **A branch another layer is stacked on stays.** When this issue's branch is the base of a layer above it, removing the branch strips that layer of its base and its open PR of its target. Check for dependents still labeled `stacked` on this issue before the teardown, and when there are any, remove the worktree but keep the branch, naming the layers that still need it. GitHub re-targets a layer automatically once the branch below it *merges*; it cannot recover one that was deleted underneath it.

If no worktree matches the branch, say so and carry on, because the tracker half of `close` still succeeded.

### 5. Hand off

**What changed.** Report the issue closed and by which PR, and each dependent unblocked (`blocked → ready`).

**Where it landed.** Say whether the worktree was removed, left dirty, or already gone. If it survived, name the path and why, so it doesn't quietly linger.

**Next.** Closing an issue is the moment a slot opens up, so point at what fills it, naming a kit only when it's installed:

- **this close unblocked something** → that dependent is the strongest candidate; name it and offer `start <n>`.
- **nothing was unblocked, but `ready` issues exist** → offer `start` on the most-recently-updated one.
- **nothing is `ready`** → the workable queue is empty, so the move is back up the funnel: **statuskit** to re-orient, or `triage` if the tracker looks like it's hiding work.
- **the worktree survived dirty** → that outranks everything above. Say it first; unlanded work in a stale worktree is what gets lost.

