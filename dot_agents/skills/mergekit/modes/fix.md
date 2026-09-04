## Mode `fix <n>`: service review feedback on your own PR

The mirror of `start`. `start` pulls down a PR for *you* to review; `fix` is for a PR *you authored* that has come back with review comments, a change request, or red CI, meaning the author's side of the same loop. It reads the feedback, **judges which of it is worth acting on**, drives those changes, pushes, and answers every thread. Like every mergekit mode, it stops short of merging.

It overlaps `close`'s [Fix path](./close.md#fix-path) in mechanics but differs at both ends: that path implements a verdict *you* just reached while reviewing someone else's PR, whereas `fix` starts from feedback *someone else* left on yours, so it opens by gathering that feedback and closes by answering it.

### 1. Gather the feedback

Assemble the punch list before touching code:

- **Unresolved review threads** with `file:line` and comment text, bot or human, via the same GraphQL `reviewThreads` query [`list`](./list.md) uses. These are the change requests.
- **Failing checks** from `gh pr checks <n>`, with each failing job's name and, where reachable, its log tail. Red CI is feedback too.
- **The review decision** from `gh pr view <n> --json reviewDecision`, so you know whether a re-request of review is warranted at the end.

If there is nothing to service, meaning no unresolved threads and green CI, say so and stop. There is nothing to fix.

### 2. Triage the punch list, and decide what is actually worth fixing

**Feedback is a claim, not an instruction.** A review comment, from a bot or a human, is someone's read of the code from outside the change, and a fair share of it is wrong for *this* project: a rule the repo has deliberately opted out of, a suggestion that contradicts the plan this PR implements, a real point that belongs in its own issue rather than this diff. Applying all of it because it was written down is how a PR grows a second unreviewed change and how a project's conventions get quietly overwritten by a linter's defaults. So every item gets a verdict *before* any code is touched.

Judge each item against what the project actually is, in this order: its **documented conventions** (the repo's agent-instructions file, its contributing guide, ADRs, lint and formatter config), the **surrounding code**, and the **stated scope** of this PR and the issue or plan it implements. Then assign one of three verdicts:

- **Fix.** Correct, in scope, and consistent with the above. This is the default for anything that is plainly a bug, a real failure, or a convention the repo does hold.
- **Decline**, with the reason named, because it goes in the reply. The recurring ones: it contradicts a documented convention or a settled decision; it is a bot false positive or a misreading of the code; it is already handled elsewhere in the diff; it is real but **out of scope**, meaning a separate change that deserves its own issue rather than a drive-by in a PR under review.
- **Ask.** You cannot tell from the repo alone. Genuine trade-offs, anything that conflicts with the implementation plan or a direction the user has stated, anything that widens the change's blast radius, and anything where your confidence is simply low.

Rules that keep this honest:

- **Ask in one round, not one at a time.** Batch every `ask` item into a single compact table (item, what it wants, your recommended verdict and why) and let the user rule on them together. Never grind through a thread-by-thread interrogation.
- **When in doubt, ask rather than decline.** Declining silently is the failure mode that costs the most: the reviewer believes it was considered, and nobody finds out otherwise.
- **A declined item is still answered.** It stays on the punch list through [Answer the feedback](#5-answer-the-feedback), where it gets a reply stating the reason and stays unresolved. Declining is a position you state, not a thread you drop.
- **Red CI is not triaged away.** A failing check is a fact about the branch, not an opinion about the code. If a job fails for a reason you consider illegitimate, surface it; don't file it under "declined" and push.
- **Print the triage before you start.** One line per item with its verdict, so the user sees the whole shape and can overrule any of it. If most of the list came back declined, say so plainly, because a PR whose feedback is mostly wrong usually means the reviewer and the PR disagree about the change itself, and that is worth a conversation, not a fix round.

### 3. Get the worktree and sync

Adopt the branch's existing worktree exactly as [`start` does](./start.md#2-get-a-worktree-adopting-first-and-creating-only-if-needed), because your own PR almost always still has the worktree it was built in, then sync exactly as [`start` syncs](./start.md#3-sync-with-the-base-branch), through gitkit. It is your branch, but it is *published*, so the sync previews and waits for an OK before anything is pushed. The thread count matters more here than anywhere else: you are about to *answer* those threads, and a rebase outdates the ones you have not replied to yet, so gather and triage the punch list first, and put the number in the preview. A PR you opened from a fork you don't control is the read-only case, where you cannot push; say so and stop.

### 4. Fix, gate, commit, push

For each item you decided to **fix**, in the live worktree:

1. Implement the change, preferring an installed implementation skill.
2. Run the repo's test and build gate.
3. Commit in the repo's own style, preferring an installed commit skill.

Then push with a plain `git push`, and the PR updates in place. This is **bounded**, like any fix round: if an item turns out to be ambiguous once you are inside the code, or you can't get the gate green, stop and surface it rather than guessing at what the reviewer meant. An item can still flip to **ask** here, because triage judged it from the outside, and the code sometimes disagrees.

### 5. Answer the feedback

Close the loop so the reviewer sees every item handled, fixed *and* declined, each mutation previewed and confirmed like any other:

- **Reply and resolve** each thread you actually fixed, pointing at the commit that did it. **Never resolve a thread you didn't fix.**
- **Reply to each declined thread with the reason, and leave it open.** A declined item is a position, not a silence: name what it conflicts with, whether the convention, the decision, or the PR's scope, and let the reviewer overrule you. Out-of-scope items are the exception worth going further on: offer to file the follow-up issue rather than leaving the point to evaporate.
- **Re-request review** when the decision was `CHANGES_REQUESTED` (`gh pr edit <n> --add-reviewer <login>`, or the `requested_reviewers` REST endpoint).
- **Do not merge.** Servicing feedback earns a fresh review, not a landing, because merging is `close`'s job, behind its human gate.

### 6. Hand off

**What changed.** Report the punch-list items you fixed and the commits that did it, the gate result, and which threads you replied to, resolved, or left open. **Report the declines with their reasons**, not just the fixes; the reviewer needs to see what you chose not to do more than what you did.

**Where it landed.** Give the branch pushed and the PR updated in place, plus the worktree path you worked in.

**Next.** The ball is back in the reviewer's court, so the move is theirs, not yours: the re-requested review, or CI re-running on the push. Name first what you *couldn't* service and what you *declined*, because a rejected comment, an ambiguous one, or a gate you couldn't get green is the thing standing between this PR and a merge, and it needs the reviewer, not another fix round. Once they approve, `close <n>` lands it.
