## Mode: `triage`

Report first, then apply the fixes the user approves, labels included. triage sits outside [the label exemption](../SKILL.md#preflight-every-mode), because every fix it makes is a judgment the report proposes.

**A targeted request is its own approval.** "Set the priority on #42", "relabel #42", "rename #42", or "#42 is grilled, mark it ready" names one fix on one issue. Skip the full report, apply that fix with the rules below, and report it.

### 1. Read the tracker
Fetch `--state all` (not just open), because a `Blocked by #N` pointing at an already-closed issue is drift that the open-issue list alone cannot see. Filter to open for the drift that only concerns open work.

```sh
gh issue list --state all --limit 200 --json number,title,state,labels,assignees,updatedAt,createdAt,blockedBy
```

This step is done when the list is in hand, or the failed call is named and the run stops. A failed read is unknown, never an empty tracker.

### 2. Flag drift
Produce a **status report**, as a table, surfacing:
- **Stale.** No update in a long while (e.g. 30–60 days; scale to the repo's pace).
- **Orphaned.** No labels and no assignee.
- **Zombie label.** A **closed** issue still carrying a status label (`in-review`, `in-progress`, …) → strip it; the closed state is the signal.
- **Stale block.** An issue labeled `blocked` whose `Blocked by #N` target is already closed → it should be `ready` (hand the relabel to `sync`).
- **Dangling / circular dependency.** A `Blocked by #N` pointing at a missing issue, or two issues blocking each other.
- **Unmarked.** An open issue carrying no [lifecycle label](../SKILL.md#lifecycle-labels-every-mode) at all → offer to classify it (`triage` / `needs-planning` / `ready` / `blocked`).
- **Unassessed.** An open issue carrying no [priority label](../SKILL.md#priority-labels-every-mode) → offer to rank it. Report this as its own count rather than folding it into *Unmarked*: the two are independent gaps, and a tracker with tidy lifecycle labels and no priorities anywhere is both a common state and an invisible one if the report only ever prints one number. Exclude `wontfix` and `duplicate`, which need no rank.
- **Double-ranked.** An open issue carrying **more than one** priority label → offer to keep the highest and drop the rest. This is the failure mode the [one-at-a-time rule](../SKILL.md#priority-labels-every-mode) exists to prevent, and it happens whenever a label is set outside this skill (the GitHub UI applies labels additively, with nothing to stop it). Keeping the highest is the safe repair: it can only ever over-rank an issue the user is about to look at anyway, where silently keeping the lowest buries work somebody explicitly escalated.
- **Stale `critical`.** An issue labeled `critical` that hasn't been updated in weeks → offer to demote it. `critical` means *preempt what's in progress*, so an untouched one is self-refuting: nobody dropped anything for it, which is the tracker saying out loud that it isn't critical. Left alone it's worse than no label at all, because it outranks everything downstream forever and trains the user to ignore the level that's supposed to be unignorable. Scale "weeks" to the repo's pace, the same way the *Stale* check does.
- **Grilled `needs-planning`.** An issue labeled `needs-planning` whose body or linked plan carries a `Grilled: YYYY-MM-DD` stamp → offer [the promotion](#promote-needs-planning-to-ready).
- **Ungrilled `ready`.** An issue labeled `ready` whose decisions clearly aren't settled (open questions in the body, no acceptance criteria) → it was promoted too early; offer to move it back to `needs-planning` so unattended workers skip it until a human grills it.
- **Missing labels**, relative to the [lifecycle map](../SKILL.md#lifecycle-labels-every-mode) (or the repo's own scheme, if it predates it). When the map's labels aren't provisioned, say so and point at **repokit** rather than creating them.
- **Status cross-checks.** Issues whose linked PR merged but that are still open (hand off to `sync` for the actual close).
- **Off-convention title.** An **open** issue whose title does not match the [title convention](../SKILL.md#title-convention-every-issue-this-skill-creates). Detect with a regex over the fetched titles, e.g. `^(feat|fix|docs|refactor|perf|test|build|ci|style|chore)\([a-z0-9./-]+\): \S` (allow leading uppercase only for a proper noun or acronym after the colon). **First confirm the repo actually uses the convention:** when most existing titles already ignore the shape, the repo has its own style, so say so, skip this check, and follow the repo per [Notes](../SKILL.md#notes). For each real miss, derive the `type` from what the issue delivers, not the files it touches, and the `(scope)` from the package or directory the body names; fall back to `repo` for genuinely global work.

This step is done when every issue in the read has been tested against every check above, and the report names each hit with its proposed fix.

### 3. Offer fixes, then apply the approved ones
Print every proposed fix as one batch, grouped by kind, and wait for the user's answer. The user approves the batch, strikes rows, or rewrites rows. Apply each approved row as approved, a rewritten row as rewritten, and skip a struck row:

```sh
gh issue edit <n> --add-label <label>
gh issue edit <n> --add-label high --remove-label medium   # priority is a replace, never an add
gh issue comment <n> --body-file <decision>
gh issue close <n> --comment "Closing as stale; reopen if still relevant."
```

**Ranking an unassessed backlog is a batch, so propose it as one table**, with issue, title, and a proposed priority per row, rather than as one question per issue. Priority is comparative by nature: the user is deciding what beats what, and a table is the only shape that shows them the comparison they're actually making. Asked one at a time, twenty issues become twenty context-free judgments and every one of them comes back `medium`, which is the same as not ranking at all.

**Propose a distribution, not a wall of `high`.** A backlog where most things are `high` has no priority information in it: the label stops discriminating and every consumer falls back to whatever tiebreak sits underneath it. Aim for a shape where `critical` is empty or nearly so, `high` is a handful, and the long tail is `medium` and `low`. When your own proposal comes out top-heavy, that's a signal to re-read the issues rather than to ship the table.

**Title repairs are a previewed batch.** A title edit rewrites what every list, notification, and PR link shows. Propose all renames as one `old -> new` table, get one OK for the whole batch, then apply each with `gh issue edit <n> --title "<new>"`. A row the user rewrites or strikes is applied as corrected or skipped.

**The table is the approval.** Ranking is a claim the user owns, so the table is how they see and correct the ranking you chose before it lands. Re-read the issues before you print a top-heavy table rather than after.

#### Promote `needs-planning` to `ready`

This promotion is the way back from `needs-planning`, for an issue that `create` filed ungrilled or that afkkit escalated. It runs **only on the user's word**, because the `ready` label carries a human judgment that no agent can award.

1. **Look for the grill.** Read the issue body for a `Grilled: YYYY-MM-DD` stamp, then any plan file the body links. Report the stamp and its source when you find one.
2. **Ask when there is no stamp.** Say that no `Grilled:` stamp exists, and ask whether a grill settled the decisions. A "yes" is the user's word; a "no" routes to **grillkit**, and the issue keeps `needs-planning`.
3. **Compute the label.** Apply [the transition rule](../SKILL.md#promoting-a-dependent) to the issue's open prerequisites: `ready` when none remain, otherwise `stacked` or `blocked`. Where the rule keeps the current label for incompatible stack parents, set `blocked` and name the parents.
4. **Replace the label** in one call: `gh issue edit 45 --remove-label needs-planning --add-label ready`.

This sub-step is done when the issue carries the label the rule computes, or keeps `needs-planning` with the reason named.

This step is done when every open issue has exactly one lifecycle label and, except `wontfix` and `duplicate`, exactly one priority label, or is named in the hand-off as a declined or unresolved row.

### 4. Hand off
**What changed.** Report what the report found, and which fixes you applied versus left alone. A flagged item the user declined is worth naming; it stays drift until someone decides otherwise.

**Where it landed.** Give the tracker's state after the pass, per namespace: how many open issues now carry a lifecycle label and how many are still unmarked, and how many carry a priority and how many are still unassessed. Two numbers, because a pass can genuinely fix one and leave the other untouched.

**Next.** triage only classifies; the fixes it can't make itself belong to a sibling mode, so route by what survived: issues whose PR merged but that are still open → `sync`; a stale `blocked` whose prerequisite already landed → `sync`; an issue promoted to `ready` too early, or a `needs-planning` issue with no grill → a human grill session (**grillkit** when installed), then the promotion above; missing labels in either namespace → **repokit**. If the tracker came back clean, say so and point at the `ready` set, because the next move is `start` on the **highest-priority** one, not more tidying.
