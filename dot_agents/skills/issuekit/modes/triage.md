## Mode: `triage`

Report first, act on approval. Never mutate the tracker just to "tidy up."

### 1. Read the tracker
Fetch `--state all` (not just open), because a `Blocked by #N` pointing at an already-closed issue is drift that the open-issue list alone cannot see. Filter to open for the drift that only concerns open work.

```sh
gh issue list --state all --limit 200 --json number,title,state,labels,assignees,updatedAt,createdAt
```

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
- **Ungrilled `ready`.** An issue labeled `ready` whose decisions clearly aren't settled (open questions in the body, no acceptance criteria) → it was promoted too early; offer to move it back to `needs-planning` so unattended workers skip it until a human grills it.
- **Missing labels**, relative to the [lifecycle map](../SKILL.md#lifecycle-labels-every-mode) (or the repo's own scheme, if it predates it). When the map's labels aren't provisioned, say so and point at **repokit** rather than creating them.
- **Status cross-checks.** Issues whose linked PR merged but that are still open (hand off to `sync` for the actual close).

### 3. Offer fixes
For each flagged item, apply the fix. A relabel or a reprioritize runs straight through, per [the label exemption](../SKILL.md#preflight-every-mode); a close or a comment is proposed and applied **only when the user approves it**:

```sh
gh issue edit <n> --add-label <label>
gh issue edit <n> --add-label high --remove-label medium   # priority is a replace, never an add
gh issue comment <n> --body-file <decision>
gh issue close <n> --comment "Closing as stale; reopen if still relevant."
```

**Ranking an unassessed backlog is a batch, so propose it as one table**, with issue, title, and a proposed priority per row, rather than as one question per issue. Priority is comparative by nature: the user is deciding what beats what, and a table is the only shape that shows them the comparison they're actually making. Asked one at a time, twenty issues become twenty context-free judgments and every one of them comes back `medium`, which is the same as not ranking at all.

**Propose a distribution, not a wall of `high`.** A backlog where most things are `high` has no priority information in it: the label stops discriminating and every consumer falls back to whatever tiebreak sits underneath it. Aim for a shape where `critical` is empty or nearly so, `high` is a handful, and the long tail is `medium` and `low`. When your own proposal comes out top-heavy, that's a signal to re-read the issues rather than to ship the table.

**Show the table, then apply it.** Ranking is a claim the user owns, so the table is how they see and correct the ranking you chose, but it does not gate the write: print it, apply the priorities, and say the user can rewrite any row with one `gh issue edit`. Re-read the issues before you print a top-heavy table rather than after.

### 4. Hand off
**What changed.** Report what the report found, and which fixes you applied versus left alone. A flagged item the user declined is worth naming; it stays drift until someone decides otherwise.

**Where it landed.** Give the tracker's state after the pass, per namespace: how many open issues now carry a lifecycle label and how many are still unmarked, and how many carry a priority and how many are still unassessed. Two numbers, because a pass can genuinely fix one and leave the other untouched.

**Next.** triage only classifies; the fixes it can't make itself belong to a sibling mode, so route by what survived: issues whose PR merged but that are still open → `sync`; a stale `blocked` whose prerequisite already landed → `sync`; an issue promoted to `ready` too early → a human grill session (**grillkit** when installed) before anything unattended touches it; missing labels in either namespace → **repokit**. If the tracker came back clean, say so and point at the `ready` set, because the next move is `start` on the **highest-priority** one, not more tidying.
