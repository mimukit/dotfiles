## Mode: `sync`

Reconcile and repair the PR↔issue relationship. **Sync deliberately does not write the forward `Closes #N` link onto a fresh PR**, because that belongs to the PR-authoring step (a prkit-style skill) at open time. Sync only earns its place where the automatic chain *broke*:

| Who | Owns |
|-----|------|
| PR-authoring skill | write `Closes #N` into a **new** PR at open time (forward, happy path) |
| **issuekit sync** | reconcile drift after merge, repair a missing link on an **existing** PR, advance lifecycle labels and unblock dependents |

### 1. Reconcile a merged PR whose issue never closed
Find PRs merged recently whose linked issue is still open. Two causes produce the same drift, and the sweep has to catch both:

```sh
gh pr list --state merged --limit 20 --json number,title,body,baseRefName,closingIssuesReferences
gh issue list --state open --json number,title
```

- **The keyword was never written.** The body carries no `Closes #N` at all, so GitHub had nothing to resolve.
- **The keyword was written and GitHub ignored it, which is the stack signature.** A body that carries `Closes #N` while `closingIssuesReferences` comes back **empty** is the case this mode exists to repair. GitHub honors a closing keyword only on a PR that targets the repository's **default branch**, so every stack layer above the bottom one ships a correct keyword that does nothing. The link normally registers by itself once the layer below merges and GitHub retargets the PR to trunk; when the merge happened without that retarget, the issue stays open with a perfect-looking body and nothing else in the tracker points at the gap.

Read the body and `closingIssuesReferences` together rather than either alone. A body with the keyword is not evidence of a link, and an empty `closingIssuesReferences` is not evidence of a missing keyword.

For each merged PR that *should* have closed an issue (evident from `Closes #N` in the body, the branch, the title, the plan, or the user telling you), **preview it and confirm before closing**:

> PR #10 (`feat(auth): add sso login`) merged, but issue #42 is still open → close #42 with a comment linking the PR?

On approval:

```sh
gh issue close 42 --comment "Closed by #10 (merged)."
```

Closing is a lifecycle transition too, so strip any active status label (`in-review`, `in-progress`, …) in the same action and a closed issue never carries a stale status (see [Labels: advance lifecycle state](#3-labels-advance-lifecycle-state-unblock-whats-freed)). Never auto-close, and always show the pairing and wait for the OK. **If which issue a PR should have closed is ambiguous, ask rather than guess**, because closing the wrong issue is worse than leaving one open.

### 2. Repair a missing link on an existing open PR
If an **open** PR should reference an issue but doesn't, add `Closes #N` to its body (editing the existing PR, not opening a new one):

```sh
gh pr edit <pr> --body-file <updated-body>
```

**Sweep the open layer PRs too, so the drift is caught before the merge rather than after.** A layer PR needs a different repair from a body rewrite, so classify it before you touch it:

```sh
gh pr list --state open --json number,title,body,baseRefName,closingIssuesReferences
gh repo view --json defaultBranchRef -q .defaultBranchRef.name
```

- **Base is the default branch, body has no keyword** → the plain repair above. Add `Closes #N` and the link registers.
- **Base is not the default branch, body carries `Closes #N`, `closingIssuesReferences` empty** → **expected, not drift.** The keyword is inert until GitHub retargets the PR to trunk, which happens when the layer below merges. Report it and change nothing. Rewriting the body here repairs nothing, and retargeting the PR to trunk would destroy the stack.
- **Base is not the default branch, body has no keyword** → a real gap, and the fix is the same body edit. Write `Closes #N` now so the link registers the moment the retarget lands.
- **Base is now the default branch, body carries `Closes #N`, `closingIssuesReferences` still empty** → a layer GitHub already retargeted, whose body it never re-parsed. Force the re-parse by writing the same body back, and check the link again:

```sh
gh pr view <pr> --json body -q .body > <file>
gh pr edit <pr> --body-file <file>
```

Preview each of these like any other mutation, and say which of the four cases each PR fell into.

### 3. Labels: advance lifecycle state, unblock what's freed
Move issues through the [lifecycle labels](../SKILL.md#lifecycle-labels-every-mode) as PRs advance: an issue whose PR just opened → `in-review`; and, the dependency payoff, when an issue that was a **blocker** closes, find the issues that depend on it and swap them `blocked` → `ready`, optionally commenting that the prerequisite landed:

```sh
gh issue edit 44 --remove-label blocked --add-label ready
gh issue comment 44 --body "Unblocked: #43 (the prerequisite) merged."
gh issue edit 42 --remove-label in-review   # closing → strip the active status label; the closed state is the signal
```

**`sync` is the repair sweep for `stacked`, not its primary writer.** A dependent becomes stackable the moment its prerequisite's PR opens, and the skill that opens that PR sets the label there, where it is fresh. `sync` catches everything that path missed: a PR opened by hand or on GitHub, a run where the flip was declined, a label that has since gone stale. Three moves, each run without a prompt:

```sh
# prerequisite's PR opened → the dependent is workable on a layer
gh issue edit 44 --remove-label blocked --add-label stacked
# prerequisite merged → the dependent no longer needs a layer
gh issue edit 44 --remove-label stacked --add-label ready
# prerequisite's PR closed unmerged → the dependent is a real wait again
gh issue edit 44 --remove-label stacked --add-label blocked
```

**A stack merge closes several issues at once**, because merging one PR in a stack merges every unmerged PR below it. So reconcile the whole cascade rather than the one PR someone named: read every merged PR in that stack, close each issue it closes, and then run the promotions above for whatever those closures freed. Handling only the top PR leaves the layers underneath looking unlanded when their code is already on trunk.

**Relabel without asking**, per [the label exemption](../SKILL.md#preflight-every-mode), and list every move in the hand-off. The closes and body edits around them still wait for an OK. If a label the map needs isn't provisioned, stop and point the user at **repokit** or the `gh label create` line, because issuekit uses labels and doesn't create them. If the repo predates this map and runs its own status scheme, follow that instead and say you did.

### 4. Hand off
**What changed.** Report issues closed, PR bodies repaired, and issues advanced or **unblocked** (`blocked` → `ready`). Name every label move, because those ran without a prompt. Say plainly if nothing needed repairing; a clean sweep is a real result.

**Where it landed.** Give the **actionable set**: a table of every open issue that is `in-progress` or `ready` *after* the sync, so the user sees at a glance what's being worked and what they can pick up next in a fresh worktree:

```sh
gh issue list --state open --label in-progress --json number,title
gh issue list --state open --label ready --json number,title
```

| # | Title | Status | Priority |
|---|-------|--------|----------|
| 43 | `feat(auth): oidc login end to end` | `in-progress` | high |
| 44 | `feat(auth): sso account linking` | `ready` | medium |

List `in-progress` rows first, then `ready`, each group ordered by priority. If both sets are empty, say so instead of printing an empty table. Drop the `Priority` column when no row carries one, because an all-blank column reads as "nothing matters" when the truth is "nobody has ranked these," and the fix for that is `triage`, not a wider table.

**Next.** Crown one row from that table, naming a kit only when it's installed: an `in-progress` issue is unfinished work and outranks a fresh start (resume it in its worktree with **implementkit**), while a `ready` one is the pick-up (`start <n>`). Priority orders *within* each group and doesn't jump a `ready` issue over an `in-progress` one, because finishing beats starting, and a half-built `medium` still costs less to land than a fresh `high`. The exception is a `critical`, which means preempt by definition: crown it over in-progress work and say plainly what's being set down. Both sets empty means the tracker has nothing workable, so the move is `create` from a plan, or **plankit** if there isn't one yet.

