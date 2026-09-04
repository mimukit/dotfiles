## Mode: `create`

Turn work into issues. Two inputs: a plan file (the main path) or a plain description (start fresh).

### 1. Find the input
- **Plan path:** a `plan-<slug>-YYYY-MM-DD.md`. Resolve it by precedence: an explicit path in the prompt → the newest canonical plan under `docs/plans/` (creation date is the filename suffix) → ask which plan.
- **Ad-hoc path:** a plain description with no plan. This is the "start fresh, just file it" case → one well-formed issue.

### 2. Decompose a plan into a proposed breakdown
Read the plan's structure (phases, milestones, tasks) and decide the shape. Four principles govern the breakdown, applied **before** you present anything:

- **One issue per plan by default.** A plan is work one person planned and grilled in a single session, so it becomes a single issue, and the plan's phases become [`## Phase N` sections in that issue's body](#3-create-the-issues) rather than separate issues. Every split costs a worktree, a branch, a PR, a review, and a close, and it buys sequencing the phases already carry for free. Split only where a piece has a genuinely different lifecycle: it ships on its own, it wants its own PR, or a real ordering constraint survives the attempt to design it away. The user can always ask to split one further, and starting consolidated beats starting fragmented.
- **Vertical slices.** Size each issue so it completes **one testable feature end to end**, meaning something a person could verify on its own, rather than a horizontal layer (e.g. "all the DB models", "all the endpoints") that isn't demonstrable until other issues land. Where a plan does yield two issues, prefer "user can log in with SSO" over separate "add OIDC table" / "add OIDC route" / "add OIDC UI" issues. **Nothing caps a slice at what fits in one agent context.** A multi-phase issue is the normal shape here, and an unattended worker builds it phase by phase.
- **Independent by default.** Where a plan does yield more than one issue, sequence them so each can be picked up in its own git worktree and worked **in parallel**, with no issue waiting on another. When two candidate issues share state (a migration one creates and another consumes, an API contract one produces), first try to **design the dependency away**: fold them back into one issue as consecutive phases, or resequence so the shared piece ships inside the prerequisite. Only when a real ordering constraint survives do you record it: the dependent gets [`blocked`](../SKILL.md#lifecycle-labels-every-mode) and a recorded dependency, everything else gets `ready`.
- **A surviving dependency is a stack candidate, not a defeat.** Independence is still worth designing for, because a `ready` issue needs nothing from anybody. But the fallback is no longer a queue: a dependent whose prerequisite is *in flight* becomes [`stacked`](../SKILL.md#lifecycle-labels-every-mode) and is worked on a branch cut from the prerequisite's, so the two land in order without the second one waiting for a review. Say so in the preview, so the user is choosing between "one issue with two phases" and "two issues that stack", rather than between one issue and an idle wait.
- **Prefactor first.** Before slicing anything, look for a simplifying refactor that makes the real change trivial: *"make the change easy, then make the easy change."* It normally belongs as the issue's **first phase**, where the code that needs it follows in the same branch. File it as its own `ready` issue (behavior-preserving → `refactor(scope):`) only when it stands alone, meaning it ships and reviews on its own merits whether or not the feature ever lands.

**Wide mechanical refactors are the standing exception to the one-issue default.** When a change has broad blast radius and genuinely can't be one vertical slice, such as renaming a shared column or retyping a symbol used everywhere, phases in one body are the wrong shape: the migrate batches are independent *of each other* and want to run in parallel branches, which is the one thing phases in a single issue cannot do. Sequence it **expand → migrate → contract**:

- **expand.** Add the new form alongside the old; nothing breaks yet. `ready`.
- **migrate.** Update call sites in batches by area, each batch its own issue [`blocked`](../SKILL.md#lifecycle-labels-every-mode) by the expand issue. The batches are independent of *each other*, so fan them out in parallel.
- **contract.** Delete the old form once nothing uses it, `blocked` by all the migrate batches.

This turns one un-sliceable change into a fan of mostly-parallel issues with honest dependency edges, and reuses the existing `ready`/`blocked` machinery.

**This is the shape stacking pays off on most, so mark the migrate batches `layer on #<expand>` in the Stack column.** The batches all depend on the expand issue and on nothing else, so the moment expand's PR opens they become [`stacked`](../SKILL.md#lifecycle-labels-every-mode) and every batch can be worked at once on its own layer off expand's branch. Without that, the entire fan idles behind a single review. The contract issue stays a plain wait, because it genuinely cannot run until the batches have actually landed.

**Milestones are opt-in.** Do **not** create GitHub milestones by default; map a plan's phases onto the issue body instead. Only when the user **explicitly asks** for milestones (or points at a repo that already uses them) should you create one (`gh api --method POST repos/{owner}/{repo}/milestones -f title="<title>"`, then `gh issue create --milestone <title>`) and attach issues to it. Absent that ask, never introduce a milestone the user would then have to maintain.

Present the proposal as a **preview table** and stop for approval. Do **not** create anything yet:

| # | Title | Priority | Depends on | Stack | Phases |
|---|-------|----------|-----------|-------|--------|
| 1 | `feat(auth): add sso login` | high | none | — | oidc provider · session + token refresh · login UI · account linking |

Titles follow the [title convention](../SKILL.md#title-convention-every-issue-this-skill-creates): `type(scope): summary`, lowercase. The **Phases** column is the plan's structure, carried into one issue rather than scattered across four. The **Depends on** column is where independence is decided out loud, and on a one-issue breakdown it is empty by construction: a cell filled with `#N` means that issue is `blocked` by another one in the table, and every empty cell is an issue the user can take into a worktree now.

The **Stack** column says what happens to a dependent once its prerequisite is in flight: `layer on #N` means it is intended to be worked as a stacked branch rather than waited on, and `—` means it is a plain wait. Fill it for every row whose *Depends on* cell is non-empty, because that is the decision that turns a queue into parallel work, and it is cheapest to make here while the user is looking at the whole shape. Nothing is stacked at creation time, since no prerequisite has a PR yet; the column records the intent that [`sync`](./sync.md) and the PR-authoring skill act on later. Let the user add, drop, retitle, **reprioritize**, **resequence to break a dependency**, or **split** any row before you proceed. Offer the split explicitly when a phase looks like it ships on its own, and say what the split would cost: a second branch, PR, review, and close. This guard is the point, so never spray a repo with auto-generated issues.

**Propose a [priority](../SKILL.md#priority-labels-every-mode) per row, and expect to be overruled.** You can read relative importance off a plan, meaning what it calls out as the core of the feature versus the polish, what it defers, and what it flags as a risk, and that's a real signal worth putting in the column. What you cannot read is why the work is being done at all, which is the thing priority actually encodes. So propose from the plan, mark anything the plan doesn't rank as `medium`, and treat the column as the one most likely to be corrected. This is exactly the right moment for that correction: setting priority here costs the user one glance at a table they're already reviewing, where doing it later means a pass back over issues that have scattered across the tracker.

**Don't hand out `critical` from a plan.** It means *preempt work already in progress*, which is a claim about right now and not about the plan, and a document written last week cannot know what's in flight today. Propose `high` for the most important row and let the user escalate it if they mean it.

For an **ad-hoc** description, skip the table: draft one issue (title + body) and confirm it before creating.

### 3. Create the issues
**Guard against duplicates first.** create is the workflow's entry point and gets re-invoked, so running it twice on one plan must not file a second set. Before creating, list existing issues and skip (or flag for the user) any whose title already matches:

```sh
gh issue list --state all --limit 200 --json number,title,state
```

On trackers with more than 200 issues, raise the limit or use `gh search issues --repo {owner}/{repo} --match title "<candidate title>"` so older duplicates are not silently missed.

Then write each issue with a title in the [`type(scope): summary` convention](../SKILL.md#title-convention-every-issue-this-skill-creates) and a body that carries the relevant slice of the plan: context, phases, acceptance criteria, and any decisions.

**A multi-phase issue carries its phases as `## Phase N` headings**, one per phase of the plan, in the order they build, each followed by its own acceptance criteria:

```markdown
## Phase 1: oidc provider
- [ ] the app redirects to the provider and back
- [ ] the callback rejects a mismatched `state` parameter

## Phase 2: session + token refresh
- [ ] a session survives a browser restart
- [ ] an expired access token refreshes with no re-login
```

That heading is a real interface rather than a formatting choice: it is what lets a builder be pointed at **one phase of the issue**, the same way it can be pointed at one phase of a plan, and it is what an unattended run walks to build a large issue in one branch.

Three conventions for the body:

- **Write acceptance criteria as `- [ ]` checkboxes**, under the phase they belong to, giving a concrete verifiable definition of done for that phase. A single-phase issue drops the headings and carries one flat list.
- **Order the phases as they build.** One branch builds them in sequence, so a phase may assume every phase above it has landed and must assume nothing about the ones below.
- **Don't hard-code file paths**, because they go stale as the branch evolves; describe the change by behavior and area instead. The one exception is a **decision-rich snippet** (a schema, state machine, type, reducer) where the decision *is* the code, so include it, trimmed to just the substantive part.

```sh
gh issue create --title "feat(auth): add sso login" --body-file <bodyfile>
```

Use a temp file for each body (multi-line markdown through `--body` is flaky) and clean it up after.

### 4. Label lifecycle state and priority, and record dependencies
Apply the [lifecycle labels](../SKILL.md#lifecycle-labels-every-mode) so the fresh issues advertise their state. The **grill gate** decides which vocabulary applies, because `ready` is a promise the work can run *unattended*, earned only when the decisions are already settled:

- **Grilled source.** The input plan file carries a `Grilled: YYYY-MM-DD` stamp (grillkit writes it when it hardens a plan), *or* the user explicitly says the work is grilled/ready. The decisions are settled, so the normal pair applies: every independent issue gets `ready`, every dependent one gets `blocked` plus a [recorded dependency](../SKILL.md#recording-a-dependency) naming the prerequisite.
- **Ungrilled source.** An ad-hoc description, or a plan with no grill stamp. The decisions aren't settled, so **every issue gets `needs-planning`**, because it still needs a human plan/grill session before anything unattended should touch it. Record the dependency anyway; it takes effect once the issue is grilled into `ready`. This is what keeps afkkit (and any unattended worker) from picking up work a human hasn't grilled yet.

**Nothing is labeled `stacked` at creation time.** A dependent only becomes stackable once its prerequisite has an open PR, and at creation nothing has been built. The Stack column records the *intent*; the label arrives later, from the PR-authoring skill or from [`sync`](./sync.md).

Then apply the [priority label](../SKILL.md#priority-labels-every-mode) shown in the preview table, **one per issue, in the same `gh issue edit` call** as the lifecycle label, so a fresh issue never exists in a half-labeled state that a concurrent survey could read.

Priority is applied **regardless of the grill gate**. The gate governs the lifecycle namespace only: an ungrilled issue is `needs-planning` because nobody has settled its decisions, but "this matters more than that" is a judgment the preview table already states and it doesn't need a grill session to be true. Dropping it here would mean the ungrilled backlog, the exact pile that most needs ordering, is the one part of the tracker nothing can rank.

Confirm each label exists first (`gh label list`), and if one is missing, stop and point the user at **repokit** or the `gh label create` line rather than creating it yourself. Check both namespaces in that one call; a repo that predates priority will have the lifecycle nine and none of the four.

```sh
# grilled plan → ready / blocked, each with its approved priority
gh issue edit 43 --add-label ready --add-label high
gh issue edit 44 --add-label blocked --add-label medium --add-blocked-by 43
# ungrilled source → needs-planning, still ranked
gh issue edit 45 --add-label needs-planning --add-label low
```

Record the dependency in the same call that labels the issue, so a dependent never exists with a `blocked` label and no recorded prerequisite. On `gh` below 2.94.0, drop `--add-blocked-by`, keep the body line, and say the native edge was skipped.

Show the label set alongside the issues in the preview. The OK covers filing the issues; the labels themselves ride along without a separate prompt.

### 5. Write the issue numbers back into the plan
Once issues exist, annotate the source `plan-<slug>-YYYY-MM-DD.md` so it stays the source of truth. Add the ref to each phase heading the issue covers, without changing the file's creation-date suffix:

```markdown
### Phase 1: oidc provider (#41)
### Phase 2: session + token refresh (#41)
```

**The same number repeats on every phase one issue covers**, which is the normal shape now and not a mistake to tidy up. The annotation answers "where is this phase tracked", and for a one-issue breakdown the answer is the same issue every time. A builder writes its own `(built YYYY-MM-DD)` stamp after the number, so the two annotations sit side by side.

Use `Edit` for this. For an ad-hoc issue with no plan file, skip this step.

### 6. Hand off

_Write every hand-off in this skill in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

**What changed.** Give a table of what you created: number, title, URL, lifecycle label, priority, and phase count. Say that the plan was annotated.

**Where it landed.** Call out the **`ready` set** (issues the user can start in parallel worktrees right now) versus the **`blocked` set**, naming what each blocked issue waits on. Order the `ready` set by priority, since that set exists to be picked from.

**Next.** Route on which set came back non-empty, naming a sibling kit only when it's installed and otherwise describing the action plainly:

- **`ready` issues exist** → pick one up with `start <n>`, which gets it a worktree and flips it `in-progress`. Crown the **highest-priority** one rather than listing all of them, breaking a tie on whichever frees the most other work.
- **everything is `needs-planning`** (an ungrilled source) → the next move is a human grill session, meaning **grillkit** on the plan, then re-run `create`, or relabel by hand once the decisions are settled. Nothing here is workable unattended yet, so say that plainly rather than offering `start`.
- **everything is `blocked`** → surface the root prerequisite; that's the only thing anyone can act on. When the breakdown marked dependents as stack candidates, say so here: starting the root frees them as soon as its PR opens, not when it merges.

