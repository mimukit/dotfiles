---
name: orcakit
description: >-
  Bridge a GitHub issue to an Orca worktree and back — turn a `ready` issue into an isolated Orca worktree branched off origin/main with its label flipped, then reconcile the tracker and remove the worktree once the PR lands. Use when the user says "start issue #N", "spin up a worktree for #N", "finish #N", "orcakit", or wants an issue's isolated workspace created or torn down.
license: MIT
allowed-tools: Bash, Read, Skill
metadata:
  internal: false
---

# orcakit

Thin glue between two systems that each own half of "take an issue from ready to landed": a GitHub issue tracker (labels say *what* is workable) and [Orca](https://orca.computer) worktrees (an isolated branch + workspace is *where* it gets worked). orcakit doesn't add tracker or worktree behavior — it **sequences** the two at the two moments they meet: `start <n>` and `finish <n>`.

It leans on two companion skills where they exist — **issuekit** for the GitHub lifecycle and **orca-cli** for worktree operations — but hard-depends on neither: everything runs through the `gh` and `orca` CLIs directly, so orcakit works with just those installed.

## When this fires

The user wants to move an issue between "ready to work" and "landed":

- **start** — "start issue #12", "spin up a worktree for #12", "begin #12", "orcakit start 12".
- **finish** — "finish #12", "wrap up #12 now the PR merged", "tear down #12's worktree", "orcakit finish 12".

If they name neither action explicitly but reference an issue and a worktree, ask which. orcakit never *implements* — it only prepares or tears down the workspace; writing code inside the worktree is a separate step.

## Preflight

Confirm both CLIs are ready before mutating anything:

```sh
gh --version && gh auth status          # GitHub CLI installed + authenticated
gh repo view --json nameWithOwner -q .nameWithOwner   # inside a repo
```

- If `gh` is missing or unauthenticated, say so and point to `https://cli.github.com` / `gh auth login` — don't work around it.
- Resolve and drive the Orca CLI **through the orca-cli skill's guidance** (it picks the right executable for the session and loads the version-matched command reference). Orca's flags can shift between releases, so treat the exact `orca` invocations below as a known-good shape, not gospel — if a flag is rejected, consult `orca worktree create --help` or the orca-cli guide rather than guessing.
- **Portability.** orcakit is repo-agnostic: never hard-code a repo-id. `orca` infers the repo from the current worktree/cwd, so run these from inside the target repo's checkout.

## The safety property

orcakit **never creates a worktree for an issue that isn't labeled `ready`.** This one guard is the whole point: because an issue only moves `blocked → ready` when its prerequisite lands (via issuekit `sync`), refusing to start anything not-`ready` enforces the dependency graph for free — Orca can never get ahead of the tracker. Everything else is mechanical.

The lifecycle labels orcakit reads and writes — `ready`, `in-progress`, `in-review`, and `blocked` — are provisioned by repokit, not created here. If a required label is absent, stop and point the user at repokit or give the exact fallback command, for example `gh label create ready --color 0E8A16 --description "specified and independent — safe to take into its own worktree now"` and `gh label create in-progress --color 1D76DB --description "actively being worked in a worktree"`.

## Action: `start <n>`

The start-event glue. Runs straight through after the guard — its steps are cheap and reversible, so no per-step confirmation. In order:

1. **Guard** — read the issue's labels (`gh issue view <n> --json labels`); refuse unless it carries `ready`. This is the safety property.
2. **Adopt check** — look for an existing worktree for #N before making one: first any whose linked issue is N, then any named `issue-<n>-…` (`orca worktree list --json`). If one exists, **report it and stop** — never recreate or error. This makes re-running `start` safe. (Detection is bounded to those two signals; orcakit does not fuzzy-match arbitrary names — see [Notes](#notes) for the off-convention case.)
3. **Derive the branch name** — `issue-<n>-<slug>` from the conventional issue title `type(scope): summary`: strip the `type(scope):` prefix, kebab-case the summary, cap ~50 chars at a word boundary, drop any trailing hyphen. If the slug comes out empty, use bare `issue-<n>`. The `<n>` prefix guarantees uniqueness across issues, so no tie-break is needed.
4. **Create the worktree + seed a checkpoint — one call** — off fresh `origin/main`, with a real Orca→GitHub link:

   ```sh
   orca worktree create --name issue-<n>-<slug> --base-branch origin/main \
     --issue <n> --no-parent --comment "starting #<n> (<title>)"
   ```

   `--issue` populates the live worktree↔issue link; `--base-branch origin/main` guarantees a clean base every time (never branch off a sibling feature branch); `--comment` records the checkpoint in one shot. `--no-parent` keeps the worktree a top-level sibling: without it, `orca` infers a parent from whatever terminal you run in (typically the main checkout) and records a spurious child lineage — cosmetic, but it nests every issue worktree under the main one. Each issue is independent parallel work, so it should never inherit a parent.
5. **Flip the label** `ready → in-progress` (inline `gh`, trivial):

   ```sh
   gh issue edit <n> --remove-label ready --add-label in-progress
   ```

Report the worktree and the label move. Do **not** launch an agent or start implementing — that's a separate step run inside the worktree.

## Action: `finish <n>`

The land-event glue. Its steps are destructive and outward-facing, so it **previews and waits for an OK** before mutating.

1. **Confirm the PR merged** for this issue (`gh pr list --search "…" --state merged` / `gh pr view`). A merged PR is a **hard precondition**: if none is found — no PR, or the PR is still open — `finish` does nothing to the tracker or the worktree and reports exactly what's blocking (`PR #X still open` / `no PR found for #N`). A forced teardown stays a deliberate manual `orca worktree rm` the user runs themselves.
2. **Preview + confirm** — show what will happen (`PR #X merged → close #N, tick parent checklist, remove worktree <name>`) and wait for the OK.
3. **Reconcile the tracker** — close #N, tick the parent epic's checklist, and flip any dependents `blocked → ready`. This is exactly issuekit's `sync` job: **invoke the issuekit skill when it's installed**; otherwise fall back to the equivalent `gh` calls yourself:

   ```sh
   gh issue close <n> --comment "Closed by #<pr> (merged)."
   gh issue edit <n> --remove-label in-review --remove-label in-progress
   # if a task-list parent contains "- [ ] #<n>", read its body, replace that
   # marker with "- [x] #<n>", and write the updated body back:
   gh issue view <parent> --json body -q .body
   gh issue edit <parent> --body-file <updated-body>
   # for each dependent whose body says "Blocked by #<n>":
   gh issue edit <dep> --remove-label blocked --add-label ready
   ```

4. **Resolve, then remove the worktree** via orca-cli. Don't remove by a single selector — resolve the target the *same two ways* `start`'s **Adopt check** detects it, then `rm` by the selector that actually matched. The `issue:<n>` selector resolves only through the stored Orca→GitHub link, so it fails with `selector_not_found` on any worktree whose `linkedIssue` is `null` — a real case (see [Notes](#notes)). Match on either signal from `orca worktree list --json`: `linkedIssue == <n>` first, then a `displayName` matching `issue-<n>-…`.

   ```sh
   # Resolve the worktree the same way `start` detects it: linked issue N first,
   # then a name matching `issue-<n>-…`, from `orca worktree list --json`.
   # Remove by the selector that actually matched — `issue:<n>` only works when the
   # `--issue` link is present; `name:<displayName>` always works.
   orca worktree rm --worktree name:issue-<n>-<slug> --json   # or issue:<n> when linked
   ```

   **Rule:** prefer `issue:<n>` when the link is present; on `selector_not_found`, fall back to `name:issue-<n>-…` resolved from the list. If nothing matches either signal, report "worktree already gone / off-convention" rather than erroring — teardown is idempotent, same spirit as `start`'s adopt-and-stop. (Other valid selectors: `name:<displayName>`, `branch:<branch>`, `path:<path>`, `id:<repo-id>::<path>`. A bare positional id is rejected as `Unknown command`.)

Report what changed: issue closed, dependents unblocked, worktree removed.

## Notes

- **Off-convention / legacy worktrees.** A worktree that predates orcakit — following neither the `issue-<n>-…` name nor the `--issue` link — won't be seen by adopt-detection, so `start` would spawn a second one beside it. Don't teach `start` to guess; migrate the old worktree once by hand (set `--issue <n>` on it, or recreate it to the naming convention) and note it as a manual step. The same gap bites `finish` more narrowly: a worktree that *does* follow the `issue-<n>-…` name but is missing its `--issue` link (`linkedIssue: null`) is invisible to the `issue:<n>` selector, so its `rm` fails with `selector_not_found` — `finish` must fall back to the name signal in its **Resolve, then remove the worktree** step to remove it.
- **Non-goals.** orcakit does not implement the feature (that's a separate step inside the worktree), does not launch agents by default, does not poll-and-spawn or run fleet automation, and adds no tracker or worktree behavior of its own — it only sequences `gh` and `orca`.
- **No shell / CLI available** (e.g. a browser-based agent)? You can't run `gh` or `orca`. Reason from what the user provides and **print the exact commands** — the guard check, the `orca worktree create …` line, and the label edits — as a codeblock for them to run.
