## Mode: `clean`

The removing mode, and the only one. Every archive and every delete in this skill happens here, in two halves with different blast radii:

- **The registry reap** collapses duplicate rows, and archives an `orphaned` row when the user asks for it before the daemon's own pass gets there. Reversible **only because of what it is scoped to**, not because `archive` is a safe call. See [the reap rule](#1-find-the-registry-reap-candidates).
- **The worktree teardown** removes the whole local footprint of merged work: the agent sessions, the worktree directory, the local branch, and the registry row. Destructive, and git gives none of it back.

**Neither half touches anything before the preview.** The mode first collects both candidate sets and prints them as one list. The registry reap then takes one confirmation, and each teardown row takes its own.

### Scope

`clean` takes the same two scopes as [`sync`](../SKILL.md#scope), with the same words. Project scope is the default. "clean all", "clean everything", or "all my projects" widens it to every project `paseo project ls --json` returns.

### 1. Find the registry reap candidates

Run [`list`](../SKILL.md#mode-list)'s join first, filtered to the chosen scope. Collect, without archiving anything yet:

- Each `duplicate` set, collapsed on paper to one row: keep the row a live agent is attached to, otherwise the oldest by `createdAt`, and queue the rest for archive.
- Each `orphaned` row, queued for archive **only when the user asked to clear the sidebar now**. Otherwise report it and let the daemon's five-minute pass take it.

**The reap rule: a reap candidate must be a row that cannot reach the disk.** Per [The archive call deletes directories](../SKILL.md#the-archive-call-deletes-directories), test each queued row and keep it only when one of these holds:

- Its directory is already gone. That is every `orphaned` row by definition, so the orphan half is safe by construction.
- Its directory's parent is the repo name rather than a hash, so the daemon refuses the delete. Archiving it edits the registry and nothing else. The row's `isPaseoOwnedWorktree` reads `false` here and agrees with the path test, per [the ownership flag](../SKILL.md#the-version-seam); read both and reject the row when they disagree.
- Another active row survives the reap pointing at the same directory. That is what protects a `duplicate` set: the kept row still references the path, so the delete test fails and the directory stays. **The rule holds only while the kept row survives**, so never queue a whole duplicate set, and never queue the kept row.

A row that passes none of the three is a disk delete wearing a reap's clothes. **Move it to the teardown half**, where it must prove a merged pull request first, or reject it and report why.

**Never queue a workspace with a live agent in it.** The archive will not refuse on your behalf; it archives the agent and continues.

**Collect each `stray project` too, as its own candidate class.** `paseo project delete "$PROJECT_ID"` is the fix, and it removes the project *and every workspace under it*, so it never rides along with a row archive. Before you queue one, list the workspaces that would go with it and carry that list into the preview. **Never queue a stray project holding a workspace whose directory a real project still needs**, and never queue one with a live agent under it.

### 2. Find the teardown candidates

From the same join, test every worktree that carries a branch. A candidate must pass **all six** gates:

- **The pull request merged.** Read it per branch, and accept nothing weaker:

  ```sh
  gh pr list --head "$BRANCH" --state merged --json number,title,mergedAt,url --limit 1
  ```

  A closed-unmerged pull request is not a merge, and no open one qualifies. **Without a merged pull request, the worktree is not a candidate**, whatever the branch name says.
- **The tree is clean.** No uncommitted change, no untracked file, no stash entry made in this worktree:

  ```sh
  git -C "$WT" status --porcelain
  ```

- **Nothing is unpushed.** `git -C "$WT" log --oneline "@{upstream}.."` returns nothing, or the branch has no upstream *and* every commit on it is contained in the merged pull request. A commit that exists only here dies with the directory.
- **No live agent.** No non-idle agent's `cwd` sits inside the worktree. A `busy` workspace is never a candidate, and it is reported, never queued.
- **The issue is closed.** A branch named `issue-<n>-<slug>` whose issue `gh issue view "$N" --json state` reads as open is tracker drift, not a candidate. Report it and route it to **issuekit** `close <n>`, which closes the issue and tears the worktree down in one pass.
- **gitkit made it.** gitkit owns the removal rule, and it removes only a worktree that carries its ownership marker, so an unmarked worktree is reported as adopted rather than queued. Without gitkit, the marker test is `test -e "$(git -C "$WT" rev-parse --absolute-git-dir)/gitkit-created"`. A Paseo-created worktree fails this gate too, and [align](./align.md)'s `autoArchiveAfterMerge` is its native path.

Ends when every worktree in scope is a candidate or a rejected row with its reason.

**`gh` missing or unauthenticated blocks the teardown entirely.** The merge is the whole precondition, and there is no way to prove it without the tracker. Say so, and carry only the registry reap candidates into the preview, rather than falling back to a branch-name guess.

### 3. Preview, then confirm

Print one table before touching anything, split into two labelled sections. The **archive** section lists each registry reap candidate with the workspace id, the title, the reason (`orphaned`, or `duplicate` with the kept row named), and which of the three reap-rule tests it passed. The **delete** section lists each teardown candidate with the branch, the merged pull request number and title, the worktree path, the workspace id, and the agent sessions that will be removed with it. Sum each section in a closing line.

Give a **stray project** section its own block when any is queued, listing the project id, its `rootPath`, and every workspace that goes with it by id and title. That count is what [Reap, then tear down, in this order](#4-reap-then-tear-down-in-this-order) checks the result against.

**Say which section reaches the disk.** State in one line above the table that the archive section removes rows and stops there, and that the delete section removes directories and branches that git cannot restore. The stray project section removes rows only, however many of them.

Then confirm, and wait for each answer. Silence is not consent.

- **The archive section takes one question.** Every row in it is registry-only by [the reap rule](#1-find-the-registry-reap-candidates), and every row is on the screen. A partial answer means archive only the rows the user named.
- **Each stray project takes its own question**, naming the workspaces that go with it.
- **Each delete row takes its own question.** gitkit owns the removal rule, and it resolves to one confirmation per worktree and per branch; without gitkit, ask once per row all the same. Name the branch, the path, and the merged pull request in each question.

Ends when every queued row has the user's answer.

An empty list ends the mode here. Say the registry and the disk already match, and skip to the hand-off.

Print the rejected worktrees under the table with their reason, one line each, because "why is this one still here" is the next question every time.

### 4. Reap, then tear down, in this order

**Archive first.** Per confirmed reap candidate:

```sh
paseo workspace archive "$WORKSPACE_ID" --json
```

**Re-read the set immediately before each archive**, with `paseo workspace ls --json` and `paseo ls -g --json`. The daemon's own pass, another session, or the user can change a row between the preview and the call. Archive a `duplicate` row only while its kept row is still active and still points at the same `cwd`, and only while no live agent has attached to it. When the kept row is gone or moved, skip the whole set, report it, and leave the re-run to the user; never promote a queued row to kept on your own. An `orphaned` row that the daemon already archived counts as done.

Then, per confirmed teardown candidate, and never in a different order, since each step removes the thing the next one would otherwise strand:

1. **Recheck the candidate.** Re-read `busy`, `git -C "$WT" status --porcelain`, and the unpushed count. Skip the row and report the change when any of them moved since the preview.
2. **Stop the agent sessions in that worktree.** Take them from `paseo ls -g --json`, filtered by expanded `cwd`, and stop each one through the `paseo` CLI. Check `paseo --help` for the current verb rather than assuming one. An agent left running holds a directory that is about to disappear.
3. **Remove the worktree through gitkit**, keyed on the branch, under its removal rule. Without gitkit installed, `git -C "$REPO" worktree remove "$WT"`. Teardown is **idempotent**: a directory already gone is reported as "already gone", never as an error. **A removal that refuses because the tree is dirty stops that candidate** and is reported; never pass `--force`.
4. **Delete the local branch through gitkit.** gitkit's rule resolves to `-d`, and to `-D` only for a squash merge whose merged pull request `headRefOid` equals the branch tip. Without gitkit, run `git -C "$REPO" branch -d "$BRANCH"`, and keep the branch and report it when `-d` refuses.
5. **Archive the registry row** with `paseo workspace archive "$WORKSPACE_ID" --json`. The gitkit removal above already deleted the directory, so the call finds nothing left to delete and only the row goes. **Keep this last for that reason.** Archive before the directory is gone and the call deletes it itself, skipping gitkit, the dirty-tree refusal, and the unpushed-commit gate.

**Delete each confirmed stray project last**, after every row above has settled, so the workspace count it reports is the one the preview promised:

```sh
paseo project delete "$PROJECT_ID" --json
```

**Verify the id against `paseo project ls --json` immediately before the call, and read the returned `removedWorkspaceIds` array.** A wrong id is not an error: the daemon accepts any well-formed `prj_…`, removes nothing, and returns an empty array with a success status. So the exit code proves nothing on its own. An empty array where the preview promised workspaces means the id was wrong or the project moved. Say that, and never re-run with a guessed id.

**A failure at any step stops that candidate and continues to the next.** Report the step it stopped on. Never unwind the steps that already succeeded, because each of them is complete on its own.

Ends when every confirmed row is archived, removed, skipped by its recheck, or stopped with its reported step.

### Hand off

**What changed.** Name the scope you ran. Report the registry reap first: rows archived and duplicate sets collapsed, with counts. Then report per candidate what was removed: the sessions stopped, the directory deleted, the branch deleted, and the row archived. Give the totals. Name every rejected and every failed candidate with its reason, and put the `busy` ones first.

**Where it landed.** Give the disk and the registry both, since this mode is the one that touches both. Name the worktree root you swept and the paths that are gone.

**Next.** Crown one:

- **any candidate the user held back** → name it and stop. That was a decision, not an oversight.
- **tracker drift**, meaning a merged pull request whose issue is still open → route to **issuekit** `close <n>`.
- **anything `busy`** → name the path and the agent. Tell the user to run `clean` again after that agent finishes.
- **any `unregistered` or `tombstoned` worktree left standing** → route to [`sync`](../SKILL.md#mode-sync), which registers into the registry this mode just cleaned.
- **nothing left** → say the disk and the registry match, and stop.
